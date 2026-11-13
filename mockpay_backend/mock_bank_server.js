const path = require("node:path");
require("dotenv").config({
  path: path.join(__dirname, ".env.callback.local"),
  quiet: true,
});
const app = require("./mock_bank").createMockBank({
  requestSecret: process.env.MOCKBANK_REQUEST_KEY,
  callbackSecret: process.env.MOCKBANK_CALLBACK_HMAC_KEY,
  callbackUrl:
    process.env.MOCKPAY_CALLBACK_URL ||
    "http://127.0.0.1:3000/api/mockpay/bank/callback",
});
const port = Number(process.env.MOCKBANK_PORT || 3001);
app.listen(port, "127.0.0.1", () =>
  console.log(`Mock bank simulation listening on port ${port}`),
);
