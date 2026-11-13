const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const destination = path.join(__dirname, ".env.callback.local");
if (fs.existsSync(destination)) {
  console.log("Callback configuration already exists; no keys were changed.");
} else {
  const values = [
    `MOCKBANK_CALLBACK_HMAC_KEY=${crypto.randomBytes(32).toString("hex")}`,
    `MOCKBANK_REQUEST_KEY=${crypto.randomBytes(32).toString("hex")}`,
    "MOCKBANK_URL=http://127.0.0.1:3001",
    "MOCKPAY_CALLBACK_URL=http://127.0.0.1:3000/api/mockpay/bank/callback",
  ];
  fs.writeFileSync(destination, values.join("\n") + "\n", {
    flag: "wx",
    mode: 0o600,
  });
  console.log(
    "Created backend-only callback configuration. Secret values are not displayed.",
  );
}
