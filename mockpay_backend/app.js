const express = require("express");
const crypto = require("crypto");
const { rateLimit } = require("express-rate-limit");

module.exports = function createApp({
  db,
  auth,
  secret,
  sendOtpEmail,
  callbackSecret,
  bankClient,
  rateLimits = true,
}) {
  if (!secret) throw new Error("ACCOUNT_HMAC_KEY is missing");
  if (callbackSecret === secret)
    throw new Error("Callback signing key must differ from the bank/OTP key");
  const callback = require("./bank_callback").createCallbackProcessor({
    db,
    callbackSecret,
  });
  if (!bankClient || typeof bankClient.authorise !== "function")
    throw new Error("Mock-bank client is required");
  const app = express();

  app.disable("x-powered-by");
  app.post(
    "/api/mockpay/bank/callback",
    rateLimits
      ? rateLimit({ windowMs: 60000, limit: 100 })
      : (req, res, next) => next(),
    express.raw({ type: "application/json", limit: "10kb" }),
    callback.handler,
  );
  app.use(express.json({ limit: "10kb" }));
  app.use((req, res, next) => {
    if (
      req.method === "POST" &&
      (!req.body || typeof req.body !== "object" || Array.isArray(req.body))
    ) {
      return res
        .status(400)
        .json({ message: "A JSON object body is required" });
    }
    next();
  });

  async function authenticateUser(req, res, next) {
    try {
      const header = req.headers.authorization;

      if (typeof header !== "string" || !header.startsWith("Bearer ")) {
        return res.status(401).json({
          message: "Authentication required",
        });
      }

      const token = header.substring(7).trim();

      if (!token) {
        return res.status(401).json({
          message: "Authentication required",
        });
      }

      const decodedToken = await auth.verifyIdToken(token, true);

      if (!decodedToken.email_verified) {
        return res.status(403).json({
          message: "Email verification required",
        });
      }

      req.user = decodedToken;
      next();
    } catch (error) {
      return res.status(401).json({
        message: "Invalid or expired authentication token",
      });
    }
  }

  async function verifyRestaurantOwner(req, res, next) {
    try {
      const { brandId } = req.body;

      if (
        typeof brandId !== "string" ||
        !brandId.trim() ||
        brandId.includes("/")
      ) {
        return res.status(400).json({
          message: "Valid restaurant brand ID is required",
        });
      }

      const userDoc = await db.collection("users").doc(req.user.uid).get();

      const brandDoc = await db
        .collection("restaurant_brands")
        .doc(brandId)
        .get();

      if (!userDoc.exists || !brandDoc.exists) {
        return res.status(403).json({
          message: "Restaurant access denied",
        });
      }

      const userData = userDoc.data();
      const brandData = brandDoc.data();

      if (
        userData.role !== "restaurant" ||
        userData.brand_id !== brandId ||
        brandData.owner_id !== req.user.uid
      ) {
        return res.status(403).json({
          message: "Restaurant access denied",
        });
      }

      req.restaurant = {
        brandId,
        businessName: brandData.name,
      };

      next();
    } catch (error) {
      console.error("Restaurant ownership verification failed");

      return res.status(500).json({
        message: "Unable to verify restaurant ownership",
      });
    }
  }

  const verificationLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: rateLimits ? 5 : 100000,
    keyGenerator: (req) => req.user.uid,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    message: {
      message: "Too many verification attempts. Try again later.",
    },
  });

  app.get("/api/health", (req, res) => {
    res.json({
      status: "success",
      message: "MockPay backend is running",
    });
  });

  if (process.env.NODE_ENV !== "production") {
    app.get("/api/test-firestore", async (req, res) => {
      try {
        await db.collection("mock_bank_registry").limit(1).get();

        return res.json({
          connected: true,
          message: "Firebase Firestore connected successfully",
        });
      } catch (error) {
        console.error("Firestore connection failed");

        return res.status(500).json({
          connected: false,
          message: "Firestore connection failed",
        });
      }
    });
  }

  app.post(
    "/api/mockpay/verify-bank",
    authenticateUser,
    verificationLimiter,
    verifyRestaurantOwner,
    async (req, res) => {
      try {
        const { bankName, accountNumber } = req.body;

        if (
          typeof bankName !== "string" ||
          typeof accountNumber !== "string" ||
          !bankName.trim()
        ) {
          return res.status(400).json({
            message: "Invalid bank details",
          });
        }

        const normalizedBank = bankName.trim().toUpperCase();

        const normalizedAccount = accountNumber.replace(/[\s-]/g, "");

        if (!/^[0-9]{6,20}$/.test(normalizedAccount)) {
          return res.status(400).json({
            message: "Invalid bank account number",
          });
        }

        const accountHmac = crypto
          .createHmac("sha256", secret)
          .update(`${normalizedBank}:${normalizedAccount}`)
          .digest("hex");

        const snapshot = await db
          .collection("mock_bank_registry")
          .where("accountNumberHmac", "==", accountHmac)
          .get();

        const verified = snapshot.docs.some((doc) => {
          const record = doc.data();

          return (
            record.businessName?.trim().toLowerCase() ===
              req.restaurant.businessName.trim().toLowerCase() &&
            record.bankName?.trim().toUpperCase() === normalizedBank &&
            record.accountNumberHmac === accountHmac &&
            record.status === "active"
          );
        });

        return res.json({
          verified,
          message: verified
            ? "Bank details matched successfully"
            : "Unable to verify bank details",
        });
      } catch (error) {
        console.error("Bank verification failed");

        return res.status(500).json({
          message: "Verification service unavailable",
        });
      }
    },
  );

  const createMockPayRouter = require("./mockpay_routes");

  app.use(
    "/api/mockpay",
    createMockPayRouter({
      db,
      authenticateUser,
      verifyRestaurantOwner,
      secret,
      sendOtpEmail,
      bankClient,
      rateLimits,
    }),
  );

  app.use(
    "/api/mockpay",
    require("./reservation_routes")({ db, authenticateUser }),
  );

  app.use((error, req, res, next) => {
    if (res.headersSent) return next(error);
    res
      .status(error.status || 500)
      .json({
        message: error.status ? error.message : "MockPay service unavailable",
      });
  });

  return app;
};
