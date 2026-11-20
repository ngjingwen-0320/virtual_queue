import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class MockPayService {
  final http.Client _client;
  final Future<String> Function()? _tokenProvider;
  final String? _apiBaseUrl;
  MockPayService({
    http.Client? client,
    Future<String> Function()? tokenProvider,
    String? apiBaseUrl,
  }) : _client = client ?? http.Client(),
       _tokenProvider = tokenProvider,
       _apiBaseUrl = apiBaseUrl;
  String get _url => _apiBaseUrl ?? baseUrl;

  // ========================================
  // API BASE URL
  // ========================================

  static String get baseUrl {
    const configured = String.fromEnvironment('MOCKPAY_BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) {
      return 'http://localhost:3000/api/mockpay';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android Emulator
        return 'http://10.0.2.2:3000/api/mockpay';

      default:
        return 'http://localhost:3000/api/mockpay';
    }
  }

  // ========================================
  // FIREBASE AUTHENTICATION TOKEN
  // ========================================

  Future<String> _getFirebaseIdToken() async {
    if (_tokenProvider != null) return _tokenProvider();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please log in before using MockPay.');
    }

    final token = await user.getIdToken();

    if (token == null || token.isEmpty) {
      throw Exception('Unable to obtain Firebase ID token.');
    }

    return token;
  }

  // ========================================
  // HANDLE BACKEND RESPONSE
  // ========================================

  Map<String, dynamic> _handleResponse(http.Response response) {
    Map<String, dynamic> data;

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw const FormatException('Invalid response format');
      }

      data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw Exception(
        'Invalid MockPay server response '
        '(HTTP ${response.statusCode}).',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['message']?.toString() ??
            'MockPay request failed '
                '(HTTP ${response.statusCode}).',
      );
    }

    return data;
  }

  // ========================================
  // POST HELPER
  // ========================================

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final token = await _getFirebaseIdToken();

    try {
      final response = await _client
          .post(
            Uri.parse('$_url$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } on TimeoutException {
      throw Exception('MockPay request timed out.');
    } on http.ClientException catch (error) {
      throw Exception('Cannot connect to MockPay: ${error.message}');
    }
  }

  // ========================================
  // GET HELPER
  // ========================================

  Future<Map<String, dynamic>> _get(String endpoint) async {
    final token = await _getFirebaseIdToken();

    try {
      final response = await _client
          .get(
            Uri.parse('$_url$endpoint'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } on TimeoutException {
      throw Exception('MockPay request timed out.');
    } on http.ClientException catch (error) {
      throw Exception('Cannot connect to MockPay: ${error.message}');
    }
  }

  // ========================================
  // 1. REQUEST OTP
  // ========================================

  Future<void> requestOtp({String? paymentId, String? bankName}) async {
    await _post('/otp/request', {
      if (paymentId != null) 'paymentId': paymentId,
      if (bankName != null) 'bankName': bankName,
    });
  }

  // ========================================
  // 2. VERIFY OTP
  // ========================================

  Future<void> verifyOtp(String otp, {String? paymentId}) async {
    await _post('/otp/verify', {
      'otp': otp.trim(),
      if (paymentId != null) 'paymentId': paymentId,
    });
  }

  // ========================================
  // 3. REGISTER MERCHANT
  // ========================================

  Future<Map<String, dynamic>> registerMerchant({
    required String brandId,
    required String businessName,
    required String bankName,
    required String accountNumber,
  }) async {
    return _post('/register-merchant', {
      'brandId': brandId,
      'businessName': businessName,
      'bankName': bankName,
      'accountNumber': accountNumber,
    });
  }

  // ========================================
  // 4. GET MERCHANT STATUS
  // ========================================

  Future<Map<String, dynamic>> getMerchantStatus() async {
    return _get('/merchant/status');
  }

  // ========================================
  // 5. INITIATE CUSTOMER PAYMENT
  // ========================================

  Future<Map<String, dynamic>> initiatePayment(String reservationId) async {
    return _post('/payments/initiate', {'reservationId': reservationId});
  }

  // ========================================
  // 6. CONFIRM CUSTOMER PAYMENT
  // ========================================

  Future<Map<String, dynamic>> confirmPayment(String paymentId) async {
    return _post('/payments/confirm', {'paymentId': paymentId});
  }

  // ========================================
  // 7. GET PAYMENT STATUS
  // ========================================

  Future<Map<String, dynamic>> getPaymentStatus(String paymentId) async {
    final encodedId = Uri.encodeComponent(paymentId);

    return _get('/payments/$encodedId');
  }

  Future<Map<String, dynamic>> createReservation(Map<String, dynamic> data) =>
      _post('/reservations', data);
  Future<Map<String, dynamic>> reservationAction(
    String reservationId,
    String action, [
    Map<String, dynamic> data = const {},
  ]) => _post('/reservations/action', {
    'reservationId': reservationId,
    'action': action,
    ...data,
  });
  Future<void> cancelPayment(String paymentId) async {
    await _post('/payments/cancel', {'paymentId': paymentId});
  }

  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    final data = await _get('/payments');
    return (data['payments'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
