# Malaysian phone validation

Registration and profile phone fields have a fixed, non-editable `+60` prefix.
Users type national digits, for example `127347838`. Local and international
numbers pasted from older data are normalized where valid. New writes use
`+60127347838`, with no spaces or hyphens. Foreign `+` country codes, letters,
extensions and overlong input are rejected rather than silently converted.

The shared utility implements basic Malaysian mobile and geographic landline
format/length checks: `1` followed by 8–9 digits, `3` followed by 8 digits, or
`4–9` followed by 7 digits. This follows the general national-number pattern
in Google's libphonenumber MY metadata:
https://github.com/google/libphonenumber/blob/master/resources/PhoneNumberMetadata.xml

It does not check detailed allocated operator ranges, number existence,
reachability or ownership. No SMS OTP is added. Mobile and landline inputs are
accepted because restaurants can use landlines.

Validation runs in the shared field, registration viewmodel, registration
service, and profile write paths. Local Firestore rules additionally enforce
canonical `+60` values on user creation, changed phone fields and branch
creation. Unrelated edits to existing legacy documents remain possible; no
existing Firestore numbers are automatically rewritten. Valid legacy numbers
are normalized for profile display/editing, while invalid ones require user
correction. Registration, profile and reservation contact forms now use the same validation. Reservation customer and guest numbers are also normalized and validated by the Node backend before saving.

The rules need review and publishing before their database enforcement is
active. Older app versions sending unnormalized phone numbers will be rejected
by the updated rules. Original source files are backed up before application.

Tests:

```
flutter test --no-pub test/phone_number_utils_test.dart test/phone_field_test.dart test/mockpay_checkout_test.dart
npm run test:mockpay
```

Report evidence: capture the validation utility, the registration viewmodel
checks, the fixed-prefix field and a valid/invalid input example. Use emulator
rules-test output to demonstrate protection against direct client writes.
