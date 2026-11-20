const crypto = require("node:crypto");
const { Timestamp, FieldValue } = require("firebase-admin/firestore");
const reject = (status, message) => {
  const error = new Error(message);
  error.status = status;
  throw error;
};

async function authorizePayment({ db, bankClient, uid, email, paymentId }) {
  const paymentRef = db.collection("mock_payments").doc(paymentId);
  const result = await db.runTransaction(async (tx) => {
    const payment = (await tx.get(paymentRef)).data();
    if (!payment) reject(404, "Payment not found");
    if (payment.customerUid !== uid) reject(403, "Payment access denied");
    if (payment.status === "paid") return { alreadyProcessed: true };
    if (
      payment.status !== "pending" ||
      !payment.expiresAt ||
      payment.expiresAt.toMillis() <= Date.now()
    )
      reject(409, "Payment not payable");
    const context = `payment:${paymentId}:${payment.attemptId}`;
    const sessionKey = crypto
      .createHash("sha256")
      .update(`${uid}:${context}`)
      .digest("hex");
    const sessionRef = db.collection("mockpay_sessions").doc(sessionKey);
    const reservationRef = db
      .collection("reservations")
      .doc(payment.reservationId);
    const merchantRef = db.collection("mock_merchants").doc(payment.brandId);
    const [sessionDoc, reservationDoc, merchantDoc] = await Promise.all([
      tx.get(sessionRef),
      tx.get(reservationRef),
      tx.get(merchantRef),
    ]);
    const reservation = reservationDoc.data();
    const merchant = merchantDoc.data();
    if (
      !reservation ||
      !merchant ||
      reservation.customer_id !== uid ||
      reservation.brand_id !== payment.brandId ||
      reservation.restaurant_id !== payment.restaurantId ||
      reservation.mockpay_payment_id !== paymentId ||
      reservation.payment_status !== "pending" ||
      !["PENDING", "CONFIRMED"].includes(
        String(reservation.status).toUpperCase(),
      ) ||
      reservation.reservation_datetime.toMillis() <= Date.now() ||
      !Number.isInteger(reservation.pax) ||
      reservation.pax < 1 ||
      reservation.pax > 8 ||
      reservation.pax !== payment.pax ||
      payment.amountCents !== reservation.pax * 1000 ||
      payment.currency !== "MYR" ||
      merchant.merchantId !== payment.merchantId ||
      merchant.verified !== true ||
      merchant.paymentEnabled !== true ||
      merchant.status !== "active"
    ) {
      reject(409, "Payment details changed or are unavailable");
    }
    if (payment.bankAuthorizationId) {
      const prior = (
        await tx.get(
          db
            .collection("mockpay_bank_authorizations")
            .doc(payment.bankAuthorizationId),
        )
      ).data();
      if (
        prior?.status === "pending" &&
        prior.attemptId === payment.attemptId &&
        prior.expiresAt.toMillis() > Date.now()
      ) {
        return {
          authorizationId: payment.bankAuthorizationId,
          authorization: prior,
        };
      }
    }
    const session = sessionDoc.data();
    if (
      !session ||
      session.context !== context ||
      session.expiresAt.toMillis() <= Date.now()
    ) {
      reject(403, "Verify the TAC for this payment first");
    }
    const authorizationId = crypto.randomUUID();
    const authorization = {
      paymentId,
      attemptId: payment.attemptId,
      merchantId: payment.merchantId,
      amountCents: payment.amountCents,
      currency: payment.currency,
      bankName: session.bankName,
      receiptEmail: email,
      eventId: crypto.randomUUID(),
      status: "pending",
      expiresAt: Timestamp.fromMillis(
        Math.min(session.expiresAt.toMillis(), payment.expiresAt.toMillis()),
      ),
      createdAt: FieldValue.serverTimestamp(),
    };
    tx.create(
      db.collection("mockpay_bank_authorizations").doc(authorizationId),
      authorization,
    );
    tx.delete(sessionRef);
    tx.update(paymentRef, { bankAuthorizationId: authorizationId });
    return { authorizationId, authorization };
  });
  if (result.alreadyProcessed)
    return { paymentId, status: "paid", alreadyProcessed: true };
  const a = result.authorization;
  try {
    await bankClient.authorise({
      authorizationId: result.authorizationId,
      eventId: a.eventId,
      paymentId: a.paymentId,
      attemptId: a.attemptId,
      merchantId: a.merchantId,
      amountCents: a.amountCents,
      currency: a.currency,
      bankName: a.bankName,
    });
  } catch (_) {
    const latest = (await paymentRef.get()).data();
    if (latest?.status !== "paid")
      reject(
        502,
        "Mock bank unavailable or callback rejected. Retry confirmation.",
      );
  }
  const payment = (await paymentRef.get()).data();
  if (payment.status !== "paid" || payment.callbackSignatureVerified !== true)
    reject(502, "Waiting for a verified bank callback. Retry confirmation.");
  return {
    paymentId,
    status: "paid",
    amountCents: payment.amountCents,
    currency: payment.currency,
    signatureVerified: true,
    alreadyProcessed: false,
  };
}

function createBankClient({ url, requestSecret, fetchImpl = fetch }) {
  require("./callback_signature").requireSecret(
    requestSecret,
    "mock-bank request key",
  );
  const target = new URL(url);
  if (
    !["http:", "https:"].includes(target.protocol) ||
    target.username ||
    target.password
  )
    throw new Error("Invalid mock-bank URL");
  return {
    async authorise(payload) {
      const response = await fetchImpl(new URL("/authorise", target), {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${requestSecret}`,
        },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(10000),
        redirect: "error",
      });
      if (!response.ok) throw new Error("Mock-bank authorization failed");
      return response.json();
    },
  };
}
module.exports = { authorizePayment, createBankClient };
