const express = require("express");
const crypto = require("node:crypto");
const { rateLimit } = require("express-rate-limit");
const { sign, requireSecret } = require("./callback_signature");

function createMockBank({
  requestSecret,
  callbackSecret,
  callbackUrl,
  fetchImpl = fetch,
}) {
  requireSecret(requestSecret, "mock-bank request key");
  requireSecret(callbackSecret);
  if (requestSecret === callbackSecret)
    throw new Error("Request and callback keys must be different");
  const callback = new URL(callbackUrl);
  if (
    !["http:", "https:"].includes(callback.protocol) ||
    callback.username ||
    callback.password
  )
    throw new Error("Invalid callback URL");
  const app = express();
  app.disable("x-powered-by");
  app.use(rateLimit({ windowMs: 60000, limit: 100 }));
  app.use(express.json({ limit: "10kb" }));
  app.get("/health", (_, res) =>
    res.json({ service: "Mock Bank", simulation: true }),
  );
  app.post("/authorise", async (req, res) => {
    const received = req.headers.authorization;
    const expectedHash = crypto
      .createHash("sha256")
      .update(`Bearer ${requestSecret}`)
      .digest();
    const receivedHash = crypto
      .createHash("sha256")
      .update(typeof received === "string" ? received : "")
      .digest();
    if (!crypto.timingSafeEqual(expectedHash, receivedHash))
      return res
        .status(401)
        .json({ message: "MockPay server authentication required" });
    const a = req.body;
    const identifiers = [
      "authorizationId",
      "eventId",
      "paymentId",
      "attemptId",
      "merchantId",
    ];
    const fields = [...identifiers, "amountCents", "currency", "bankName"];
    if (
      !a ||
      typeof a !== "object" ||
      Array.isArray(a) ||
      Object.keys(a).some((key) => !fields.includes(key)) ||
      !identifiers.every(
        (key) =>
          typeof a[key] === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(a[key]),
      ) ||
      !Number.isSafeInteger(a.amountCents) ||
      a.amountCents <= 0 ||
      a.amountCents > 8000 ||
      a.currency !== "MYR" ||
      ![
        "Maybank2u",
        "CIMB Clicks",
        "Public Bank",
        "RHB Now",
        "Hong Leong Connect",
        "AmBank",
        "Bank Islam",
        "Bank Rakyat",
      ].includes(a.bankName)
    ) {
      return res
        .status(400)
        .json({ message: "Invalid simulated bank authorization" });
    }
    const message = sign(callbackSecret, { ...a, status: "paid" });
    try {
      const result = await fetchImpl(callback, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-MockPay-Timestamp": message.timestamp,
          "X-MockPay-Signature": message.signature,
        },
        body: message.rawBody,
        signal: AbortSignal.timeout(8000),
        redirect: "error",
      });
      if (!result.ok)
        return res
          .status(502)
          .json({ message: "MockPay rejected the bank callback" });
      return res.json({ status: "delivered", eventId: a.eventId });
    } catch (_) {
      return res
        .status(502)
        .json({ message: "MockPay callback delivery unavailable" });
    }
  });
  app.use((error, req, res, next) => {
    if (res.headersSent) return next(error);
    res
      .status(error.status || 500)
      .json({ message: "Invalid mock-bank request" });
  });
  return app;
}
module.exports = { createMockBank };
