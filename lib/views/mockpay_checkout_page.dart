import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/mockpay_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'mockpay_receipt_page.dart';

enum MockPayStep {
  loading,
  bankSelection,
  redirecting,
  bankLogin,
  authorisation,
  returning,
  success,
  error,
}

class MockPayCheckoutPage extends StatefulWidget {
  final String reservationId;
  final String restaurantName;
  final MockPayService? service;

  const MockPayCheckoutPage({
    super.key,
    required this.reservationId,
    required this.restaurantName,
    this.service,
  });

  @override
  State<MockPayCheckoutPage> createState() => _MockPayCheckoutPageState();
}

class _MockPayCheckoutPageState extends State<MockPayCheckoutPage> {
  late final MockPayService _service;

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _usernameController = TextEditingController(
    text: 'demo.user',
  );

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _tacController = TextEditingController();

  static const Color background = Color(0xFFFFFFFF);
  static const Color fieldColor = Color(0xFFF0F4F5);
  static const Color primaryColor = Color(0xFF006670);
  static const Color foreground = Color(0xFF134E4A);
  static const Color muted = Color(0xFF48626E);

  MockPayStep _step = MockPayStep.loading;

  String? _selectedBank;
  String? _paymentId;
  String? _merchantId;
  String? _errorMessage;

  int _amountCents = 0;
  bool _busy = false;
  bool _tacSent = false;
  bool _tacVerified = false;

  final List<String> _banks = const [
    'Maybank2u',
    'CIMB Clicks',
    'Public Bank',
    'RHB Now',
    'Hong Leong Connect',
    'AmBank',
    'Bank Islam',
    'Bank Rakyat',
  ];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MockPayService();
    _emailController.text = widget.service == null
        ? FirebaseAuth.instance.currentUser?.email ?? ''
        : 'demo@example.test';
    _initiatePayment();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _tacController.dispose();
    super.dispose();
  }

  String get _formattedAmount => 'RM${(_amountCents / 100).toStringAsFixed(2)}';

  Color get _bankColor => primaryColor;

  void _showError(Object error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _initiatePayment() async {
    try {
      final data = await _service.initiatePayment(widget.reservationId);

      if (!mounted) return;

      final amount = data['amountCents'];
      final paymentId = data['paymentId'];

      if (amount is! int ||
          amount <= 0 ||
          paymentId is! String ||
          paymentId.isEmpty) {
        throw Exception('Invalid payment details returned.');
      }

      setState(() {
        _amountCents = amount;
        _paymentId = paymentId;
        _merchantId = data['merchantId']?.toString();
        _step = data['status'] == 'paid'
            ? MockPayStep.success
            : MockPayStep.bankSelection;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _step = MockPayStep.error;
      });
    }
  }

  Future<void> _continueToBank() async {
    if (_selectedBank == null) {
      _showError('Please select a bank.');
      return;
    }

    if (_emailController.text.trim().isEmpty ||
        !_emailController.text.contains('@')) {
      _showError('Please enter a valid receipt email.');
      return;
    }

    setState(() {
      _step = MockPayStep.redirecting;
    });

    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    setState(() {
      _step = MockPayStep.bankLogin;
    });
  }

  void _loginToDemoBank() {
    if (_usernameController.text.trim() != 'demo.user' ||
        _passwordController.text != 'demo1234') {
      _showError('Use demo.user and demo1234 for this simulation.');
      return;
    }

    setState(() {
      _step = MockPayStep.authorisation;
    });
  }

  Future<void> _requestTac() async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    try {
      await _service.requestOtp(paymentId: _paymentId, bankName: _selectedBank);

      if (!mounted) return;

      setState(() {
        _tacSent = true;
        _tacVerified = false;
        _tacController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'MockPay verification code sent to your '
            'registered email.',
          ),
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _confirmPayment() async {
    if (_busy || !_tacSent || _paymentId == null) return;

    final tac = _tacController.text.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(tac)) {
      _showError('Please enter the six-digit code.');
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      if (!_tacVerified) {
        await _service.verifyOtp(tac, paymentId: _paymentId);
        _tacVerified = true;
      }

      final result = await _service.confirmPayment(_paymentId!);

      if (result['status'] != 'paid') {
        throw Exception('Payment was not confirmed.');
      }

      if (!mounted) return;

      setState(() {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _step = MockPayStep.returning;
        _busy = false;
      });

      await Future.delayed(const Duration(milliseconds: 1200));

      if (!mounted) return;

      setState(() {
        _step = MockPayStep.success;
      });
    } catch (error) {
      if (await _recoverPaidPayment()) return;
      _showError(error);

      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<bool> _recoverPaidPayment() async {
    if (_paymentId == null) return false;
    try {
      final payment = await _service.getPaymentStatus(_paymentId!);
      if (payment['status'] == 'paid' && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        setState(() {
          _step = MockPayStep.success;
          _busy = false;
        });
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _leaveCheckout() async {
    if (_busy) return;
    if (_step == MockPayStep.success || _paymentId == null) {
      Navigator.of(context).pop(_step == MockPayStep.success);
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.cancelPayment(_paymentId!);
      if (mounted) Navigator.of(context).pop(false);
    } catch (error) {
      if (await _recoverPaidPayment()) return;
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _header(String title, String subtitle, {Color color = primaryColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _button(
    String text,
    VoidCallback? onPressed, {
    Color color = primaryColor,
    bool outlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
    );
  }

  Widget _input(
    TextEditingController controller, {
    String? hint,
    bool obscure = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      cursorColor: primaryColor,
      readOnly: controller == _emailController,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: foreground),
      decoration: InputDecoration(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintText: hint,
        hintStyle: const TextStyle(color: muted),
        filled: true,
        fillColor: fieldColor,
        contentPadding: const EdgeInsets.all(17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
    );
  }

  Widget _detailsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: muted, fontSize: 14),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: foreground,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageCard(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }

  Widget _buildBankSelection() {
    return _pageCard(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(
            'MockPay · FPX online banking',
            'Paying ${widget.restaurantName} · $_formattedAmount',
          ),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose your bank', style: TextStyle(color: muted)),
                const SizedBox(height: 12),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _banks.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3.1,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    final bank = _banks[index];
                    final selected = _selectedBank == bank;

                    return OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedBank = bank;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: selected
                            ? const Color(0xFFE9F5F4)
                            : fieldColor,
                        side: BorderSide(
                          color: selected
                              ? primaryColor
                              : const Color(0xFFE5E7EB),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        bank,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: foreground, fontSize: 12),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                const Text(
                  'Receipt email (your registered account)',
                  style: TextStyle(color: muted),
                ),

                const SizedBox(height: 10),

                _input(
                  _emailController,
                  hint: 'alex@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 32),

                _button('Continue to your bank', _continueToBank),

                const SizedBox(height: 10),

                _button('Back to restaurant', _leaveCheckout, outlined: true),

                const SizedBox(height: 18),

                const Text(
                  'Mock FPX. Bank names are for illustration '
                  'only. No real banks or funds are involved.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading({
    required String heading,
    required String subtitle,
    required Color color,
  }) {
    return _pageCard(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(heading, subtitle, color: color),
          const SizedBox(height: 40),
          const CircularProgressIndicator(color: primaryColor),
          const SizedBox(height: 24),
          Text(
            _step == MockPayStep.redirecting
                ? 'Redirecting to $_selectedBank...'
                : 'Returning to ${widget.restaurantName}...',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: foreground,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Please keep this screen open.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 45),
        ],
      ),
    );
  }

  Widget _buildBankLogin() {
    return _pageCard(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(
            _selectedBank ?? 'Mock Bank',
            'Mock internet banking · Demo only',
            color: _bankColor,
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DEMO BANK LOGIN — NOT A REAL BANK',
                  style: TextStyle(color: muted, fontSize: 12),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Security phrase: Blue Heron 42',
                  style: TextStyle(color: primaryColor),
                ),

                const SizedBox(height: 22),

                const Text('Demo username', style: TextStyle(color: muted)),

                const SizedBox(height: 8),

                _input(_usernameController),

                const SizedBox(height: 18),

                const Text('Demo password', style: TextStyle(color: muted)),

                const SizedBox(height: 8),

                _input(
                  _passwordController,
                  hint: 'Use demo1234',
                  obscure: true,
                ),

                const SizedBox(height: 12),

                const Text(
                  'Demo credentials: demo.user / demo1234\n'
                  'Never enter a real banking password.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),

                const SizedBox(height: 28),

                _button('Log in', _loginToDemoBank, color: _bankColor),

                const SizedBox(height: 10),

                _button('Cancel transaction', _leaveCheckout, outlined: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorisation() {
    return _pageCard(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(
            _selectedBank ?? 'Mock Bank',
            'Authorise simulated FPX payment',
            color: _bankColor,
          ),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailsRow('Merchant', widget.restaurantName),
                _detailsRow('Transaction ID', _paymentId ?? '-'),
                _detailsRow('From account', 'Demo Savings •••• 4821'),
                _detailsRow('Amount', _formattedAmount),

                const Divider(color: Color(0xFFE5E7EB), height: 32),

                _button(
                  _tacSent ? 'Resend TAC' : 'Request TAC',
                  _busy ? null : _requestTac,
                  outlined: true,
                ),

                const SizedBox(height: 20),

                const Text('Enter TAC', style: TextStyle(color: muted)),

                const SizedBox(height: 10),

                _input(
                  _tacController,
                  hint: '6-digit verification code',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),

                const SizedBox(height: 8),

                const Text(
                  'For this simulation, the TAC is a '
                  'MockPay email OTP sent by your backend.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),

                const SizedBox(height: 28),

                _button(
                  _busy ? 'Processing...' : 'Confirm payment',
                  (_busy || !_tacSent) ? null : _confirmPayment,
                  color: _bankColor,
                ),

                const SizedBox(height: 10),

                _button(
                  'Cancel transaction',
                  _busy ? null : _leaveCheckout,
                  outlined: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return _pageCard(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header('MockPay · FPX online banking', 'Payment complete'),

          Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                const SizedBox(height: 15),

                const Icon(
                  Icons.check_circle_rounded,
                  size: 95,
                  color: Color(0xFF22C55E),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Payment successful',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: foreground,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Your simulated deposit has been recorded. '
                  'Restaurant approval is still required.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),

                const SizedBox(height: 28),

                _detailsRow('Merchant', widget.restaurantName),
                _detailsRow('Amount', _formattedAmount),
                _detailsRow('Bank', _selectedBank ?? '-'),
                _detailsRow('Status', 'PAID'),
                _detailsRow('Merchant ID', _merchantId ?? '-'),
                _detailsRow('Transaction ID', _paymentId ?? '-'),
                const SizedBox(height: 12),
                _button(
                  'View receipt',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MockPayReceiptPage(
                        paymentId: _paymentId!,
                        service: _service,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Simulation only — no real funds transferred.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: muted),
                ),

                const SizedBox(height: 28),

                _button(
                  'Back to restaurant',
                  () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return _pageCard(
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
            const SizedBox(height: 12),
            const Text(
              'Unable to start payment',
              style: TextStyle(color: foreground, fontSize: 20),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 20),
            _button('Retry', () {
              setState(() {
                _step = MockPayStep.loading;
              });
              _initiatePayment();
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    switch (_step) {
      case MockPayStep.loading:
        content = const Center(
          child: CircularProgressIndicator(color: primaryColor),
        );
        break;

      case MockPayStep.bankSelection:
        content = _buildBankSelection();
        break;

      case MockPayStep.redirecting:
        content = _buildLoading(
          heading: 'MockPay · FPX online banking',
          subtitle: 'Connecting securely (simulation)',
          color: primaryColor,
        );
        break;

      case MockPayStep.bankLogin:
        content = _buildBankLogin();
        break;

      case MockPayStep.authorisation:
        content = _buildAuthorisation();
        break;

      case MockPayStep.returning:
        content = _buildLoading(
          heading: _selectedBank ?? 'Mock Bank',
          subtitle: 'Simulated payment authorised',
          color: _bankColor,
        );
        break;

      case MockPayStep.success:
        content = _buildSuccess();
        break;

      case MockPayStep.error:
        content = _buildError();
        break;
    }

    return PopScope(
      canPop: _step == MockPayStep.success,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_busy) _leaveCheckout();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6FAFB),
        appBar: AppBar(
          backgroundColor: const Color(0xFF115E59),
          foregroundColor: Colors.white,
          title: const Text('MockPay · Simulation'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _busy ? null : _leaveCheckout,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: content,
          ),
        ),
      ),
    );
  }
}
