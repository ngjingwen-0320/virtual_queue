const { 
  initializeTestEnvironment, 
  assertFails, 
  assertSucceeds 
} = require('@firebase/rules-unit-testing');
const fs = require('fs');

let testEnv;

describe("Firestore Security Rules Verification (Table 3.1)", () => {

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: "virtual-queue-test",
      firestore: {
        rules: fs.readFileSync("firestore.rules", "utf8"),
        host: "127.0.0.1",
        port: 8080,
      },
    });
  });

  afterEach(async () => {
    await testEnv.clearFirestore();
  });

  after(async () => {
    await testEnv.cleanup();
  });

  // =========================================================================
  // TEST CASES 1-12
  // =========================================================================

  // Test 1: Authenticated user reads own profile
  it("Test 1: Allow - Authenticated user reads own profile", async () => {
    const aliceContext = testEnv.authenticatedContext("alice_uid");
    const userDoc = aliceContext.firestore().collection("users").doc("alice_uid");
    await assertSucceeds(userDoc.get());
  });

  // Test 2: User reads another user's profile
  it("Test 2: Deny - User reads another user's profile", async () => {
    const aliceContext = testEnv.authenticatedContext("alice_uid");
    const bobDoc = aliceContext.firestore().collection("users").doc("bob_uid");
    await assertFails(bobDoc.get());
  });

  // Test 3: User reads own bookmark
  it("Test 3: Allow - User reads own bookmark", async () => {
    const aliceContext = testEnv.authenticatedContext("alice_uid");
    const bookmarkDoc = aliceContext.firestore()
      .collection("users")
      .doc("alice_uid")
      .collection("bookmarks")
      .doc("bm_1");
    await assertSucceeds(bookmarkDoc.get());
  });

  // Test 4: User reads another user's bookmark
  it("Test 4: Deny - User reads another user's bookmark", async () => {
    const aliceContext = testEnv.authenticatedContext("alice_uid");
    const bobBookmarkDoc = aliceContext.firestore()
      .collection("users")
      .doc("bob_uid")
      .collection("bookmarks")
      .doc("bm_1");
    await assertFails(bobBookmarkDoc.get());
  });

  // Test 5: User creates own bookmark
  it("Test 5: Allow - User creates own bookmark", async () => {
    const aliceContext = testEnv.authenticatedContext("alice_uid");
    const bookmarkDoc = aliceContext.firestore()
      .collection("users")
      .doc("alice_uid")
      .collection("bookmarks")
      .doc("bm_1");
    await assertSucceeds(bookmarkDoc.set({ restaurant_id: "rest_100" }));
  });

  // Test 6: User modifies another user's bookmark
  it("Test 6: Deny - User modifies another user's bookmark", async () => {
    const aliceContext = testEnv.authenticatedContext("alice_uid");
    const bobBookmarkDoc = aliceContext.firestore()
      .collection("users")
      .doc("bob_uid")
      .collection("bookmarks")
      .doc("bm_1");
    await assertFails(bobBookmarkDoc.update({ restaurant_id: "rest_200" }));
  });

  // Test 7: User reads own active queue
  it("Test 7: Allow - User reads own active queue", async () => {
    const aliceContext = testEnv.authenticatedContext("alice_uid");
    const activeQueueDoc = aliceContext.firestore()
      .collection("users")
      .doc("alice_uid")
      .collection("active_queue")
      .doc("q_1");
    await assertSucceeds(activeQueueDoc.get());
  });

  // Test 8: User reads another user's active queue
  it("Test 8: Deny - User reads another user's active queue", async () => {
    const aliceContext = testEnv.authenticatedContext("alice_uid");
    const bobActiveQueueDoc = aliceContext.firestore()
      .collection("users")
      .doc("bob_uid")
      .collection("active_queue")
      .doc("q_1");
    await assertFails(bobActiveQueueDoc.get());
  });

  // Test 9: Unauthenticated user reads user data
  it("Test 9: Deny - Unauthenticated user reads user data", async () => {
    const unauthContext = testEnv.unauthenticatedContext();
    const userDoc = unauthContext.firestore().collection("users").doc("alice_uid");
    await assertFails(userDoc.get());
  });

  // Test 10: Customer changes role to restaurant
  it("Test 10: Deny - Customer changes role to restaurant", async () => {
    // Seed existing customer document using admin context (bypasses rules)
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("alice_uid").set({
        name: "Alice",
        role: "customer"
      });
    });

    const aliceContext = testEnv.authenticatedContext("alice_uid");
    const userDoc = aliceContext.firestore().collection("users").doc("alice_uid");
    await assertFails(userDoc.update({ role: "restaurant" }));
  });

  // Test 11: Customer creates reservation using own UID
  it("Test 11: Allow - Customer creates reservation using own UID", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("alice_uid").set({
        name: "Alice",
        role: "customer"
      });
    });
    const aliceContext = testEnv.authenticatedContext("alice_uid");
    const reservationDoc = aliceContext.firestore().collection("reservations").doc("res_1");
    await assertSucceeds(reservationDoc.set({
      customer_id: "alice_uid",
      party_size: 4,
      timestamp: new Date()
    }));
  });

  // Test 12: Customer creates reservation using another user's UID
  it("Test 12: Deny - Customer creates reservation using another user's UID", async () => {
    const aliceContext = testEnv.authenticatedContext("alice_uid");
    const reservationDoc = aliceContext.firestore().collection("reservations").doc("res_2");
    await assertFails(reservationDoc.set({
      customer_id: "bob_uid",
      party_size: 2,
      timestamp: new Date()
    }));
  });

});