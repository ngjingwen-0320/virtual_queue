import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_logger.dart';

class RestaurantNotificationEmailService {
  static const String serviceId = 'service_ydg7n6n';
  static const String publicKey = 'x4Tc1vifKlpWa-2cM';

  static const String calledTemplateId = 'template_0wqrfnd';
  static const String cancelledTemplateId = 'template_m1ag07k';

  Future<void> sendQueueCalledEmail({
    required String userName,
    required String userEmail,
    required String restaurantName,
    required int queueNumber,
  }) async {
    await _sendEmail(
      templateId: calledTemplateId,
      params: {
        'user_name': userName,
        'user_email': userEmail,
        'restaurant_name': restaurantName,
        'queue_number': queueNumber.toString(),
      },
    );
  }

  Future<void> sendQueueCancelledEmail({
    required String userName,
    required String userEmail,
    required String restaurantName,
    required int queueNumber,
    required String reason,
  }) async {
    await _sendEmail(
      templateId: cancelledTemplateId,
      params: {
        'user_name': userName,
        'user_email': userEmail,
        'restaurant_name': restaurantName,
        'queue_number': queueNumber.toString(),
        'reason': reason,
      },
    );
  }

  Future<void> _sendEmail({
    required String templateId,
    required Map<String, dynamic> params,
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
          'template_id': templateId,
          'user_id': publicKey,
          'template_params': params,
        }),
      );

      // 🔐 Record email notification results without logging customer details.
      if (response.statusCode == 200) {
        AppLogger.info(
          'RestaurantNotificationEmailService',
          'Email sent successfully',
        );
      } else {
        AppLogger.warning(
          'RestaurantNotificationEmailService',
          'EmailJS failed: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      AppLogger.error(
        'RestaurantNotificationEmailService',
        'EmailJS error occurred',
      );
    }
  }
}