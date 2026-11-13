const { FieldValue } = require("firebase-admin/firestore");
const { verify, requireSecret } = require("./callback_signature");
const validId = (value) =>
  typeof value === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(value);
const reject = (status, message) => {
  const error = new Error(message);
  error.status = status;
  throw error;
};

function createCallbackProcessor({ db, callbackSecret, clock = Date.now }) {
  requireSecret(callbackSecret);
  async function audit(type, details = {}) {
    try {
      await db
        .collection("mockpay_security_events")
        .add({ type, ...details, at: FieldValue.serverTimestamp() });
    } catch (_) {
      console.error("MockPay security audit write unavailable");
    }
  }
  async function processCallback({ timestamp, signature, rawBody }) {
    const checked = verify(
      callbackSecret,
      timestamp,
      signature,
      rawBody,
      clock(),
    );
    if (!checked.ok) {
      await audit(
        checked.status === 401
          ? "callback_signature_rejected"
          : "callback_timestamp_rejected",
      );
      reject(checked.status, checked.reason);
    }
    let event;
    try {
      event = JSON.parse(rawBody.toString("utf8"));
    } catch (_) {
      await audit("callback_payload_rejected");
      reject(400, "Invalid callback JSON");
    }
    const fields = [
      "eventId",
      "authorizationId",
      "paymentId",
      "attemptId",
      "merchantId",
      "amountCents",
      "currency",
      "status",
      "bankName",
    ];
    if (
      !event ||
      typeof event !== "object" ||
      Array.isArray(event) ||
      Object.keys(event).length !== fields.length ||
      fields.some((key) => !(key in event)) ||
      Object.keys(event).some((key) => !fields.includes(key)) ||
      ![
        "eventId",
        "authorizationId",
        "paymentId",
        "attemptId",
        "merchantId",
      ].every((key) => validId(event[key])) ||
      !Number.isSafeInteger(event.amountCents) ||
      event.amountCents <= 0 ||
      event.amountCents > 8000 ||
      event.currency !== "MYR" ||
      event.status !== "paid" ||
      typeof event.bankName !== "string" ||
      event.bankName.length > 80
    ) {
      await audit("callback_payload_rejected");
      reject(400, "Invalid callback payload");
    }
    try {
      return await db.runTransaction(async (tx) => {
        const eventRef = db
          .collection("mockpay_callback_events")
          .doc(event.eventId);
        const paymentRef = db.collection("mock_payments").doc(event.paymentId);
        const authRef = db
          .collection("mockpay_bank_authorizations")
          .doc(event.authorizationId);
        const paymentDoc = await tx.get(paymentRef);
        const existing = await tx.get(eventRef);
        const authorizationDoc = await tx.get(authRef);
        if (existing.exists) reject(409, "Callback event already processed");
        const payment = paymentDoc.data();
        const authorization = authorizationDoc.data();
        if (!payment || !authorization)
          reject(409, "Payment authorization not found");
        if (payment.status !== "pending")
          reject(409, "Payment already processed or cancelled");
        if (
          authorization.status !== "pending" ||
          authorization.expiresAt.toMillis() <= clock() ||
          payment.expiresAt.toMillis() <= clock()
        )
          reject(409, "Payment authorization expired");
        if (
          payment.bankAuthorizationId !== event.authorizationId ||
          authorization.eventId !== event.eventId ||
          [
            "paymentId",
            "attemptId",
            "merchantId",
            "amountCents",
            "currency",
            "bankName",
          ].some((key) => authorization[key] !== event[key]) ||
          payment.attemptId !== event.attemptId ||
          payment.merchantId !== event.merchantId ||
          payment.amountCents !== event.amountCents ||
          payment.currency !== event.currency
        ) {
          reject(409, "Callback does not match the authorized payment");
        }
        const reservationRef = db
          .collection("reservations")
          .doc(payment.reservationId);
        const merchantRef = db
          .collection("mock_merchants")
          .doc(payment.brandId);
        const [reservationDoc, merchantDoc] = await Promise.all([
          tx.get(reservationRef),
          tx.get(merchantRef),
        ]);
        const reservation = reservationDoc.data();
        const merchant = merchantDoc.data();
        if (
          !reservation ||
          !merchant ||
          reservation.customer_id !== payment.customerUid ||
          reservation.brand_id !== payment.brandId ||
          reservation.restaurant_id !== payment.restaurantId ||
          reservation.mockpay_payment_id !== event.paymentId ||
          reservation.payment_status !== "pending" ||
          !["PENDING", "CONFIRMED"].includes(
            String(reservation.status).toUpperCase(),
          ) ||
          reservation.reservation_datetime.toMillis() <= clock() ||
          !Number.isInteger(reservation.pax) ||
          reservation.pax < 1 ||
          reservation.pax > 8 ||
          payment.pax !== reservation.pax ||
          event.amountCents !== reservation.pax * 1000 ||
          merchant.merchantId !== event.merchantId ||
          merchant.verified !== true ||
          merchant.paymentEnabled !== true ||
          merchant.status !== "active"
        ) {
          reject(409, "Stored payment details changed or are unavailable");
        }
        tx.create(eventRef, {
          eventId: event.eventId,
          paymentId: event.paymentId,
          authorizationId: event.authorizationId,
          receivedAt: FieldValue.serverTimestamp(),
        });
        tx.update(authRef, {
          status: "paid",
          completedAt: FieldValue.serverTimestamp(),
        });
        tx.update(paymentRef, {
          status: "paid",
          bankName: event.bankName,
          receiptEmail: authorization.receiptEmail,
          callbackSignatureVerified: true,
          callbackEventId: event.eventId,
          callbackVerifiedAt: FieldValue.serverTimestamp(),
          paidAt: FieldValue.serverTimestamp(),
        });
        tx.update(merchantRef, {
          balanceCents: FieldValue.increment(event.amountCents),
        });
        tx.update(reservationRef, {
          payment_status: "paid",
          deposit_paid: true,
          paid_at: FieldValue.serverTimestamp(),
        });
        tx.create(db.collection("mockpay_security_events").doc(), {
          type: "callback_accepted",
          paymentId: event.paymentId,
          eventId: event.eventId,
          at: FieldValue.serverTimestamp(),
        });
        return {
          status: "paid",
          paymentId: event.paymentId,
          eventId: event.eventId,
          signatureVerified: true,
        };
      });
    } catch (error) {
      await audit(
        error.message === "Callback event already processed"
          ? "callback_replay_rejected"
          : "callback_payment_rejected",
        { eventId: event.eventId, paymentId: event.paymentId },
      );
      throw error;
    }
  }
  const handler = async (req, res, next) => {
    try {
      res.json(
        await processCallback({
          timestamp: req.headers["x-mockpay-timestamp"],
          signature: req.headers["x-mockpay-signature"],
          rawBody: req.body,
        }),
      );
    } catch (error) {
      next(error);
    }
  };
  return { handler, processCallback };
}
module.exports = { createCallbackProcessor };
