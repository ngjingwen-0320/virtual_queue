const crypto = require("crypto");
const path = require("path");
const dotenv = require("dotenv");

const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

dotenv.config({
  path: path.join(__dirname, "../mock_payment_tools/.env"),
});

const serviceAccount = require("./serviceAccountKey.json");

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

async function verifyBankDetails(businessName, bankName, accountNumber) {
  const secretKey = process.env.ACCOUNT_HMAC_KEY;

  if (!secretKey) {
    throw new Error("Missing ACCOUNT_HMAC_KEY");
  }

  const accountHmac = crypto
    .createHmac("sha256", secretKey)
    .update(
      `${bankName.trim().toUpperCase()}:${accountNumber.replace(/[\s-]/g, "")}`,
    )
    .digest("hex");

  const snapshot = await db.collection("mock_bank_registry").get();

  for (const doc of snapshot.docs) {
    const record = doc.data();

    if (
      record.businessName?.trim().toLowerCase() ===
        businessName.trim().toLowerCase() &&
      record.bankName?.trim().toLowerCase() === bankName.trim().toLowerCase() &&
      record.accountNumberHmac === accountHmac &&
      record.status === "active"
    ) {
      return true;
    }
  }

  return false;
}

// Test with fictional details
verifyBankDetails("Lagenda House & Cafe", "Maybank", "111122223333")
  .then((verified) => {
    console.log(
      verified
        ? "Bank details verified successfully"
        : "Bank verification failed",
    );
  })
  .catch((error) => {
    console.error("Verification error:", error.message);
    process.exitCode = 1;
  });
