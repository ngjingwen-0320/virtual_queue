# MockPay payment simulation

No bank connection or real money movement is implemented. Use only the displayed
demo bank credentials (`demo.user` / `demo1234`). TACs are generated and checked by
the Node backend and sent to the signed-in user's verified email.

## Local run

1. In `mockpay_backend`, run `npm ci`, then `npm start`.
2. Keep the existing `serviceAccountKey.json` and `mock_payment_tools/.env` local.
   Required environment names: `ACCOUNT_HMAC_KEY`, `EMAILJS_SERVICE_ID`,
   `EMAILJS_TEMPLATE_ID`, `EMAILJS_PUBLIC_KEY`, `EMAILJS_PRIVATE_KEY`.
   Backend `.env` can supply variables missing from the existing tools `.env`.
3. Configure EmailJS to accept the server-side request using that private key.
   Template parameters are `user_email`, `user_name`, and `otp_code`.
4. Run Flutter on an Android emulator. Its default backend URL is
   `http://10.0.2.2:3000/api/mockpay`. For a physical device use
   `flutter run --dart-define=MOCKPAY_BASE_URL=http://YOUR_PC_LAN_IP:3000/api/mockpay`
   and explicitly set backend `HOST=0.0.0.0`. Do not expose this demo on the Internet.
5. Before using the new app against the live database, review and publish the
   tested `firestore.rules`. The application now creates and changes reservations
   through the backend. Older app builds that write reservations directly will be
   rejected after this rules change.

## End-to-end demonstration

1. Provision a fictional active record in `mock_bank_registry` using the existing
   HMAC tool and the backend's secret. Business name must match the restaurant.
   Never commit the secret, account data, OTPs, or service-account credentials.
2. Sign in as the restaurant, open Profile > Set Up MockPay, enter the matching
   fictional bank details, request/verify email OTP, then register. Merchant
   activation requires ownership, bank matching and OTP on the backend.
3. Sign in as a customer, book 1–8 people at least 24 hours ahead. Deposit is RM10
   per person. The backend requires an active merchant and derives the amount.
4. Choose a demo bank, sign in with the displayed demo credentials, request TAC,
   enter the email code, and confirm. The fictional bank login is presentation
   only; it does not authenticate a real bank account.
5. My Reservations shows deposit state, allows retrying an unpaid booking, and
   links to receipts and payment history. Paid bookings remain `PENDING` until
   the restaurant approves them. Unpaid bookings cannot be approved.
6. Cancellation with at least 24 hours notice or rejection of a pending booking
   refunds the simulated deposit atomically and subtracts it from the merchant's
   mock balance exactly once. There is no real refund provider.

Checkout attempts expire after 15 minutes and are treated as expired when read
or acted on; there is no scheduled cleanup job. Retrying creates a fresh attempt
and invalidates old TAC scopes. Canceling checkout keeps the reservation unpaid
so it can be resumed. Paid guest-count/time changes require cancellation and
rebooking. Receipts can be viewed and copied; receipt emails are not dispatched.

## Tests

From the repository root, install test dependencies with `npm ci` and run:

```
firebase emulators:exec --project demo-mockpay --config firebase.test.json --only firestore,auth "node --test mockpay_backend/test/integration.test.js"
flutter test test/mockpay_checkout_test.dart
flutter analyze --no-pub
```

Tests refuse to run without the demo emulator environment. Email delivery is
injected in tests; they do not send email, use live bank data, or touch production
Firestore. Actual device networking and EmailJS delivery require the local demo
walkthrough above. The existing login OTP remains a legacy client-side flow and
is not backend-enforced MFA. Restaurant queue notification emails are skipped
when Firestore correctly denies access to another user's private profile; moving
those notifications to a backend is separate from MockPay.


Signed bank callbacks are now part of the prepared backend. See [MOCKPAY_CALLBACKS.md](MOCKPAY_CALLBACKS.md) for setup, the separate mock-bank service, and the signature demonstration. Run the bank service before restarting this version of MockPay.
