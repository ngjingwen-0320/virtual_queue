const crypto = require("node:crypto");

function requireSecret(secret, name = "callback signing key") {
  if (typeof secret !== "string" || Buffer.byteLength(secret) < 32) {
    throw new Error(`${name} must contain at least 32 bytes`);
  }
}

function signature(secret, timestamp, rawBody) {
  requireSecret(secret);
  if (!Buffer.isBuffer(rawBody))
    throw new TypeError("Raw body must be a Buffer");
  return crypto
    .createHmac("sha256", secret)
    .update(String(timestamp))
    .update(".")
    .update(rawBody)
    .digest("hex");
}

function sign(secret, payload, now = Date.now()) {
  const timestamp = String(Math.floor(now / 1000));
  const rawBody = Buffer.from(JSON.stringify(payload), "utf8");
  return {
    timestamp,
    rawBody,
    signature: signature(secret, timestamp, rawBody),
  };
}

function verify(
  secret,
  timestamp,
  receivedSignature,
  rawBody,
  now = Date.now(),
) {
  if (
    typeof timestamp !== "string" ||
    !/^\d{10,12}$/.test(timestamp) ||
    !Number.isSafeInteger(Number(timestamp))
  ) {
    return { ok: false, status: 400, reason: "Invalid callback timestamp" };
  }
  if (
    !Buffer.isBuffer(rawBody) ||
    typeof receivedSignature !== "string" ||
    !/^[a-f0-9]{64}$/.test(receivedSignature)
  ) {
    return { ok: false, status: 401, reason: "Invalid callback signature" };
  }
  const expected = signature(secret, timestamp, rawBody);
  if (
    !crypto.timingSafeEqual(
      Buffer.from(expected, "hex"),
      Buffer.from(receivedSignature, "hex"),
    )
  ) {
    return { ok: false, status: 401, reason: "Invalid callback signature" };
  }
  const age = Math.floor(now / 1000) - Number(timestamp);
  if (age > 300 || age < -30)
    return {
      ok: false,
      status: 400,
      reason: "Callback timestamp expired or in the future",
    };
  return { ok: true };
}

module.exports = { requireSecret, sign, verify };
