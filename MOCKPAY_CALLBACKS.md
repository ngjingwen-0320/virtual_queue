# Signed mock-bank callbacks

This is a payment simulation. Neither service contacts a bank or moves money.
The existing demo bank username/password are presentation only. The gateway's
backend TAC check authorises a specific, immutable payment attempt.

## Flow

1. Flutter verifies its payment TAC with MockPay, then requests confirmation.
2. MockPay atomically consumes that TAC session and records a pending bank
   authorisation containing the server-calculated amount, merchant, currency,
   payment ID, attempt ID, bank, expiry and one unique callback event ID.
3. MockPay sends that authorisation to the separate mock-bank HTTP service.
   A backend-only request key authenticates this call; the bank rejects public
   requests without it. Flutter never receives either server secret.
4. The mock bank signs its exact result bytes using HMAC-SHA256 over
   `timestamp + "." + rawBody`. It sends `X-MockPay-Timestamp` and
   `X-MockPay-Signature` headers to `/api/mockpay/bank/callback`.
5. MockPay verifies the signature before parsing JSON. It rejects malformed
   headers, messages older than five minutes or more than 30 seconds in the
   future, previously processed event IDs, expired authorisations, cancelled
   attempts, and mismatches against its authorisation/payment/reservation.
6. One Firestore transaction records the event, marks the payment and deposit
   paid, credits the merchant once, and records an audit event. The reservation
   remains pending for restaurant approval.

The callback uses a dedicated signing key, separate from bank matching/OTP and
separate from the key used to authenticate calls to the mock bank. Comparisons
use constant-time functions. These properties demonstrate integrity and shared
secret possession, not real bank authentication or non-repudiation.

## Run the local services after reviewing the changes

In `mockpay_backend`:

```
npm run setup:callbacks
npm run start:bank
```

In a second terminal in the same directory:

```
npm start
```

The setup command creates `.env.callback.local` only if it does not exist and
never prints or overwrites keys. The existing `.env.*` ignore rule excludes it
from Git. Keep it private. The two services read this backend-only local file.

Defaults are MockPay on loopback port 3000 and the mock bank on loopback port
3001. Stop the old MockPay process before starting the new version. No live
Firestore rules changes are needed: the existing default deny rule already
blocks clients from accessing the new private collections.

Configuration names:

- `MOCKBANK_CALLBACK_HMAC_KEY`: at least 32 random bytes, known to both servers.
- `MOCKBANK_REQUEST_KEY`: independent random key for MockPay-to-bank requests.
- `MOCKBANK_URL`: fixed trusted bank endpoint, default `http://127.0.0.1:3001`.
- `MOCKPAY_CALLBACK_URL`: fixed callback URL, default
  `http://127.0.0.1:3000/api/mockpay/bank/callback`.

URLs are server configuration; they are not accepted from customer requests.
HTTP is for loopback development only. Use HTTPS and proper deployment secret
management before exposing either service over a network. Never ship these
secrets in Flutter, screenshots, logs, or your assignment report.

## Assignment demonstration

From the project root:

```
npm run demo:signature
npm run test:mockpay
```

The demonstration refuses to run outside the `demo-mockpay` Firestore emulator.
It generates an ephemeral key, prints a synthetic message and its signature,
and shows these real callback processor outcomes:

| Input | Expected result |
|---|---|
| Original signed result | Signature verified; payment accepted |
| Changed amount with original signature | 401 Invalid callback signature |
| Same signed event again | 409 Callback event already processed |
| Expired signed timestamp | 400 Timestamp rejected |
| Properly signed amount differing from stored authorisation | 409 Payment mismatch |

New payment receipts show callback verification and the event ID. Existing
payments are never retroactively marked signature-verified. A refunded payment
can still show that its original payment callback was verified.

Audit collection `mockpay_security_events` records types, event/payment IDs and
timestamps only. It never stores raw bodies, signature values, keys, Firebase
tokens, TAC values, account numbers or email addresses. It is backend-only;
no public audit viewer or unauthenticated demonstration endpoint is added.

If the bank/callback is unavailable, the payment stays pending. Retrying uses
the same unexpired authorisation and event ID; it does not require reusing the
consumed TAC. A lost response after a successful callback is recovered by
reading the payment status. There is no background retry worker; a user retries
confirmation. After an authorisation expires, request a new TAC. Event IDs are
retained rather than expiring with the timestamp window.
