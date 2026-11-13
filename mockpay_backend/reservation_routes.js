const { runReservationTransaction } = require('./reservation_transaction');
const { normalizePhone } = require('./phone_number_utils');
const express = require("express");
const { FieldValue, Timestamp } = require("firebase-admin/firestore");

module.exports = function createReservationRouter({ db, authenticateUser }) {
  const router = express.Router();
  const fail = (status, message) => {
    const error = new Error(message);
    error.status = status;
    throw error;
  };
  const id = (value) =>
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= 128 &&
    !value.includes("/") &&
    value !== "." &&
    value !== "..";
  const ref = (collection, key) => db.collection(collection).doc(key);
  const route = (path, fn) =>
    router.post(path, authenticateUser, async (req, res, next) => {
      try {
        res.json(await fn(req));
      } catch (error) {
        next(error);
      }
    });
  const active = (merchant) =>
    merchant?.verified === true &&
    merchant.paymentEnabled === true &&
    merchant.status === "active";

  route("/reservations", async (req) => {
    const user = (await ref("users", req.user.uid).get()).data();
    if (user?.role !== "customer") fail(403, "Customer access required");
    const data = { ...req.body };
    if (
      !id(data.reservation_id) ||
      !id(data.brand_id) ||
      !id(data.restaurant_id)
    )
      fail(400, "Invalid reservation details");
    const allowed = [
      "reservation_id",
      "customer_id",
      "customer_name",
      "customer_phone",
      "brand_id",
      "restaurant_id",
      "restaurant_name",
      "booking_type",
      "guest_name",
      "guest_phone",
      "pax",
      "reservation_datetime",
      "special_request",
    ];
    if (Object.keys(data).some((key) => !allowed.includes(key)))
      fail(400, "Unsupported reservation fields");
    if (
      data.customer_id !== req.user.uid ||
      !Number.isInteger(data.pax) ||
      data.pax < 1 ||
      data.pax > 8
    )
      fail(400, "Invalid customer or guest count");
    const date = Date.parse(data.reservation_datetime);
    if (!Number.isFinite(date) || date < Date.now() + 86400000)
      fail(400, "Book at least 24 hours in advance");
    for (const key of ["customer_name", "customer_phone"]) {
      if (
        typeof data[key] !== "string" ||
        !data[key].trim() ||
        data[key].length > 150
      )
        fail(400, "Name and phone required");
    }
    for (const key of ["special_request", "guest_name", "guest_phone"]) {
      if (
        data[key] !== undefined &&
        (typeof data[key] !== "string" || data[key].length > 1000)
      )
        fail(400, "Invalid booking details");
    }
    if (!["SELF", "OTHER"].includes(data.booking_type))
      fail(400, "Invalid booking type");
    if (
      data.booking_type === "OTHER" &&
      (!data.guest_name?.trim() || !data.guest_phone?.trim())
    )
      fail(400, "Guest details required");
    data.customer_phone = normalizePhone(data.customer_phone);
    if (!data.customer_phone) fail(400, 'Invalid Malaysian customer phone number');
    data.guest_phone = data.booking_type === 'OTHER' ? normalizePhone(data.guest_phone) : '';
    if (data.booking_type === 'OTHER' && !data.guest_phone) fail(400, 'Invalid Malaysian guest phone number');
    const reservationRef = ref("reservations", data.reservation_id);
    return db.runTransaction(async (tx) => {
      const [existing, branch, merchant] = await Promise.all([
        tx.get(reservationRef),
        tx.get(
          db.doc(
            `restaurant_brands/${data.brand_id}/restaurants/${data.restaurant_id}`,
          ),
        ),
        tx.get(ref("mock_merchants", data.brand_id)),
      ]);
      if (existing.exists) {
        if (existing.data().customer_id !== req.user.uid)
          fail(409, "Reservation ID unavailable");
        return { reservationId: reservationRef.id };
      }
      if (!branch.exists || branch.data().is_active === false)
        fail(409, "Restaurant branch unavailable");
      if (!active(merchant.data()))
        fail(409, "This restaurant has not enabled MockPay deposits");
      tx.create(reservationRef, {
        ...data,
        restaurant_name: merchant.data().businessName,
        reservation_datetime: Timestamp.fromMillis(date),
        status: "PENDING",
        payment_status: "unpaid",
        deposit_paid: false,
        deposit_amount_cents: data.pax * 1000,
        created_at: FieldValue.serverTimestamp(),
      });
      return { reservationId: reservationRef.id };
    });
  });

  route("/reservations/action", async (req) => {
    const { reservationId, action } = req.body;
    if (
      !id(reservationId) ||
      !["cancel", "approve", "reject", "update"].includes(action)
    )
      fail(400, "Invalid reservation action");
    const user = (await ref("users", req.user.uid).get()).data();
    return runReservationTransaction(db, async (tx) => {
      const reservationRef = ref("reservations", reservationId);
      const reservation = (await tx.get(reservationRef)).data();
      if (!reservation) fail(404, "Reservation not found");
      const customer =
        user?.role === "customer" && reservation.customer_id === req.user.uid;
      let owner = false;
      if (user?.role === "restaurant") {
        const [brand, branch] = await Promise.all([
          tx.get(ref("restaurant_brands", reservation.brand_id)),
          tx.get(
            db.doc(
              `restaurant_brands/${reservation.brand_id}/restaurants/${reservation.restaurant_id}`,
            ),
          ),
        ]);
        owner =
          brand.data()?.owner_id === req.user.uid &&
          branch.data()?.owner_id === req.user.uid;
      }
      if (
        (["cancel", "update"].includes(action) && !customer) ||
        (["approve", "reject"].includes(action) && !owner)
      )
        fail(403, "Reservation access denied");
      const target =
        action === "cancel"
          ? "CANCELLED"
          : action === "approve"
            ? "CONFIRMED"
            : "REJECTED";
      if (
        action !== "update" &&
        String(reservation.status).toUpperCase() === target
      )
        return { status: target, paymentStatus: reservation.payment_status || "unpaid" };
      if (
        !["PENDING", "CONFIRMED"].includes(
          String(reservation.status).toUpperCase(),
        ) ||
        reservation.reservation_datetime.toMillis() <= Date.now()
      )
        fail(409, "Reservation can no longer be changed");
      if (
        ["cancel", "update"].includes(action) &&
        reservation.reservation_datetime.toMillis() < Date.now() + 86400000
      )
        fail(409, "Changes require at least 24 hours notice");
      if (action === "approve") {
        if (
          String(reservation.status).toUpperCase() !== "PENDING" ||
          reservation.payment_status !== "paid" ||
          !reservation.deposit_paid
        )
          fail(409, "Deposit must be paid before approval");
        tx.update(reservationRef, { status: "CONFIRMED" });
        return { status: "CONFIRMED" };
      }
      if (
        action === "reject" &&
        String(reservation.status).toUpperCase() !== "PENDING"
      )
        fail(409, "Only pending reservations can be rejected");
      const paymentRef = ref(
        "mock_payments",
        reservation.mockpay_payment_id || reservationId,
      );
      const payment = (await tx.get(paymentRef)).data();
      if (
        payment &&
        (payment.customerUid !== reservation.customer_id ||
          payment.brandId !== reservation.brand_id)
      )
        fail(409, "Payment reconciliation required");
      if (action === "update") {
        if (payment?.status === "paid")
          fail(
            409,
            "Paid bookings cannot change guest count or time; cancel and rebook",
          );
        const date = Date.parse(req.body.reservationDateTime);
        if (
          !Number.isInteger(req.body.pax) ||
          req.body.pax < 1 ||
          req.body.pax > 8 ||
          !Number.isFinite(date) ||
          date < Date.now() + 86400000 ||
          typeof req.body.specialRequest !== "string" ||
          req.body.specialRequest.length > 1000
        )
          fail(400, "Invalid reservation changes");
        if (payment) tx.update(paymentRef, { status: "cancelled" });
        tx.update(reservationRef, {
          pax: req.body.pax,
          reservation_datetime: Timestamp.fromMillis(date),
          special_request: req.body.specialRequest,
          payment_status: "unpaid",
          deposit_amount_cents: req.body.pax * 1000,
        });
        return { status: reservation.status };
      }
      let paymentStatus = reservation.payment_status || "unpaid";
      if (payment?.status === "paid") {
        const merchantRef = ref("mock_merchants", payment.brandId);
        const merchant = (await tx.get(merchantRef)).data();
        if (!merchant || merchant.balanceCents < payment.amountCents)
          fail(409, "Refund reconciliation required");
        tx.update(merchantRef, {
          balanceCents: FieldValue.increment(-payment.amountCents),
        });
        tx.update(paymentRef, {
          status: "refunded",
          refundedAt: FieldValue.serverTimestamp(),
        });
        paymentStatus = "refunded";
      } else if (payment?.status === "pending") {
        tx.update(paymentRef, { status: "cancelled" });
        paymentStatus = "cancelled";
      }
      tx.update(reservationRef, {
        status: target,
        payment_status: paymentStatus,
        deposit_paid: false,
        ...(paymentStatus === "refunded"
          ? { refunded_at: FieldValue.serverTimestamp() }
          : {}),
      });
      return { status: target, paymentStatus };
    });
  });
  return router;
};
