const { test, before, beforeEach, after } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const crypto = require("node:crypto");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  query,
  where,
  getDocs,
  writeBatch,
  serverTimestamp,
  setLogLevel,
} = require("firebase/firestore");
const createApp = require("../app");
const { createMockBank } = require("../mock_bank");
const { createBankClient } = require("../payment_authorization");
const { sign } = require("../callback_signature");

if (
  !process.env.FIRESTORE_EMULATOR_HOST ||
  !process.env.FIREBASE_AUTH_EMULATOR_HOST ||
  process.env.GCLOUD_PROJECT !== "demo-mockpay"
)
  throw new Error("Run only in the demo-mockpay emulators");
const secret = "test-only-secret-not-for-deployment";
const admin = initializeApp({ projectId: "demo-mockpay" });
const db = getFirestore(admin);
let env, server, base, sent, bankServer, bankBase;
const callbackSecret = "test-only-independent-callback-key-32-bytes";
const requestSecret = "test-only-independent-bank-request-key-32-bytes";
let bankRequests = [],
  deliverCallbacks = true,
  loseBankResponse = false;
const bankClient = {
  authorise: async (payload) => {
    bankRequests.push(payload);
    if (!deliverCallbacks) return { status: "held-for-test" };
    const result = await createBankClient({
      url: bankBase,
      requestSecret,
    }).authorise(payload);
    if (loseBankResponse) throw new Error("Simulated lost response");
    return result;
  },
};
const users = {
  customer: {
    uid: "customer",
    email: "customer@example.test",
    email_verified: true,
  },
  other: { uid: "other", email: "other@example.test", email_verified: true },
  owner: { uid: "owner", email: "owner@example.test", email_verified: true },
  attacker: {
    uid: "attacker",
    email: "attacker@example.test",
    email_verified: true,
  },
  unverified: { uid: "customer", email_verified: false },
};
const auth = {
  async verifyIdToken(token, revoked) {
    assert.equal(revoked, true);
    if (!users[token]) throw new Error("Invalid, expired or revoked token");
    return users[token];
  },
};
const appOptions = {
  db,
  auth,
  secret,
  callbackSecret,
  bankClient,
  sendOtpEmail: async (email, otp) => {
    sent[email] = otp;
  },
  rateLimits: false,
};
async function listen(app) {
  const s = await new Promise((resolve) => {
    const running = app.listen(0, "127.0.0.1", () => resolve(running));
  });
  return {
    server: s,
    base: `http://127.0.0.1:${s.address().port}/api/mockpay`,
  };
}
async function request(path, body, token = "customer", url = base) {
  const response = await fetch(url + path, {
    method: body === undefined ? "GET" : "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: response.status, body: await response.json() };
}
const reservation = (reservationId = "booking") => ({
  reservation_id: reservationId,
  customer_id: "customer",
  customer_name: "Demo Customer",
  customer_phone: "0123456789",
  brand_id: "brand",
  restaurant_id: "branch",
  restaurant_name: "Demo Restaurant",
  booking_type: "SELF",
  guest_name: "",
  guest_phone: "",
  pax: 3,
  special_request: "",
  reservation_datetime: new Date(Date.now() + 3 * 86400000).toISOString(),
});
async function book(key = "booking") {
  const result = await request("/reservations", reservation(key));
  assert.equal(result.status, 200, JSON.stringify(result.body));
  return key;
}
async function initiate(key = "booking") {
  const result = await request("/payments/initiate", { reservationId: key });
  assert.equal(result.status, 200, JSON.stringify(result.body));
  return result.body.paymentId;
}
async function verify(paymentId) {
  const body = paymentId ? { paymentId, bankName: "Maybank2u" } : {};
  const token = paymentId ? "customer" : "owner";
  assert.equal((await request("/otp/request", body, token)).status, 200);
  const otp = sent[users[token].email];
  assert.match(otp, /^\d{6}$/);
  const verified = await request(
    "/otp/verify",
    { ...(paymentId ? { paymentId } : {}), otp },
    token,
  );
  assert.equal(verified.status, 200, JSON.stringify(verified.body));
  return otp;
}
async function pay(key = "booking") {
  await book(key);
  const paymentId = await initiate(key);
  await verify(paymentId);
  assert.equal((await request("/payments/confirm", { paymentId })).status, 200);
  return paymentId;
}
before(async () => {
  setLogLevel("silent");
  env = await initializeTestEnvironment({
    projectId: "demo-mockpay",
    firestore: {
      host: "127.0.0.1",
      port: 8180,
      rules: fs.readFileSync(
        require("node:path").join(__dirname, "../../firestore.rules"),
        "utf8",
      ),
    },
  });
  ({ server, base } = await listen(createApp(appOptions)));
  const bank = await listen(
    createMockBank({
      requestSecret,
      callbackSecret,
      callbackUrl: base + "/bank/callback",
    }),
  );
  bankServer = bank.server;
  bankBase = bank.base.replace("/api/mockpay", "");
});
beforeEach(async () => {
  await env.clearFirestore();
  sent = {};
  bankRequests = [];
  deliverCallbacks = true;
  loseBankResponse = false;
  await Promise.all([
    db
      .doc("users/customer")
      .set({
        role: "customer",
        name: "Demo Customer",
        email: users.customer.email,
      }),
    db.doc("users/other").set({ role: "customer" }),
    db
      .doc("users/owner")
      .set({
        role: "restaurant",
        brand_id: "brand",
        restaurant_ids: ["branch"],
      }),
    db
      .doc("users/attacker")
      .set({
        role: "restaurant",
        brand_id: "otherbrand",
        restaurant_ids: ["otherbranch"],
      }),
    db
      .doc("restaurant_brands/brand")
      .set({ owner_id: "owner", name: "Demo Restaurant" }),
    db
      .doc("restaurant_brands/brand/restaurants/branch")
      .set({ owner_id: "owner", brand_id: "brand", is_active: true }),
    db
      .doc("mock_merchants/brand")
      .set({
        merchantId: "MP_demo",
        ownerUid: "owner",
        businessName: "Demo Restaurant",
        verified: true,
        paymentEnabled: true,
        status: "active",
        balanceCents: 0,
      }),
    db
      .doc("mock_bank_registry/bank")
      .set({
        businessName: "Demo Restaurant",
        bankName: "MAYBANK",
        status: "active",
        accountNumberHmac: crypto
          .createHmac("sha256", secret)
          .update("MAYBANK:1234567890")
          .digest("hex"),
      }),
  ]);
});
after(async () => {
  if (bankServer) await new Promise((resolve) => bankServer.close(resolve));
  if (server) await new Promise((resolve) => server.close(resolve));
  if (env) await env.cleanup();
  await deleteApp(admin);
});

test("authentication denies missing, invalid, expired, revoked and unverified tokens", async () => {
  for (const token of [null, "invalid", "expired", "revoked"])
    assert.equal(
      (await request("/merchant/status", undefined, token)).status,
      401,
    );
  assert.equal(
    (await request("/merchant/status", undefined, "unverified")).status,
    403,
  );
});
test("real Firebase Auth emulator token passes authentication and ownership checks", async () => {
  const realAuth = getAuth(admin);
  try {
    await realAuth.deleteUser("owner");
  } catch (_) {}
  await realAuth.createUser({
    uid: "owner",
    email: "owner@example.test",
    password: "EmulatorOnly123!",
    emailVerified: true,
  });
  const response = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: "owner@example.test",
        password: "EmulatorOnly123!",
        returnSecureToken: true,
      }),
    },
  );
  const token = (await response.json()).idToken;
  assert.ok(token);
  const real = await listen(createApp({ ...appOptions, auth: realAuth }));
  try {
    assert.equal(
      (await request("/merchant/status", undefined, token, real.base)).status,
      200,
    );
  } finally {
    await new Promise((resolve) => real.server.close(resolve));
  }
});
test("authenticated bank matching normalizes values and rejects wrong details or owner", async () => {
  const details = {
    brandId: "brand",
    bankName: " maybank ",
    accountNumber: "1234-5678 90",
  };
  assert.equal(
    (await request("/verify-bank", details, "owner")).body.verified,
    true,
  );
  assert.equal(
    (
      await request(
        "/verify-bank",
        { ...details, accountNumber: "0000000000" },
        "owner",
      )
    ).body.verified,
    false,
  );
  assert.equal(
    (
      await request(
        "/verify-bank",
        { ...details, accountNumber: "abc" },
        "owner",
      )
    ).status,
    400,
  );
  assert.equal(
    (await request("/verify-bank", details, "attacker")).status,
    403,
  );
});
test("merchant registration requires bank matching and scoped OTP, prevents duplicates", async () => {
  await db.doc("mock_merchants/brand").delete();
  const details = {
    brandId: "brand",
    businessName: "Demo Restaurant",
    bankName: "Maybank",
    accountNumber: "1234567890",
  };
  assert.equal(
    (await request("/register-merchant", details, "owner")).status,
    403,
  );
  await verify();
  const result = await request("/register-merchant", details, "owner");
  assert.equal(result.status, 201);
  assert.equal(result.body.paymentEnabled, true);
  assert.equal(
    (await db.doc("mock_merchants/brand").get()).data().balanceCents,
    0,
  );
  assert.notEqual(
    (await request("/register-merchant", details, "owner")).status,
    200,
  );
});
test("backend calculates deposit; rejects forged payment fields and inactive merchants", async () => {
  assert.equal(
    (await request("/reservations", { ...reservation(), deposit_paid: true }))
      .status,
    400,
  );
  assert.equal(
    (await request("/reservations", { ...reservation(), pax: 9 })).status,
    400,
  );
  await book();
  assert.equal(
    (await db.doc("reservations/booking").get()).data().deposit_amount_cents,
    3000,
  );
  await db.doc("mock_merchants/brand").update({ paymentEnabled: false });
  assert.equal(
    (await request("/reservations", reservation("disabled"))).status,
    409,
  );
});
test("checkout starts without OTP; amount tampering does not change server amount", async () => {
  await book();
  const result = await request("/payments/initiate", {
    reservationId: "booking",
    amountCents: 1,
  });
  assert.equal(result.status, 200);
  assert.equal(result.body.amountCents, 3000);
  assert.equal(
    (await request("/payments/confirm", { paymentId: "booking" })).status,
    403,
  );
});
test("wrong and replayed OTPs fail; repeated guesses exhaust challenge", async () => {
  await book();
  const paymentId = await initiate();
  await request("/otp/request", { paymentId, bankName: "Maybank2u" });
  const real = sent[users.customer.email];
  const wrong = real === "000000" ? "111111" : "000000";
  for (let n = 0; n < 5; n++)
    assert.equal(
      (await request("/otp/verify", { paymentId, otp: wrong })).status,
      403,
    );
  assert.equal(
    (await request("/otp/verify", { paymentId, otp: real })).status,
    403,
  );
});
test("expired OTPs fail", async () => {
  await book();
  const paymentId = await initiate();
  await request("/otp/request", { paymentId, bankName: "Maybank2u" });
  const challenges = await db.collection("mockpay_otp_challenges").get();
  await challenges.docs[0].ref.update({
    expiresAt: Timestamp.fromMillis(Date.now() - 1),
  });
  assert.equal(
    (
      await request("/otp/verify", {
        paymentId,
        otp: sent[users.customer.email],
      })
    ).status,
    403,
  );
});
test("TAC is single-use and cannot confirm a different payment", async () => {
  await book();
  await book("second");
  const first = await initiate();
  const second = await initiate("second");
  const otp = await verify(first);
  assert.equal(
    (await request("/otp/verify", { paymentId: first, otp })).status,
    403,
  );
  assert.equal(
    (await request("/payments/confirm", { paymentId: second })).status,
    403,
  );
  assert.equal(
    (await request("/payments/confirm", { paymentId: first })).status,
    200,
  );
});
test("concurrent duplicate confirmations credit once and retain restaurant approval", async () => {
  await book();
  const paymentId = await initiate();
  await verify(paymentId);
  const results = await Promise.all(
    Array.from({ length: 3 }, () =>
      request("/payments/confirm", { paymentId }),
    ),
  );
  assert.ok(
    results.every((r) => r.status === 200),
    JSON.stringify(results),
  );
  assert.equal(
    (await db.doc("mock_merchants/brand").get()).data().balanceCents,
    3000,
  );
  const booking = (await db.doc("reservations/booking").get()).data();
  assert.equal(booking.status, "PENDING");
  assert.equal(booking.deposit_paid, true);
  assert.equal(
    (
      await request(
        "/reservations/action",
        { reservationId: "booking", action: "approve" },
        "owner",
      )
    ).status,
    200,
  );
  assert.equal(
    (await db.doc("reservations/booking").get()).data().status,
    "CONFIRMED",
  );
});
test("unpaid booking cannot be approved; another owner cannot approve", async () => {
  await book();
  assert.equal(
    (
      await request(
        "/reservations/action",
        { reservationId: "booking", action: "approve" },
        "owner",
      )
    ).status,
    409,
  );
  assert.equal(
    (
      await request(
        "/reservations/action",
        { reservationId: "booking", action: "approve" },
        "attacker",
      )
    ).status,
    403,
  );
});
test("unauthorized customer cannot view, pay or cancel another reservation", async () => {
  await book();
  const paymentId = await initiate();
  for (const path of [
    "/payments/initiate",
    "/payments/confirm",
    "/payments/cancel",
  ]) {
    assert.equal(
      (await request(path, { paymentId, reservationId: "booking" }, "other"))
        .status,
      403,
    );
  }
  assert.equal(
    (await request(`/payments/${paymentId}`, undefined, "other")).status,
    403,
  );
});
test("cancelled and expired checkout can restart with a fresh attempt and no stale TAC", async () => {
  await book();
  const paymentId = await initiate();
  await verify(paymentId);
  const beforeAttempt = (
    await db.doc(`mock_payments/${paymentId}`).get()
  ).data().attemptId;
  assert.equal((await request("/payments/cancel", { paymentId })).status, 200);
  await initiate();
  assert.notEqual(
    (await db.doc(`mock_payments/${paymentId}`).get()).data().attemptId,
    beforeAttempt,
  );
  assert.equal((await request("/payments/confirm", { paymentId })).status, 403);
  await db
    .doc(`mock_payments/${paymentId}`)
    .update({ expiresAt: Timestamp.fromMillis(Date.now() - 1) });
  assert.equal((await request("/payments/confirm", { paymentId })).status, 409);
  assert.equal(
    (await request(`/payments/${paymentId}`)).body.status,
    "expired",
  );
  await initiate();
});
test("customer cancellation refunds exactly once even with concurrent requests", async () => {
  await pay();
  const results = await Promise.all(
    [1, 2].map(() =>
      request("/reservations/action", {
        reservationId: "booking",
        action: "cancel",
      }),
    ),
  );
  assert.ok(
    results.every((r) => r.status === 200),
    JSON.stringify(results),
  );
  assert.equal(
    (await db.doc("mock_merchants/brand").get()).data().balanceCents,
    0,
  );
  assert.equal((await request("/payments/booking")).body.status, "refunded");
  assert.equal(
    (await request("/payments/confirm", { paymentId: "booking" })).status,
    409,
  );
});
test("restaurant rejection refunds paid deposit; payment history includes receipt", async () => {
  await pay();
  const receipt = await request("/payments/booking");
  assert.equal(receipt.body.bankName, "Maybank2u");
  assert.ok(receipt.body.paidAt);
  assert.equal(receipt.body.receiptEmail, users.customer.email);
  assert.equal((await request("/payments")).body.payments.length, 1);
  assert.equal(
    (await request("/payments", undefined, "other")).body.payments.length,
    0,
  );
  assert.equal(
    (
      await request(
        "/reservations/action",
        { reservationId: "booking", action: "reject" },
        "owner",
      )
    ).status,
    200,
  );
  assert.equal(
    (await db.doc("mock_merchants/brand").get()).data().balanceCents,
    0,
  );
});
test("paid booking edits fail; unpaid edits invalidate pending payment", async () => {
  await pay();
  const change = {
    reservationId: "booking",
    action: "update",
    pax: 4,
    specialRequest: "",
    reservationDateTime: reservation().reservation_datetime,
  };
  assert.equal((await request("/reservations/action", change)).status, 409);
  await book("unpaid");
  await initiate("unpaid");
  assert.equal(
    (
      await request("/reservations/action", {
        ...change,
        reservationId: "unpaid",
      })
    ).status,
    200,
  );
  assert.equal(await initiate("unpaid"), "unpaid");
  assert.equal(
    (await db.doc("mock_payments/unpaid").get()).data().amountCents,
    4000,
  );
});
test("rate limiting returns HTTP 429 and different accounts on same IP have separate limits", async () => {
  const limited = await listen(createApp({ ...appOptions, rateLimits: true }));
  const details = {
    brandId: "brand",
    bankName: "Maybank",
    accountNumber: "1234567890",
  };
  try {
    for (let n = 0; n < 5; n++)
      assert.equal(
        (await request("/verify-bank", details, "owner", limited.base)).status,
        200,
      );
    assert.equal(
      (await request("/verify-bank", details, "owner", limited.base)).status,
      429,
    );
    assert.equal(
      (await request("/verify-bank", details, "attacker", limited.base)).status,
      403,
    );
  } finally {
    await new Promise((resolve) => limited.server.close(resolve));
  }
});

test("rules deny all client payment mutations and direct reservation writes", async () => {
  await book();
  for (const uid of ["customer", "owner", "attacker"]) {
    const client = env
      .authenticatedContext(uid, { email_verified: true })
      .firestore();
    await assertFails(
      updateDoc(doc(client, "reservations/booking"), {
        payment_status: "paid",
      }),
    );
    await assertFails(
      updateDoc(doc(client, "mock_merchants/brand"), { balanceCents: 999999 }),
    );
    await assertFails(
      setDoc(doc(client, "mock_payments/forged"), { status: "paid" }),
    );
    await assertFails(
      setDoc(doc(client, "mockpay_sessions/forged"), { verified: true }),
    );
    for (const collection of [
      "mockpay_bank_authorizations",
      "mockpay_callback_events",
      "mockpay_security_events",
    ]) {
      await assertFails(
        setDoc(doc(client, collection + "/forged"), { paid: true }),
      );
      await assertFails(getDoc(doc(client, collection + "/private")));
    }
    await assertFails(
      setDoc(doc(client, "mockpay_otp_challenges/forged"), { otp: "123456" }),
    );
    await assertFails(getDoc(doc(client, "mock_bank_registry/bank")));
  }
});
test("rules preserve scoped reservation queries and prevent cross-customer reads", async () => {
  await book();
  const customer = env.authenticatedContext("customer").firestore();
  const owner = env.authenticatedContext("owner").firestore();
  const other = env.authenticatedContext("other").firestore();
  await assertSucceeds(
    getDocs(
      query(
        collection(customer, "reservations"),
        where("customer_id", "==", "customer"),
      ),
    ),
  );
  await assertSucceeds(
    getDocs(
      query(
        collection(owner, "reservations"),
        where("brand_id", "==", "brand"),
        where("restaurant_id", "==", "branch"),
      ),
    ),
  );
  await assertFails(getDoc(doc(other, "reservations/booking")));
});
test("rules block ownership reassignment, user role changes and brand payment flags", async () => {
  const owner = env.authenticatedContext("owner").firestore();
  const attacker = env.authenticatedContext("attacker").firestore();
  await assertFails(
    updateDoc(doc(attacker, "restaurant_brands/brand"), {
      owner_id: "attacker",
    }),
  );
  await assertFails(
    updateDoc(doc(owner, "restaurant_brands/brand"), { paymentEnabled: true }),
  );
  await assertFails(
    updateDoc(doc(owner, "users/owner"), { brand_id: "otherbrand" }),
  );
  await assertFails(deleteDoc(doc(owner, "users/owner")));
  await assertSucceeds(
    updateDoc(doc(owner, "restaurant_brands/brand"), {
      about: "Demo restaurant",
    }),
  );
});
test("rules preserve signup and own OTP access, deny cross-user OTP access", async () => {
  const signup = env.authenticatedContext("new-owner").firestore();
  await assertSucceeds(
    setDoc(doc(signup, "users/new-owner"), {
      role: "restaurant",
      owner_phone: "+60127347838",
      brand_id: "newbrand",
      restaurant_ids: ["newbranch"],
      name: "Demo",
      email: "demo@example.test",
      created_at: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    setDoc(doc(signup, "restaurant_brands/newbrand"), {
      owner_id: "new-owner",
      name: "Demo",
      cuisine: "",
      about: "",
      created_at: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    setDoc(doc(signup, "restaurant_brands/newbrand/restaurants/newbranch"), {
      owner_id: "new-owner",
      brand_id: "newbrand",
      phone: "+6042345678",
      created_at: serverTimestamp(),
    }),
  );
  const client = env
    .authenticatedContext("customer", { email_verified: true })
    .firestore();
  await assertSucceeds(setDoc(doc(client, "otps/customer"), { otp: "123456" }));
  await assertFails(getDoc(doc(client, "otps/other")));
});
test("rules allow atomic queue join but reject counter-only changes and extra tickets", async () => {
  const client = env.authenticatedContext("customer").firestore();
  const batch = writeBatch(client);
  batch.set(doc(client, "queues/branch"), {
    brand_id: "brand",
    restaurant_id: "branch",
    current_serving: 0,
    next_available_number: 2,
  });
  batch.set(doc(client, "queues/branch/tickets/t1"), {
    user_id: "customer",
    status: "WAITING",
    queue_number: 1,
    created_at: serverTimestamp(),
  });
  batch.set(doc(client, "users/customer/active_queue/branch"), {
    ticket_id: "t1",
    brand_id: "brand",
    restaurant_id: "branch",
    ticket_number: 1,
    status: "WAITING",
    joined_at: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());
  await assertFails(
    updateDoc(doc(client, "queues/branch"), { next_available_number: 3 }),
  );
  await assertFails(
    setDoc(doc(client, "queues/branch/tickets/t2"), {
      user_id: "customer",
      status: "WAITING",
      queue_number: 1,
      created_at: serverTimestamp(),
    }),
  );
  const other = env.authenticatedContext("other").firestore();
  const forged = writeBatch(other);
  forged.set(doc(other, "queues/branch/tickets/forged"), {
    user_id: "other",
    status: "WAITING",
    queue_number: 1,
    created_at: serverTimestamp(),
  });
  forged.set(doc(other, "users/other/active_queue/branch"), {
    ticket_id: "forged",
    brand_id: "brand",
    restaurant_id: "branch",
    ticket_number: 1,
    status: "WAITING",
    joined_at: serverTimestamp(),
  });
  await assertFails(forged.commit());
  const owner = env.authenticatedContext("owner").firestore();
  const called = writeBatch(owner);
  called.update(doc(owner, "queues/branch"), { current_serving: 1 });
  called.update(doc(owner, "queues/branch/tickets/t1"), {
    status: "CALLED",
    called_at: serverTimestamp(),
  });
  called.update(doc(owner, "users/customer/active_queue/branch"), {
    status: "CALLED",
    called_at: serverTimestamp(),
  });
  await assertSucceeds(called.commit());
  await assertFails(
    updateDoc(
      doc(env.authenticatedContext("attacker").firestore(), "queues/branch"),
      { current_serving: 9 },
    ),
  );
});

test("payment OTP session expiry blocks confirmation", async () => {
  await book();
  const paymentId = await initiate();
  await verify(paymentId);
  const sessions = await db.collection("mockpay_sessions").get();
  await sessions.docs[0].ref.update({
    expiresAt: Timestamp.fromMillis(Date.now() - 1),
  });
  assert.equal((await request("/payments/confirm", { paymentId })).status, 403);
  assert.equal(
    (await db.doc("mock_merchants/brand").get()).data().balanceCents,
    0,
  );
});
test("cancellation inside 24 hours is rejected without refunding", async () => {
  await pay();
  await db
    .doc("reservations/booking")
    .update({
      reservation_datetime: Timestamp.fromMillis(Date.now() + 3600000),
    });
  assert.equal(
    (
      await request("/reservations/action", {
        reservationId: "booking",
        action: "cancel",
      })
    ).status,
    409,
  );
  assert.equal(
    (await db.doc("mock_merchants/brand").get()).data().balanceCents,
    3000,
  );
});

async function holdCallback() {
  await book();
  const paymentId = await initiate();
  await verify(paymentId);
  deliverCallbacks = false;
  assert.equal((await request("/payments/confirm", { paymentId })).status, 502);
  assert.equal(
    (await db.doc("mock_payments/booking").get()).data().status,
    "pending",
  );
  assert.equal(
    (await db.doc("mock_merchants/brand").get()).data().balanceCents,
    0,
  );
  return { ...bankRequests.at(-1), status: "paid" };
}
async function callback(message, rawBody = message.rawBody, extraHeaders = {}) {
  const response = await fetch(base + "/bank/callback", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-MockPay-Timestamp": message.timestamp,
      "X-MockPay-Signature": message.signature,
      ...extraHeaders,
    },
    body: rawBody,
  });
  return { status: response.status, body: await response.json() };
}
test("only a verified raw-bank callback settles an authorized payment and records proof", async () => {
  const event = await holdCallback();
  const result = await callback(sign(callbackSecret, event));
  assert.equal(result.status, 200);
  assert.equal(result.body.signatureVerified, true);
  const receipt = (await request("/payments/booking")).body;
  assert.equal(receipt.callbackSignatureVerified, true);
  assert.equal(receipt.callbackEventId, event.eventId);
  assert.ok(receipt.callbackVerifiedAt);
  assert.equal(
    (await db.doc("mock_merchants/brand").get()).data().balanceCents,
    3000,
  );
  assert.equal(
    (await db.doc("reservations/booking").get()).data().status,
    "PENDING",
  );
});
test("altered raw-body amount with the original signature is rejected", async () => {
  const event = await holdCallback();
  const message = sign(callbackSecret, event);
  assert.equal(
    (
      await callback(
        message,
        Buffer.from(JSON.stringify({ ...event, amountCents: 100 })),
      )
    ).status,
    401,
  );
  assert.equal(
    (await db.doc("mock_merchants/brand").get()).data().balanceCents,
    0,
  );
});
test("valid signatures still cannot change amount, currency, merchant or payment ID", async () => {
  const event = await holdCallback();
  for (const change of [
    { amountCents: 2000 },
    { currency: "USD" },
    { merchantId: "MP_other" },
    { paymentId: "unknown" },
  ]) {
    const result = await callback(
      sign(callbackSecret, { ...event, ...change }),
    );
    assert.ok([400, 409].includes(result.status), JSON.stringify(result));
  }
  assert.equal(
    (await db.doc("mock_merchants/brand").get()).data().balanceCents,
    0,
  );
});
test("expired, future and malformed callback timestamps are rejected", async () => {
  const event = await holdCallback();
  assert.equal(
    (await callback(sign(callbackSecret, event, Date.now() - 301000))).status,
    400,
  );
  assert.equal(
    (await callback(sign(callbackSecret, event, Date.now() + 60000))).status,
    400,
  );
  assert.equal(
    (
      await callback(sign(callbackSecret, event), undefined, {
        "X-MockPay-Timestamp": "NaN",
      })
    ).status,
    400,
  );
});
test("invalid signature headers are rejected without a comparison exception", async () => {
  const event = await holdCallback();
  const message = sign(callbackSecret, event);
  for (const bad of [
    "",
    "zz",
    "00",
    "0".repeat(64),
    message.signature + "ff",
  ]) {
    assert.equal(
      (await callback(message, undefined, { "X-MockPay-Signature": bad }))
        .status,
      401,
    );
  }
});
test("raw bytes are verified rather than parsed and reserialized JSON", async () => {
  const event = await holdCallback();
  const timestamp = String(Math.floor(Date.now() / 1000));
  const rawBody = Buffer.from(JSON.stringify(event, null, 2) + "\n");
  const signature = crypto
    .createHmac("sha256", callbackSecret)
    .update(timestamp + ".")
    .update(rawBody)
    .digest("hex");
  const message = { timestamp, rawBody, signature };
  assert.equal(
    (await callback(message, Buffer.from(JSON.stringify(event)))).status,
    401,
  );
  assert.equal((await callback(message)).status, 200);
});
test("concurrent replay is rejected and credits the merchant only once", async () => {
  const event = await holdCallback();
  const message = sign(callbackSecret, event);
  const results = await Promise.all([callback(message), callback(message)]);
  assert.deepEqual(results.map((result) => result.status).sort(), [200, 409]);
  assert.equal((await callback(message)).status, 409);
  assert.equal(
    (await db.doc("mock_merchants/brand").get()).data().balanceCents,
    3000,
  );
});
test("signed callback without a TAC-backed authorization cannot settle payment", async () => {
  await book();
  const paymentId = await initiate();
  const payment = (await db.doc("mock_payments/booking").get()).data();
  const event = {
    paymentId,
    attemptId: payment.attemptId,
    merchantId: payment.merchantId,
    amountCents: 3000,
    currency: "MYR",
    bankName: "Maybank2u",
    status: "paid",
    authorizationId: crypto.randomUUID(),
    eventId: crypto.randomUUID(),
  };
  assert.equal((await callback(sign(callbackSecret, event))).status, 409);
});
test("mock bank rejects authorisation calls from unauthenticated clients", async () => {
  const event = await holdCallback();
  const response = await fetch(bankBase + "/authorise", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(event),
  });
  assert.equal(response.status, 401);
});
test("cancelled or restarted attempts reject an old correctly signed callback", async () => {
  const event = await holdCallback();
  assert.equal(
    (await request("/payments/cancel", { paymentId: "booking" })).status,
    200,
  );
  assert.equal((await callback(sign(callbackSecret, event))).status, 409);
  await initiate();
  assert.equal((await callback(sign(callbackSecret, event))).status, 409);
  assert.equal(
    (await db.doc("mock_merchants/brand").get()).data().balanceCents,
    0,
  );
});
test("bank outage permits retry of the same authorization without reusing TAC", async () => {
  await holdCallback();
  const authorizationId = bankRequests[0].authorizationId;
  deliverCallbacks = true;
  assert.equal(
    (await request("/payments/confirm", { paymentId: "booking" })).status,
    200,
  );
  assert.equal(bankRequests.at(-1).authorizationId, authorizationId);
  assert.equal(
    (await db.doc("mock_merchants/brand").get()).data().balanceCents,
    3000,
  );
});
test("lost bank delivery response recovers a payment accepted by callback", async () => {
  loseBankResponse = true;
  await pay();
  assert.equal(
    (await db.doc("mock_merchants/brand").get()).data().balanceCents,
    3000,
  );
});
test("security audit events omit bodies, signatures, keys, tokens, TACs and email", async () => {
  const event = await holdCallback();
  const message = sign(callbackSecret, event);
  await callback({ ...message, signature: "0".repeat(64) });
  await callback(message);
  await callback(message);
  const audits = (
    await db.collection("mockpay_security_events").get()
  ).docs.map((doc) => doc.data());
  for (const type of [
    "callback_signature_rejected",
    "callback_accepted",
    "callback_replay_rejected",
  ])
    assert.ok(audits.some((a) => a.type === type));
  for (const audit of audits)
    assert.ok(
      Object.keys(audit).every((key) =>
        ["type", "paymentId", "eventId", "at"].includes(key),
      ),
    );
});

test("phone rules accept normalized signup and reject letters, wrong country and bad lengths", async () => {
  const good = env.authenticatedContext("new-customer").firestore();
  await assertSucceeds(
    setDoc(doc(good, "users/new-customer"), {
      role: "customer",
      name: "Demo",
      email: "demo@example.test",
      phone: "+60127347838",
    }),
  );
  const bad = env.authenticatedContext("bad-customer").firestore();
  for (const phone of [
    "abc",
    "123",
    "0127347838",
    "+65127347838",
    "+6012-7347838",
    "+60127347838000",
    "",
  ]) {
    await assertFails(
      setDoc(doc(bad, "users/bad-customer"), { role: "customer", phone }),
    );
  }
  await assertFails(
    updateDoc(doc(good, "users/new-customer"), { phone: "+6512345678" }),
  );
  await assertFails(
    updateDoc(doc(good, "users/new-customer"), { owner_phone: "abc" }),
  );
  await assertSucceeds(
    updateDoc(doc(good, "users/new-customer"), { phone: "+601123456789" }),
  );
});
test("restaurant phone updates require a normalized Malaysian number and preserve legacy unrelated edits", async () => {
  const owner = env.authenticatedContext("owner").firestore();
  await assertFails(
    updateDoc(doc(owner, "restaurant_brands/brand/restaurants/branch"), {
      phone: "abc",
    }),
  );
  await assertFails(
    updateDoc(doc(owner, "restaurant_brands/brand/restaurants/branch"), {
      phone: "+6561234567",
    }),
  );
  await assertSucceeds(
    updateDoc(doc(owner, "restaurant_brands/brand/restaurants/branch"), {
      phone: "+6042345678",
    }),
  );
  await assertSucceeds(
    updateDoc(doc(owner, "users/owner"), { name: "Updated name" }),
  );
  await assertFails(
    updateDoc(doc(owner, "users/owner"), { owner_phone: "123" }),
  );
  await assertSucceeds(
    updateDoc(doc(owner, "users/owner"), { owner_phone: "+60127347838" }),
  );
});

test("reservation API rejects invalid customer phone numbers before saving", async () => {
  for (const phone of [
    "123",
    "abc",
    "+6512345678",
    "+600127347838",
    "127347838999",
    "",
  ]) {
    const result = await request("/reservations", {
      ...reservation(),
      customer_phone: phone,
    });
    assert.equal(result.status, 400);
  }
  assert.equal((await db.doc("reservations/booking").get()).exists, false);
});
test("reservation API validates guest phone and normalizes both contacts", async () => {
  const data = {
    ...reservation(),
    booking_type: "OTHER",
    guest_name: "Demo Guest",
    guest_phone: "123",
  };
  assert.equal((await request("/reservations", data)).status, 400);
  assert.equal(
    (await request("/reservations", { ...data, guest_phone: "+6512345678" }))
      .status,
    400,
  );
  assert.equal(
    (
      await request("/reservations", {
        ...data,
        customer_phone: "012-7347838",
        guest_phone: "+60 11-2345 6789",
      })
    ).status,
    200,
  );
  const saved = (await db.doc("reservations/booking").get()).data();
  assert.equal(saved.customer_phone, "+60127347838");
  assert.equal(saved.guest_phone, "+601123456789");
});

test("cancellation retries a transient transaction timeout without duplicate refund", async () => {
  await pay();
  let calls = 0;
  const retryDb = new Proxy(db, {
    get(target, key) {
      if (key === "runTransaction")
        return async (...args) => {
          if (calls++ === 0) {
            const error = new Error("Simulated transaction deadline");
            error.code = 4;
            throw error;
          }
          return target.runTransaction(...args);
        };
      const value = Reflect.get(target, key);
      return typeof value === "function" ? value.bind(target) : value;
    },
  });
  const retryApp = await listen(createApp({ ...appOptions, db: retryDb }));
  try {
    const body = { reservationId: "booking", action: "cancel" };
    assert.equal(
      (await request("/reservations/action", body, "customer", retryApp.base))
        .status,
      200,
    );
    assert.equal(
      (await request("/reservations/action", body, "customer", retryApp.base))
        .body.paymentStatus,
      "refunded",
    );
    assert.equal(
      (await db.doc("mock_merchants/brand").get()).data().balanceCents,
      0,
    );
    assert.equal(
      (await db.doc("mock_payments/booking").get()).data().status,
      "refunded",
    );
    assert.ok(calls >= 3);
  } finally {
    await new Promise((resolve) => retryApp.server.close(resolve));
  }
});
