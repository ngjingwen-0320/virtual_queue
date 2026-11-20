import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_queue/utils/phone_number_utils.dart';

void main() {
  final valid = <String, String>{
    '127347838': '+60127347838',
    '0127347838': '+60127347838',
    '+60127347838': '+60127347838',
    '+6012-7347838': '+60127347838',
    '0060127347838': '+60127347838',
    '60127347838': '+60127347838',
    ' (012) 734-7838 ': '+60127347838',
    '01123456789': '+601123456789',
    '042345678': '+6042345678',
    '0323856789': '+60323856789',
  };
  for (final entry in valid.entries) {
    test('normalizes ${entry.key} without punctuation', () {
      expect(PhoneNumberUtils.normalize(entry.key), entry.value);
      expect(PhoneNumberUtils.validate(entry.key), isNull);
      expect(PhoneNumberUtils.normalize(entry.value), entry.value);
    });
  }
  for (final value in [
    '',
    'abc',
    '012abc7838',
    '123',
    '+65127347838',
    '+441234567890',
    '+600127347838',
    '00127347838',
    '+60+60127347838',
    '127347838999',
    '423456789',
    '32385678',
    '0000000000',
    '12345678 ext 1',
  ]) {
    test('rejects invalid phone "$value"', () {
      expect(PhoneNumberUtils.tryNormalize(value), isNull);
      expect(PhoneNumberUtils.validate(value), isNotNull);
      expect(() => PhoneNumberUtils.normalize(value), throwsFormatException);
    });
  }
  test('existing valid phone displays canonically without rewriting data', () {
    expect(PhoneNumberUtils.display('012-7347838'), '+60127347838');
    expect(PhoneNumberUtils.nationalDigits('+60127347838'), '127347838');
    expect(PhoneNumberUtils.display('legacy-invalid'), 'legacy-invalid');
  });
}
