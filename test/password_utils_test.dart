import 'package:flutter_test/flutter_test.dart';
import '../lib/utils/password_utils.dart';
void main() {
  test('password changes require every registration strength condition', () {
    for (final weak in ['', 'Aa1!', 'password1!', 'PASSWORD1!', 'Password!', 'Password1']) {
      expect(PasswordUtils.validate(weak), isNotNull, reason: weak);
    }
    expect(PasswordUtils.validate('Password1!'), isNull);
    expect(PasswordUtils.validate('Abc1234#'), isNull);
  });
}
