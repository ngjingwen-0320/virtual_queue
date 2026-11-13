import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_logger.dart';

class OtpEmailService {
  static const String serviceId = 'service_otndmwn';
  static const String publicKey = 'm0-pjpXqF0pD4BpH4';
  static const String otpTemplateId = 'template_13fg8no';

  /// Sends a 6-digit verification code to the specified email address.
  /// Returns `true` if the request was accepted by EmailJS (HTTP 200).
  Future<bool> sendOtpEmail({
    required String userEmail,
    required String otpCode,
    String userName = 'User',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'http://localhost',
        },
        body: json.encode({
          'service_id': serviceId,
          'template_id': otpTemplateId,
          'user_id': publicKey,
          'template_params': {
            'user_email': userEmail,
            'user_name': userName,
            'otp_code': otpCode,
          },
        }),
      );

      // 🔐 Log OTP delivery status without exposing recipient emails or API responses.
      if (response.statusCode == 200) {
        AppLogger.info(
          'OtpEmailService',
          'OTP email sent successfully',
        );
        return true;
      } else {
        AppLogger.warning(
          'OtpEmailService',
          'EmailJS OTP delivery failed [HTTP ${response.statusCode}]',
        );
        return false;
      }
    } catch (e) {
      AppLogger.error(
        'OtpEmailService',
        'Error sending OTP via EmailJS',
      );
      return false;
    }
  }
}