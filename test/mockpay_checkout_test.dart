import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_queue/services/mockpay_service.dart';
import 'package:virtual_queue/views/mockpay_checkout_page.dart';
import 'package:virtual_queue/views/mockpay_receipt_page.dart';

class FakeMockPay extends MockPayService {
  bool failStart = false;
  bool callbackVerified = false;
  bool failConfirm = false;
  bool loseConfirmationResponse = false;
  String? otpPayment;
  String? confirmedPayment;
  bool cancelled = false;
  @override
  Future<Map<String, dynamic>> initiatePayment(String reservationId) async {
    if (failStart) throw Exception('Merchant unavailable');
    return {
      'paymentId': reservationId,
      'merchantId': 'MP_demo',
      'amountCents': 3000,
      'status': 'pending',
    };
  }

  @override
  Future<void> requestOtp({String? paymentId, String? bankName}) async {
    otpPayment = paymentId;
  }

  @override
  Future<void> verifyOtp(String otp, {String? paymentId}) async {
    if (otp != '123456' || paymentId != otpPayment) {
      throw Exception('Invalid TAC');
    }
  }

  @override
  Future<Map<String, dynamic>> confirmPayment(String paymentId) async {
    if (failConfirm) throw Exception('Payment expired');
    confirmedPayment = paymentId;
    if (loseConfirmationResponse) throw Exception('Connection lost');
    return {'status': 'paid'};
  }

  @override
  Future<void> cancelPayment(String paymentId) async {
    cancelled = true;
  }

  @override
  Future<Map<String, dynamic>> getPaymentStatus(String paymentId) async => {
    'reservationId': paymentId,
    'merchantId': 'MP_demo',
    'restaurantName': 'Demo Restaurant',
    'amountCents': 3000,
    'status': failConfirm ? 'pending' : 'paid',
    'bankName': 'Maybank2u',
    'callbackSignatureVerified': callbackVerified,
    if (callbackVerified) 'callbackEventId': 'demo-callback-event',
    'receiptEmail': 'demo@example.test',
    'paidAt': '2026-11-11T01:00:00Z',
  };
}

Future<void> tap(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> authorise(WidgetTester tester, FakeMockPay service) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MockPayCheckoutPage(
        reservationId: 'booking',
        restaurantName: 'Demo Restaurant',
        service: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tap(tester, 'Maybank2u');
  await tap(tester, 'Continue to your bank');
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
  final password = find.byType(TextField).last;
  await tester.ensureVisible(password);
  await tester.enterText(password, 'demo1234');
  await tap(tester, 'Log in');
  await tap(tester, 'Request TAC');
  final tac = find.byType(TextField).last;
  await tester.ensureVisible(tac);
  await tester.enterText(tac, '123456');
}

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['MOCKPAY_SCREENSHOTS'] != '1') return;
  final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/mockpay-preview/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (Platform.environment['MOCKPAY_SCREENSHOTS'] != '1') return;
    final textFont = File('C:/Windows/Fonts/segoeui.ttf');
    if (await textFont.exists()) {
      final loader = FontLoader('Roboto')
        ..addFont(
          textFont.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
    final icons = File(
      'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (await icons.exists()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(
          icons.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });
  testWidgets(
    'checkout completes scoped TAC flow and displays backend receipt',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = FakeMockPay();
      await authorise(tester, service);
      await tap(tester, 'Confirm payment');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(service.otpPayment, 'booking');
      expect(service.confirmedPayment, 'booking');
      expect(find.text('Payment successful'), findsOneWidget);
      await capture(tester, 'success');
      await tap(tester, 'View receipt');
      await capture(tester, 'receipt');
      expect(find.text('Simulated payment receipt'), findsOneWidget);
      expect(find.text('RM30.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed confirmation never displays success', (tester) async {
    final service = FakeMockPay()..failConfirm = true;
    await authorise(tester, service);
    await tap(tester, 'Confirm payment');
    expect(find.text('Payment successful'), findsNothing);
    expect(find.text('Payment expired'), findsOneWidget);
    expect(service.confirmedPayment, isNull);
  });
  testWidgets('lost confirmation response recovers the paid server status', (
    tester,
  ) async {
    final service = FakeMockPay()..loseConfirmationResponse = true;
    await authorise(tester, service);
    await tap(tester, 'Confirm payment');
    expect(find.text('Payment successful'), findsOneWidget);
    expect(service.confirmedPayment, 'booking');
  });
  testWidgets('initial API failure offers retry', (tester) async {
    final service = FakeMockPay()..failStart = true;
    await tester.pumpWidget(
      MaterialApp(
        home: MockPayCheckoutPage(
          reservationId: 'booking',
          restaurantName: 'Demo Restaurant',
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to start payment'), findsOneWidget);
    service.failStart = false;
    await tap(tester, 'Retry');
    expect(find.text('Choose your bank'), findsOneWidget);
  });
  testWidgets('leaving checkout cancels the pending backend attempt', (
    tester,
  ) async {
    final service = FakeMockPay();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MockPayCheckoutPage(
                  reservationId: 'booking',
                  restaurantName: 'Demo Restaurant',
                  service: service,
                ),
              ),
            ),
            child: const Text('Open checkout'),
          ),
        ),
      ),
    );
    await tap(tester, 'Open checkout');
    await tap(tester, 'Back to restaurant');
    expect(service.cancelled, true);
    expect(find.text('Open checkout'), findsOneWidget);
  });
  testWidgets('receipt displays backend transaction details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MockPayReceiptPage(paymentId: 'booking', service: FakeMockPay()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PAID'), findsOneWidget);
    expect(find.text('demo@example.test'), findsOneWidget);
  });
  testWidgets(
    'receipt shows signature proof only when returned by the backend',
    (tester) async {
      final service = FakeMockPay()..callbackVerified = true;
      await tester.pumpWidget(
        MaterialApp(
          home: MockPayReceiptPage(paymentId: 'booking', service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('HMAC-SHA256 signature verified'), findsOneWidget);
      expect(find.text('demo-callback-event'), findsOneWidget);
    },
  );
}
