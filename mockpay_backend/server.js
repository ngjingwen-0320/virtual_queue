const path = require("path");
const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
require("dotenv").config({
  path: path.join(__dirname, "../mock_payment_tools/.env"),
});
require("dotenv").config({ path: path.join(__dirname, ".env") });
require("dotenv").config({
  path: path.join(__dirname, ".env.callback.local"),
  quiet: true,
});

if (!process.env.ACCOUNT_HMAC_KEY)
  throw new Error("ACCOUNT_HMAC_KEY is missing");

if (process.env.FIRESTORE_EMULATOR_HOST) {
  initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-mockpay" });
} else {
  initializeApp({ credential: cert(require("./serviceAccountKey.json")) });
}

const bankClient = require("./payment_authorization").createBankClient({
  url: process.env.MOCKBANK_URL || "http://127.0.0.1:3001",
  requestSecret: process.env.MOCKBANK_REQUEST_KEY,
});

const app = require("./app")({
  db: getFirestore(),
  auth: getAuth(),
  secret: process.env.ACCOUNT_HMAC_KEY,
  callbackSecret: process.env.MOCKBANK_CALLBACK_HMAC_KEY,
  bankClient,
});

const port = Number(process.env.PORT || 3000);
app.listen(port, process.env.HOST || "127.0.0.1", () =>
  console.log(`MockPay simulation running on port ${port}`),
);
