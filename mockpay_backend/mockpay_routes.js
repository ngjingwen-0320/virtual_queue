const express = require("express");
const crypto = require("crypto");
const { rateLimit } = require("express-rate-limit");
const { FieldValue, Timestamp } = require("firebase-admin/firestore");

module.exports = function createMockPayRouter({
  db,
  authenticateUser,
  verifyRestaurantOwner,
  secret = process.env.ACCOUNT_HMAC_KEY,
  sendOtpEmail,
  bankClient,
  rateLimits = true,
}) {
  const router = express.Router();

  const DEPOSIT_PER_PAX_CENTS = 1000;
  const OTP_EXPIRY_MS = 5 * 60 * 1000;
  const SESSION_EXPIRY_MS = 5 * 60 * 1000;
  const MAX_OTP_ATTEMPTS = 5;

  if (!secret) {
    throw new Error("ACCOUNT_HMAC_KEY is missing");
  }

  // ========================================
  // RATE LIMITERS
  // ========================================

  const verificationLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: rateLimits ? 30 : 100000,
    keyGenerator: (req) => req.user.uid,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    message: {
      message: "Too many requests. Please try again later.",
    },
  });

  const otpRequestLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: rateLimits ? 3 : 100000,
    keyGenerator: (req) => req.user.uid,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    message: {
      message: "Too many OTP requests. Please try again later.",
    },
  });

  // ========================================
  // HELPER FUNCTIONS
  // ========================================

  function sendError(res, status, message) {
    return res.status(status).json({ message });
  }

  function sha256(value) {
    return crypto.createHash("sha256").update(value).digest("hex");
  }

  function getTokenHash(req) {
    const authorization = req.headers.authorization || "";

    if (!authorization.startsWith("Bearer ")) {
      throw new Error("Firebase ID token is missing");
    }

    return sha256(authorization.substring(7));
  }

  function generateAccountHmac(bankName, accountNumber) {
    return crypto
      .createHmac("sha256", secret)
      .update(`${bankName}:${accountNumber}`)
      .digest("hex");
  }

  function generateOtpHmac(uid, otp) {
    return crypto
      .createHmac("sha256", secret)
      .update(`${uid}:${otp}`)
      .digest("hex");
  }

  function safeHashEqual(a, b) {
    if (typeof a !== "string" || typeof b !== "string") {
      return false;
    }

    if (!/^[a-fA-F0-9]{64}$/.test(a) || !/^[a-fA-F0-9]{64}$/.test(b)) {
      return false;
    }

    return crypto.timingSafeEqual(Buffer.from(a, "hex"), Buffer.from(b, "hex"));
  }

  function normalizeName(value) {
    return value.trim().toLowerCase();
  }

  function validId(value) {
    return (
      typeof value === "string" &&
      /^[A-Za-z0-9_& -]{1,128}$/.test(value) &&
      value !== "." &&
      value !== ".."
    );
  }

  function getValidPax(reservation) {
    const pax = reservation.pax;

    if (!Number.isInteger(pax) || pax < 1 || pax > 8) {
      return null;
    }

    return pax;
  }

  function isCancelled(reservation) {
    const status = String(reservation.status || "").toLowerCase();

    return ["cancelled", "completed", "rejected"].includes(status);
  }

  // ========================================
  // EMAILJS
  // ========================================

  function isEmailJsConfigured() {
    return Boolean(
      process.env.EMAILJS_SERVICE_ID &&
      process.env.EMAILJS_TEMPLATE_ID &&
      process.env.EMAILJS_PUBLIC_KEY &&
      process.env.EMAILJS_PRIVATE_KEY,
    );
  }

  async function sendMockPayOtpEmail(
    email,
    otp,
    userName = "Restaurant Owner",
  ) {
    if (!sendOtpEmail && !isEmailJsConfigured()) {
      throw new Error("EmailJS is not configured");
    }

    if (sendOtpEmail) return sendOtpEmail(email, otp, userName);

    const response = await fetch(
      "https://api.emailjs.com/api/v1.0/email/send",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          service_id: process.env.EMAILJS_SERVICE_ID,
          template_id: process.env.EMAILJS_TEMPLATE_ID,
          user_id: process.env.EMAILJS_PUBLIC_KEY,
          accessToken: process.env.EMAILJS_PRIVATE_KEY,
          template_params: {
            user_email: email,
            user_name: userName,
            otp_code: otp,
          },
        }),
        signal: AbortSignal.timeout(15000),
      },
    );

    if (!response.ok) {
      const message = "Delivery rejected";

      console.error("EmailJS delivery failed:", response.status, message);

      throw new Error("EmailJS delivery failed");
    }

    return true;
  }

  const BANKS = [
    "Maybank2u",
    "CIMB Clicks",
    "Public Bank",
    "RHB Now",
    "Hong Leong Connect",
    "AmBank",
    "Bank Islam",
    "Bank Rakyat",
  ];
  async function otpContext(req) {
    if (req.body.paymentId !== undefined) {
      if (!validId(req.body.paymentId)) {
        const e = new Error("Invalid payment ID");
        e.status = 400;
        throw e;
      }
      const doc = await db
        .collection("mock_payments")
        .doc(req.body.paymentId)
        .get();
      const payment = doc.data();
      if (!payment || payment.customerUid !== req.user.uid) {
        const e = new Error("Payment access denied");
        e.status = 403;
        throw e;
      }
      if (
        payment.status !== "pending" ||
        !payment.expiresAt ||
        payment.expiresAt.toMillis() <= Date.now()
      ) {
        const e = new Error("Payment expired or unavailable");
        e.status = 409;
        throw e;
      }
      return `payment:${doc.id}:${payment.attemptId}`;
    }
    const brandId = await getOwnedBrandId(req.user.uid);
    if (!brandId) {
      const e = new Error("Restaurant ownership verification failed");
      e.status = 403;
      throw e;
    }
    return `merchant:${brandId}`;
  }
  function otpKey(uid, context) {
    return sha256(`${uid}:${context}`);
  }

  // ========================================
  // REQUIRE VERIFIED MOCKPAY OTP
  // ========================================

  async function requireOtp(req, res, next) {
    try {
      const context = await otpContext(req);
      const sessionDoc = await db
        .collection("mockpay_sessions")
        .doc(otpKey(req.user.uid, context))
        .get();

      if (!sessionDoc.exists) {
        return sendError(res, 403, "MockPay OTP verification required");
      }

      const session = sessionDoc.data();

      if (
        session.context !== context ||
        !session.expiresAt ||
        session.expiresAt.toMillis() <= Date.now()
      ) {
        return sendError(res, 403, "MockPay OTP session expired or invalid");
      }

      next();
    } catch (error) {
      console.error("OTP session check failed:", error.message);

      return sendError(res, 500, "OTP session verification failed");
    }
  }

  // ========================================
  // REQUIRE CUSTOMER ROLE
  // ========================================

  async function requireCustomer(req, res, next) {
    try {
      const userDoc = await db.collection("users").doc(req.user.uid).get();

      if (!userDoc.exists || userDoc.data().role !== "customer") {
        return sendError(res, 403, "Customer access required");
      }

      next();
    } catch (error) {
      console.error("Customer authorization failed:", error.message);

      return sendError(res, 500, "Customer authorization failed");
    }
  }

  // ========================================
  // VERIFY AUTHENTICATED RESTAURANT
  // ========================================

  async function getOwnedBrandId(uid) {
    const userDoc = await db.collection("users").doc(uid).get();

    if (!userDoc.exists) {
      return null;
    }

    const user = userDoc.data();

    if (user.role !== "restaurant") {
      return null;
    }

    const brandId = user.brand_id;

    if (!validId(brandId)) {
      return null;
    }

    const brandDoc = await db
      .collection("restaurant_brands")
      .doc(brandId)
      .get();

    if (!brandDoc.exists || brandDoc.data().owner_id !== uid) {
      return null;
    }

    return brandId;
  }

  // ========================================
  // 1. REQUEST OTP
  // POST /api/mockpay/otp/request
  // ========================================

  router.post(
    "/otp/request",
    authenticateUser,
    otpRequestLimiter,
    async (req, res) => {
      try {
        if (!sendOtpEmail && !isEmailJsConfigured()) {
          return sendError(res, 503, "EmailJS OTP service is not configured");
        }

        if (!req.user.email) {
          return sendError(res, 400, "Authenticated email is unavailable");
        }

        const uid = req.user.uid;
        const context = await otpContext(req);
        const key = otpKey(uid, context);

        const otp = crypto.randomInt(0, 1000000).toString().padStart(6, "0");

        const challengeRef = db.collection("mockpay_otp_challenges").doc(key);

        const sessionRef = db.collection("mockpay_sessions").doc(key);

        const nonce = crypto.randomUUID();
        const otpHash = generateOtpHmac(`${uid}:${context}:${nonce}`, otp);
        if (req.body.paymentId && !BANKS.includes(req.body.bankName))
          return sendError(res, 400, "Select a supported demo bank");
        const tokenHash = getTokenHash(req);

        await db.runTransaction(async (tx) => {
          const existingSession = await tx.get(sessionRef);
          const prior = await tx.get(challengeRef);
          if (
            prior.exists &&
            Date.now() - prior.data().createdAt.toMillis() < 60000
          ) {
            const e = new Error("Wait one minute before resending");
            e.status = 429;
            throw e;
          }

          tx.set(challengeRef, {
            otpHash,
            context,
            nonce,
            bankName: req.body.paymentId ? req.body.bankName : null,
            tokenHash,
            attempts: 0,
            expiresAt: Timestamp.fromMillis(Date.now() + OTP_EXPIRY_MS),
            createdAt: FieldValue.serverTimestamp(),
          });

          if (existingSession.exists) {
            tx.delete(sessionRef);
          }
        });

        try {
          await sendMockPayOtpEmail(
            req.user.email,
            otp,
            req.user.name || "User",
          );
        } catch (emailError) {
          await db.runTransaction(async (tx) => {
            const current = await tx.get(challengeRef);

            if (
              current.exists &&
              current.data().tokenHash === tokenHash &&
              safeHashEqual(current.data().otpHash, otpHash)
            ) {
              tx.delete(challengeRef);
            }
          });

          throw emailError;
        }

        return res.json({
          message: "OTP sent successfully",
        });
      } catch (error) {
        if (error.status) return sendError(res, error.status, error.message);
        console.error("MockPay OTP sending failed:", error.message);

        return sendError(res, 500, "Unable to send OTP");
      }
    },
  );

  // ========================================
  // 2. VERIFY OTP
  // POST /api/mockpay/otp/verify
  // ========================================

  router.post(
    "/otp/verify",
    authenticateUser,
    verificationLimiter,
    async (req, res) => {
      try {
        const { otp } = req.body;

        if (typeof otp !== "string" || !/^[0-9]{6}$/.test(otp)) {
          return sendError(res, 400, "Invalid OTP format");
        }

        const uid = req.user.uid;
        const context = await otpContext(req);
        const key = otpKey(uid, context);

        const challengeRef = db.collection("mockpay_otp_challenges").doc(key);

        const sessionRef = db.collection("mockpay_sessions").doc(key);

        const verified = await db.runTransaction(async (tx) => {
          const challengeDoc = await tx.get(challengeRef);

          if (!challengeDoc.exists) {
            return false;
          }

          const challenge = challengeDoc.data();

          if (
            !challenge.expiresAt ||
            challenge.expiresAt.toMillis() <= Date.now() ||
            challenge.attempts >= MAX_OTP_ATTEMPTS ||
            challenge.context !== context
          ) {
            tx.delete(challengeRef);
            return false;
          }

          const enteredHash = generateOtpHmac(
            `${uid}:${context}:${challenge.nonce}`,
            otp,
          );

          if (!safeHashEqual(challenge.otpHash, enteredHash)) {
            tx.update(challengeRef, {
              attempts: FieldValue.increment(1),
            });

            return false;
          }

          tx.delete(challengeRef);

          tx.set(sessionRef, {
            context,
            bankName: challenge.bankName || null,
            verifiedAt: FieldValue.serverTimestamp(),
            expiresAt: Timestamp.fromMillis(Date.now() + SESSION_EXPIRY_MS),
          });

          return true;
        });

        if (!verified) {
          return sendError(res, 403, "OTP verification failed");
        }

        return res.json({
          verified: true,
          message: "MockPay OTP verified",
        });
      } catch (error) {
        if (error.status) return sendError(res, error.status, error.message);
        console.error("OTP verification failed:", error.message);

        return sendError(res, 500, "OTP verification error");
      }
    },
  );

  // ========================================
  // 3. REGISTER MERCHANT
  // POST /api/mockpay/register-merchant
  // ========================================

  router.post(
    "/register-merchant",
    authenticateUser,
    verificationLimiter,
    requireOtp,
    verifyRestaurantOwner,
    async (req, res) => {
      try {
        const { businessName, bankName, accountNumber } = req.body;

        if (
          typeof businessName !== "string" ||
          typeof bankName !== "string" ||
          typeof accountNumber !== "string"
        ) {
          return sendError(res, 400, "All bank details are required");
        }

        const business = normalizeName(businessName);
        const bank = bankName.trim().toUpperCase();
        const account = accountNumber.replace(/[\s-]/g, "");

        if (!business || !bank || !/^[0-9]{6,20}$/.test(account)) {
          return sendError(res, 400, "Invalid bank details");
        }

        if (business !== normalizeName(req.restaurant.businessName)) {
          return sendError(res, 400, "Business name does not match restaurant");
        }

        const accountHmac = generateAccountHmac(bank, account);

        const registry = await db
          .collection("mock_bank_registry")
          .where("accountNumberHmac", "==", accountHmac)
          .get();

        const bankVerified = registry.docs.some((doc) => {
          const record = doc.data();

          return (
            record.status === "active" &&
            normalizeName(record.businessName || "") === business &&
            (record.bankName || "").trim().toUpperCase() === bank
          );
        });

        if (!bankVerified) {
          return sendError(res, 400, "Bank verification failed");
        }

        const merchantRef = db
          .collection("mock_merchants")
          .doc(req.restaurant.brandId);

        const merchantId = `MP_${crypto.randomUUID()}`;

        const created = await db.runTransaction(async (tx) => {
          const existingMerchant = await tx.get(merchantRef);
          const context = `merchant:${req.restaurant.brandId}`;
          const sessionRef = db
            .collection("mockpay_sessions")
            .doc(otpKey(req.user.uid, context));
          const session = (await tx.get(sessionRef)).data();
          const brand = (
            await tx.get(
              db.collection("restaurant_brands").doc(req.restaurant.brandId),
            )
          ).data();
          if (
            brand?.owner_id !== req.user.uid ||
            !session ||
            session.context !== context ||
            session.expiresAt.toMillis() <= Date.now()
          ) {
            const e = new Error("MockPay OTP verification required");
            e.status = 403;
            throw e;
          }

          if (existingMerchant.exists) {
            return false;
          }

          tx.delete(sessionRef);
          tx.create(merchantRef, {
            merchantId,
            brandId: req.restaurant.brandId,
            ownerUid: req.user.uid,
            businessName: req.restaurant.businessName,
            bankName: bankName.trim(),
            accountLast4: account.slice(-4),
            verified: true,
            paymentEnabled: true,
            status: "active",
            balanceCents: 0,
            createdAt: FieldValue.serverTimestamp(),
          });

          return true;
        });

        if (!created) {
          return sendError(res, 409, "Merchant already registered");
        }

        return res.status(201).json({
          message: "MockPay merchant registered successfully",
          merchantId,
          status: "active",
          paymentEnabled: true,
        });
      } catch (error) {
        if (error.status) return sendError(res, error.status, error.message);
        console.error("Merchant registration failed:", error.message);

        return sendError(res, 500, "Merchant registration failed");
      }
    },
  );

  // ========================================
  // 4. GET MERCHANT STATUS
  // GET /api/mockpay/merchant/status
  // ========================================

  router.get("/merchant/status", authenticateUser, async (req, res) => {
    try {
      const brandId = await getOwnedBrandId(req.user.uid);

      if (!brandId) {
        return sendError(res, 403, "Restaurant ownership verification failed");
      }

      const merchantDoc = await db
        .collection("mock_merchants")
        .doc(brandId)
        .get();

      if (!merchantDoc.exists) {
        return res.json({
          registered: false,
          status: "not_registered",
          verified: false,
          paymentEnabled: false,
        });
      }

      const merchant = merchantDoc.data();

      return res.json({
        registered: true,
        merchantId: merchant.merchantId,
        brandId,
        businessName: merchant.businessName,
        status: merchant.status,
        verified: merchant.verified === true,
        paymentEnabled: merchant.paymentEnabled === true,
        bankName: merchant.bankName,
        accountLast4: merchant.accountLast4,
        balanceCents: merchant.balanceCents || 0,
      });
    } catch (error) {
      if (error.status) return sendError(res, error.status, error.message);
      console.error("Merchant status lookup failed:", error.message);

      return sendError(res, 500, "Unable to retrieve merchant status");
    }
  });

  // ========================================
  // 5. INITIATE PAYMENT
  // POST /api/mockpay/payments/initiate
  // ========================================

  router.post(
    "/payments/initiate",
    authenticateUser,
    verificationLimiter,
    requireCustomer,
    async (req, res) => {
      try {
        const { reservationId } = req.body;

        if (!validId(reservationId)) {
          return sendError(res, 400, "Invalid reservation ID");
        }

        const reservationRef = db.collection("reservations").doc(reservationId);

        const paymentRef = db.collection("mock_payments").doc(reservationId);

        const result = await db.runTransaction(async (tx) => {
          const reservationDoc = await tx.get(reservationRef);

          if (!reservationDoc.exists) {
            return {
              error: "Reservation not found",
              code: 404,
            };
          }

          const reservation = reservationDoc.data();

          if (reservation.customer_id !== req.user.uid) {
            return {
              error: "Reservation access denied",
              code: 403,
            };
          }

          if (
            !validId(reservation.brand_id) ||
            !validId(reservation.restaurant_id) ||
            !["PENDING", "CONFIRMED"].includes(
              String(reservation.status).toUpperCase(),
            ) ||
            !reservation.reservation_datetime ||
            reservation.reservation_datetime.toMillis() <= Date.now() ||
            isCancelled(reservation)
          ) {
            return {
              error: "Reservation not payable",
              code: 409,
            };
          }

          const pax = getValidPax(reservation);

          if (pax === null) {
            return {
              error: "Invalid guest count",
              code: 400,
            };
          }

          const depositCents = pax * DEPOSIT_PER_PAX_CENTS;

          const merchantRef = db
            .collection("mock_merchants")
            .doc(reservation.brand_id);

          const merchantDoc = await tx.get(merchantRef);

          const existingPayment = await tx.get(paymentRef);

          if (!merchantDoc.exists) {
            return {
              error: "Merchant unavailable",
              code: 409,
            };
          }

          const merchant = merchantDoc.data();

          if (
            merchant.status !== "active" ||
            merchant.verified !== true ||
            merchant.paymentEnabled !== true
          ) {
            return {
              error: "Merchant unavailable",
              code: 409,
            };
          }

          if (reservation.payment_status === "paid") {
            return {
              paymentId: paymentRef.id,
              status: "paid",
              amountCents: depositCents,
            };
          }

          if (
            existingPayment.exists &&
            existingPayment.data().status === "pending" &&
            existingPayment.data().expiresAt?.toMillis() > Date.now()
          ) {
            const payment = existingPayment.data();

            if (
              payment.customerUid !== req.user.uid ||
              payment.brandId !== reservation.brand_id ||
              payment.status !== "pending" ||
              payment.amountCents !== depositCents ||
              payment.pax !== pax
            ) {
              return {
                error: "Existing payment conflict",
                code: 409,
              };
            }

            return {
              paymentId: paymentRef.id,
              merchantId: payment.merchantId,
              amountCents: payment.amountCents,
              currency: "MYR",
              status: "pending",
            };
          }

          if (
            existingPayment.exists &&
            ["paid", "refunded"].includes(existingPayment.data().status)
          )
            return { error: "Payment already processed", code: 409 };
          tx.set(paymentRef, {
            reservationId,
            restaurantId: reservation.restaurant_id,
            restaurantName: reservation.restaurant_name,
            attemptId: crypto.randomUUID(),
            expiresAt: Timestamp.fromMillis(Date.now() + 15 * 60 * 1000),
            customerUid: req.user.uid,
            brandId: reservation.brand_id,
            merchantId: merchant.merchantId,
            pax,
            amountCents: depositCents,
            currency: "MYR",
            status: "pending",
            createdAt: FieldValue.serverTimestamp(),
          });

          tx.update(reservationRef, {
            payment_status: "pending",
            mockpay_payment_id: paymentRef.id,
            deposit_amount_cents: depositCents,
          });

          return {
            paymentId: paymentRef.id,
            merchantId: merchant.merchantId,
            amountCents: depositCents,
            currency: "MYR",
            status: "pending",
          };
        });

        if (result.error) {
          return sendError(res, result.code, result.error);
        }

        return res.json(result);
      } catch (error) {
        if (error.status) return sendError(res, error.status, error.message);
        console.error("Payment initiation failed:", error.message);

        return sendError(res, 500, "Payment initiation failed");
      }
    },
  );

  // ========================================
  // 6. CONFIRM SIMULATED PAYMENT
  // POST /api/mockpay/payments/confirm
  // ========================================

  router.post(
    "/payments/confirm",
    authenticateUser,
    verificationLimiter,
    requireCustomer,
    async (req, res, next) => {
      try {
        if (!validId(req.body.paymentId))
          return sendError(res, 400, "Invalid payment ID");
        const result =
          await require("./payment_authorization").authorizePayment({
            db,
            bankClient,
            uid: req.user.uid,
            email: req.user.email,
            paymentId: req.body.paymentId,
          });
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  // ========================================
  // 7. GET PAYMENT STATUS
  // GET /api/mockpay/payments/:paymentId
  // ========================================

  router.post(
    "/payments/cancel",
    authenticateUser,
    requireCustomer,
    async (req, res, next) => {
      try {
        if (!validId(req.body.paymentId))
          return sendError(res, 400, "Invalid payment ID");
        const result = await db.runTransaction(async (tx) => {
          const paymentRef = db
            .collection("mock_payments")
            .doc(req.body.paymentId);
          const payment = (await tx.get(paymentRef)).data();
          if (!payment || payment.customerUid !== req.user.uid) {
            const e = new Error("Payment access denied");
            e.status = 403;
            throw e;
          }
          if (["paid", "refunded"].includes(payment.status)) {
            const e = new Error("Payment already processed");
            e.status = 409;
            throw e;
          }
          const reservationRef = db
            .collection("reservations")
            .doc(payment.reservationId);
          const reservation = (await tx.get(reservationRef)).data();
          const key = otpKey(
            req.user.uid,
            `payment:${paymentRef.id}:${payment.attemptId}`,
          );
          tx.update(paymentRef, { status: "cancelled" });
          if (reservation?.mockpay_payment_id === paymentRef.id)
            tx.update(reservationRef, { payment_status: "unpaid" });
          tx.delete(db.collection("mockpay_sessions").doc(key));
          tx.delete(db.collection("mockpay_otp_challenges").doc(key));
          return { status: "cancelled" };
        });
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    "/payments",
    authenticateUser,
    requireCustomer,
    async (req, res, next) => {
      try {
        const docs = await db
          .collection("mock_payments")
          .where("customerUid", "==", req.user.uid)
          .get();
        const payments = docs.docs
          .map((doc) => {
            const p = doc.data();
            return {
              paymentId: doc.id,
              restaurantName: p.restaurantName,
              amountCents: p.amountCents,
              status:
                p.status === "pending" && p.expiresAt?.toMillis() <= Date.now()
                  ? "expired"
                  : p.status,
              createdAt: p.createdAt?.toMillis() || 0,
            };
          })
          .sort((a, b) => b.createdAt - a.createdAt);
        res.json({ payments });
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    "/payments/:paymentId",
    authenticateUser,
    requireCustomer,
    async (req, res) => {
      try {
        const { paymentId } = req.params;

        if (!validId(paymentId)) {
          return sendError(res, 400, "Invalid payment ID");
        }

        const paymentDoc = await db
          .collection("mock_payments")
          .doc(paymentId)
          .get();

        if (!paymentDoc.exists) {
          return sendError(res, 404, "Payment not found");
        }

        const payment = paymentDoc.data();

        if (payment.customerUid !== req.user.uid) {
          return sendError(res, 403, "Payment access denied");
        }

        return res.json({
          paymentId,
          reservationId: payment.reservationId,
          merchantId: payment.merchantId,
          pax: payment.pax,
          amountCents: payment.amountCents,
          currency: payment.currency,
          status:
            payment.status === "pending" &&
            payment.expiresAt?.toMillis() <= Date.now()
              ? "expired"
              : payment.status,
          restaurantName: payment.restaurantName,
          bankName: payment.bankName || null,
          receiptEmail: payment.receiptEmail || null,
          paidAt: payment.paidAt?.toDate().toISOString() || null,
          refundedAt: payment.refundedAt?.toDate().toISOString() || null,
          callbackSignatureVerified: payment.callbackSignatureVerified === true,
          callbackEventId: payment.callbackEventId || null,
          callbackVerifiedAt:
            payment.callbackVerifiedAt?.toDate().toISOString() || null,
        });
      } catch (error) {
        if (error.status) return sendError(res, error.status, error.message);
        console.error("Payment lookup failed:", error.message);

        return sendError(res, 500, "Unable to retrieve payment");
      }
    },
  );

  return router;
};
