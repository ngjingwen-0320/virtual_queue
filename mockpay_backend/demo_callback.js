const crypto = require("node:crypto");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { createCallbackProcessor } = require("./bank_callback");
const { sign } = require("./callback_signature");

if (
  process.env.GCLOUD_PROJECT !== "demo-mockpay" ||
  !process.env.FIRESTORE_EMULATOR_HOST
) {
  throw new Error(
    "Run this demonstration only through the demo-mockpay emulator command",
  );
}
async function main() {
  const sdk = initializeApp({ projectId: "demo-mockpay" });
  const db = getFirestore(sdk);
  const callbackSecret = crypto.randomBytes(32).toString("hex");
  const { processCallback } = createCallbackProcessor({ db, callbackSecret });
  const prefix = crypto.randomUUID();
  async function fixture(name) {
    const paymentId = `${prefix}-${name}`;
    const authorizationId = crypto.randomUUID();
    const attemptId = crypto.randomUUID();
    const eventId = crypto.randomUUID();
    const brandId = paymentId;
    const expiresAt = Timestamp.fromMillis(Date.now() + 600000);
    const event = {
      eventId,
      authorizationId,
      paymentId,
      attemptId,
      merchantId: "MP_demo",
      amountCents: 2000,
      currency: "MYR",
      status: "paid",
      bankName: "Maybank2u",
    };
    await Promise.all([
      db
        .collection("mock_merchants")
        .doc(brandId)
        .set({
          merchantId: "MP_demo",
          verified: true,
          paymentEnabled: true,
          status: "active",
          balanceCents: 0,
        }),
      db
        .collection("mock_payments")
        .doc(paymentId)
        .set({
          reservationId: paymentId,
          brandId,
          restaurantId: "branch",
          customerUid: "demo",
          bankAuthorizationId: authorizationId,
          attemptId,
          merchantId: "MP_demo",
          amountCents: 2000,
          currency: "MYR",
          pax: 2,
          status: "pending",
          expiresAt,
        }),
      db
        .collection("reservations")
        .doc(paymentId)
        .set({
          customer_id: "demo",
          brand_id: brandId,
          restaurant_id: "branch",
          mockpay_payment_id: paymentId,
          status: "PENDING",
          payment_status: "pending",
          pax: 2,
          reservation_datetime: Timestamp.fromMillis(Date.now() + 3 * 86400000),
        }),
      db
        .collection("mockpay_bank_authorizations")
        .doc(authorizationId)
        .set({
          ...event,
          status: "pending",
          receiptEmail: "demo@example.test",
          expiresAt,
        }),
    ]);
    return event;
  }
  async function check(scenario, message) {
    try {
      const result = await processCallback(message);
      return {
        scenario,
        result: "Signature verified; payment accepted",
        http: 200,
        paymentId: result.paymentId,
      };
    } catch (error) {
      return { scenario, result: error.message, http: error.status || 500 };
    }
  }
  try {
    const event = await fixture("valid");
    const message = sign(callbackSecret, event);
    console.log(
      "Synthetic signed message (the secret key is never displayed):",
    );
    console.log(
      JSON.stringify(
        {
          timestamp: message.timestamp,
          signature: message.signature,
          payload: event,
        },
        null,
        2,
      ),
    );
    const results = [await check("Valid callback", message)];
    results.push(
      await check("Modified amount; original signature", {
        ...message,
        rawBody: Buffer.from(JSON.stringify({ ...event, amountCents: 100 })),
      }),
    );
    results.push(await check("Repeated event", message));
    results.push(
      await check(
        "Expired timestamp",
        sign(callbackSecret, await fixture("expired"), Date.now() - 301000),
      ),
    );
    results.push(
      await check(
        "Signed but wrong amount",
        sign(callbackSecret, {
          ...(await fixture("mismatch")),
          amountCents: 1000,
        }),
      ),
    );
    console.table(results.map(({ paymentId, ...row }) => row));
    const expected = [200, 401, 409, 400, 409];
    if (results.some((result, i) => result.http !== expected[i]))
      throw new Error("A demonstration check failed");
    console.log(
      "Demo passed. Only isolated emulator records were used; no funds or emails were sent.",
    );
  } finally {
    await deleteApp(sdk);
  }
}
main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
