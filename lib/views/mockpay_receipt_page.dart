import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/mockpay_service.dart';

class MockPayReceiptPage extends StatefulWidget {
  final String paymentId;
  final MockPayService? service;
  const MockPayReceiptPage({super.key, required this.paymentId, this.service});
  @override
  State<MockPayReceiptPage> createState() => _MockPayReceiptPageState();
}

class _MockPayReceiptPageState extends State<MockPayReceiptPage> {
  late Future<Map<String, dynamic>> _receipt;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _receipt = (widget.service ?? MockPayService()).getPaymentStatus(
      widget.paymentId,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6FAFB),
    appBar: AppBar(
      backgroundColor: const Color(0xFF115E59),
      foregroundColor: Colors.white,
      title: const Text('MockPay receipt'),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _receipt,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(snapshot.error.toString(), textAlign: TextAlign.center),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF006670),
                  ),
                  onPressed: () => setState(_load),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF006670)),
          );
        }
        final data = snapshot.data!;
        final amount =
            'RM${((data['amountCents'] as num) / 100).toStringAsFixed(2)}';
        final rows = <String, String>{
          'Transaction': widget.paymentId,
          'Reservation': data['reservationId'].toString(),
          'Merchant':
              data['restaurantName']?.toString() ??
              data['merchantId'].toString(),
          'Amount': amount,
          'Status': data['status'].toString().toUpperCase(),
          'Bank': data['bankName']?.toString() ?? '-',
          'Bank callback': data['callbackSignatureVerified'] == true
              ? 'HMAC-SHA256 signature verified'
              : (data['status'] == 'paid' || data['status'] == 'refunded')
              ? 'Not recorded for this payment'
              : 'Not verified yet',
          if (data['callbackSignatureVerified'] == true &&
              data['callbackEventId'] != null)
            'Callback event': data['callbackEventId'].toString(),
          'Receipt email': data['receiptEmail']?.toString() ?? '-',
          'Paid at': data['paidAt'] == null
              ? '-'
              : DateTime.parse(data['paidAt']).toLocal().toString(),
          if (data['refundedAt'] != null)
            'Refunded at': DateTime.parse(
              data['refundedAt'],
            ).toLocal().toString(),
        };
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.receipt_long, size: 64, color: Color(0xFF006670)),
            const SizedBox(height: 16),
            const Text(
              'Simulated payment receipt',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            for (final row in rows.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.key, style: const TextStyle(color: Colors.grey)),
                    SelectableText(row.value),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF006670),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text:
                        'MockPay simulation\n${rows.entries.map((e) => '${e.key}: ${e.value}').join('\n')}\nNo real funds transferred.',
                  ),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Receipt copied')),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy receipt'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Simulation only. No real funds transferred. Receipt email is recorded; no receipt email is sent.',
            ),
          ],
        );
      },
    ),
  );
}

class MockPayHistoryPage extends StatefulWidget {
  const MockPayHistoryPage({super.key});
  @override
  State<MockPayHistoryPage> createState() => _MockPayHistoryPageState();
}

class _MockPayHistoryPageState extends State<MockPayHistoryPage> {
  late Future<List<Map<String, dynamic>>> _payments;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _payments = MockPayService().getPaymentHistory();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6FAFB),
    appBar: AppBar(
      backgroundColor: const Color(0xFF115E59),
      foregroundColor: Colors.white,
      title: const Text('Simulated payment history'),
      actions: [
        IconButton(
          onPressed: () => setState(_load),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _payments,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF006670)),
          );
        }
        if (snapshot.data!.isEmpty) {
          return const Center(child: Text('No simulated payments yet'));
        }
        return ListView(
          children: [
            for (final payment in snapshot.data!)
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text(
                  payment['restaurantName']?.toString() ??
                      'Reservation deposit',
                ),
                subtitle: Text(
                  '${payment['status']} · ${payment['paymentId']}',
                ),
                trailing: Text(
                  'RM${((payment['amountCents'] as num) / 100).toStringAsFixed(2)}',
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MockPayReceiptPage(paymentId: payment['paymentId']),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
