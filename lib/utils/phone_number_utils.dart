class PhoneNumberUtils {
  static const countryCode = '+60';
  static const exampleNationalNumber = '127347838';
  static const invalidMessage =
      'Enter a valid Malaysian phone number, e.g. 127347838.';

  static final _nationalPattern = RegExp(
    r'^(?:1[0-9]{8,9}|3[0-9]{8}|[4-9][0-9]{7})$',
  );

  static String? nationalInput(String value) {
    var input = value.trim();
    if (!RegExp(r'^[+0-9\s()\-]*$').hasMatch(input)) return null;
    input = input.replaceAll(RegExp(r'[\s()\-]'), '');
    var international = false;
    if (input.startsWith('+')) {
      if (!input.startsWith(countryCode)) return null;
      input = input.substring(countryCode.length);
      international = true;
    } else if (input.startsWith('00')) {
      if (!input.startsWith('0060')) return null;
      input = input.substring(4);
      international = true;
    } else if (input.startsWith('60') && input.length >= 10) {
      input = input.substring(2);
      international = true;
    }
    if (international && input.startsWith('0')) return null;
    if (!international && input.startsWith('0')) input = input.substring(1);
    if (!RegExp(r'^[0-9]{0,10}$').hasMatch(input)) return null;
    return input;
  }

  static String? tryNormalize(String value) {
    final national = nationalInput(value);
    if (national == null || !_nationalPattern.hasMatch(national)) return null;
    return '$countryCode$national';
  }

  static String normalize(String value) {
    final result = tryNormalize(value);
    if (result == null) throw const FormatException(invalidMessage);
    return result;
  }

  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required.';
    }
    return tryNormalize(value) == null ? invalidMessage : null;
  }

  static String nationalDigits(String value) =>
      nationalInput(value) ?? value.trim();
  static String display(String value) => tryNormalize(value) ?? value.trim();
}
