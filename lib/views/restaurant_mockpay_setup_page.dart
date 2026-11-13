
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/mockpay_service.dart';

class RestaurantMockPaySetupPage extends StatefulWidget {
  final String brandId;
  final String restaurantName;

  const RestaurantMockPaySetupPage({
    super.key,
    required this.brandId,
    required this.restaurantName,
  });

  @override
  State<RestaurantMockPaySetupPage> createState() =>
      _RestaurantMockPaySetupPageState();
}

class _RestaurantMockPaySetupPageState
    extends State<RestaurantMockPaySetupPage> {
  final _formKey = GlobalKey<FormState>();

  final MockPayService _mockPayService = MockPayService();

  final TextEditingController _bankNameController =
  TextEditingController();

  final TextEditingController _accountNumberController =
  TextEditingController();

  bool _isLoading = false;
  bool _otpVerified = false;
  bool _merchantRegistered = false;

  String? _merchantId;
  String? _merchantStatus;

  static const Color primaryColor = Color(0xFF006670);
  static const Color darkTeal = Color(0xFF115E59);
  static const Color backgroundColor = Color(0xFFF6FAFB);

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  // ========================================
  // GENERAL HELPERS
  // ========================================

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
          ),
        ),
        backgroundColor: isError ? Colors.red : darkTeal,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ========================================
  // REQUEST OTP AND OPEN VERIFICATION PANEL
  // ========================================

  Future<void> _requestOtp() async {
    if (_isLoading || _merchantRegistered) return;

    setState(() {
      _isLoading = true;
      _otpVerified = false;
    });

    try {
      // OTP is generated and emailed by Node.js.
      await _mockPayService.requestOtp();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Verification OTP sent to your email.');

      // Open login-style OTP verification panel.
      final verified = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        builder: (_) => _MockPayOtpPanel(
          mockPayService: _mockPayService,
          email: FirebaseAuth.instance.currentUser?.email ?? '',
        ),
      );

      if (!mounted) return;

      if (verified == true) {
        setState(() {
          _otpVerified = true;
        });

        _showMessage('MockPay OTP verified successfully!');
      }
    } catch (error) {
      _showMessage(
        _cleanError(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ========================================
  // REGISTER MOCKPAY MERCHANT
  // ========================================

  Future<void> _registerMerchant() async {
    if (_isLoading || _merchantRegistered) return;

    if (!_otpVerified) {
      _showMessage(
        'Please complete email OTP verification first.',
        isError: true,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String bankName =
    _bankNameController.text.trim();

    final String accountNumber =
    _accountNumberController.text.replaceAll(
      RegExp(r'[\s-]'),
      '',
    );

    final String lastFour =
    accountNumber.substring(accountNumber.length - 4);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Confirm Merchant Registration',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Business: ${widget.restaurantName}\n\n'
              'Bank: $bankName\n\n'
              'Account ending: $lastFour\n\n'
              'Register this fictional bank account with MockPay?',
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text(
              'Register',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _mockPayService.registerMerchant(
        brandId: widget.brandId,
        businessName: widget.restaurantName,
        bankName: bankName,
        accountNumber: accountNumber,
      );

      if (!mounted) return;

      final id = result['merchantId']?.toString();

      if (id == null || id.isEmpty) {
        throw Exception(
          'Merchant registration response has no Merchant ID.',
        );
      }

      setState(() {
        _merchantId = id;
        _merchantStatus = result['status']?.toString();
        _merchantRegistered = true;
      });

      _showMessage(
        'MockPay merchant registered successfully!',
      );
    } catch (error) {
      _showMessage(
        _cleanError(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ========================================
  // INPUT DECORATION
  // ========================================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: primaryColor,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE5E7EB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: primaryColor,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF171C1D),
      ),
    );
  }

  // ========================================
  // PRIMARY BUTTON
  // ========================================

  Widget _primaryButton({
    required String text,
    required VoidCallback? onPressed,
    required IconData icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
          const Color(0xFFB8C9CB),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _isLoading
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : Icon(icon, size: 20),
        label: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ========================================
  // MERCHANT REGISTRATION SUCCESS
  // ========================================

  Widget _buildSuccessPage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 76,
            color: Color(0xFF16A34A),
          ),

          const SizedBox(height: 16),

          const Text(
            'Merchant Registered',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            widget.restaurantName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            'Merchant ID',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 8),

          SelectableText(
            _merchantId ?? '-',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: darkTeal,
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Merchant Status',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            (_merchantStatus ?? 'unknown').toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF16A34A),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 30),

          _primaryButton(
            text: 'Back to Restaurant Profile',
            icon: Icons.arrow_back,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ========================================
  // MAIN PAGE
  // ========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: darkTeal,
        elevation: 0,
        title: const Text(
          'MockPay Merchant Setup',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.bold,
            color: Color(0xFF134E4A),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),

        child: _merchantRegistered
            ? _buildSuccessPage()
            : Form(
          key: _formKey,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -----------------------
              // Information card
              // -----------------------

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F5F4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.security_rounded,
                      color: primaryColor,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'MockPay is a simulated payment '
                            'gateway. Use fictional bank details '
                            'only. No real funds are transferred.',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          color: darkTeal,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // -----------------------
              // Business information
              // -----------------------

              _sectionTitle('Business Information'),

              const SizedBox(height: 12),

              TextFormField(
                initialValue: widget.restaurantName,
                readOnly: true,
                decoration: _inputDecoration(
                  hint: 'Registered business name',
                  icon: Icons.store_outlined,
                ),
              ),

              const SizedBox(height: 24),

              // -----------------------
              // Bank information
              // -----------------------

              _sectionTitle('Bank Information'),

              const SizedBox(height: 12),

              TextFormField(
                controller: _bankNameController,
                textCapitalization:
                TextCapitalization.words,
                decoration: _inputDecoration(
                  hint: 'Example: Maybank',
                  icon: Icons.account_balance_outlined,
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Please enter bank name';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(20),
                ],
                decoration: _inputDecoration(
                  hint: 'Fictional bank account number',
                  icon: Icons.credit_card_outlined,
                ),
                validator: (value) {
                  final account = (value ?? '').trim();

                  if (!RegExp(r'^\d{8,20}$')
                      .hasMatch(account)) {
                    return 'Enter 8–20 digits';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 28),

              // -----------------------
              // Email verification
              // -----------------------

              _sectionTitle('Email Verification'),

              const SizedBox(height: 8),

              Text(
                'A six-digit verification code will be '
                    'sent to ${FirebaseAuth.instance.currentUser?.email ?? "your registered email"}.',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 18),

              if (!_otpVerified)
                _primaryButton(
                  text: 'Send Verification OTP',
                  icon: Icons.mark_email_read_outlined,
                  onPressed: _requestOtp,
                ),

              // -----------------------
              // OTP verified message
              // -----------------------

              if (_otpVerified)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F7EF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF16A34A),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Email OTP verified successfully.',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 28),

              // -----------------------
              // Register merchant
              // -----------------------

              _primaryButton(
                text: 'Register MockPay Merchant',
                icon:
                Icons.account_balance_wallet_outlined,
                onPressed:
                _otpVerified ? _registerMerchant : null,
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================
// LOGIN-STYLE MOCKPAY OTP VERIFICATION BOTTOM SHEET
// =======================================================

class _MockPayOtpPanel extends StatefulWidget {
  final MockPayService mockPayService;
  final String email;

  const _MockPayOtpPanel({
    required this.mockPayService,
    required this.email,
  });

  @override
  State<_MockPayOtpPanel> createState() =>
      _MockPayOtpPanelState();
}

class _MockPayOtpPanelState
    extends State<_MockPayOtpPanel> {
  final TextEditingController _otpController =
  TextEditingController();

  String? _verificationError;
  bool _isVerifying = false;
  bool _isResending = false;

  static const Color primaryColor = Color(0xFF006670);

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _showPanelMessage(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) return;

    if (isError) {
      setState(() => _verificationError = message);
      return;
    }
    setState(() => _verificationError = null);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
        isError ? Colors.red : primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ========================================
  // VERIFY OTP THROUGH NODE.JS
  // ========================================

  Future<void> _verifyOtp() async {
    if (_isVerifying || _isResending) return;

    final otp = _otpController.text.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _showPanelMessage(
        'Please enter a valid 6-digit OTP.',
        isError: true,
      );
      return;
    }

    setState(() {
      _verificationError = null;
      _isVerifying = true;
    });

    try {
      await widget.mockPayService.verifyOtp(otp);

      if (!mounted) return;

      // Return successful verification to parent page.
      Navigator.pop(context, true);
    } catch (error) {
      _showPanelMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  // ========================================
  // RESEND OTP
  // ========================================

  Future<void> _resendOtp() async {
    if (_isResending || _isVerifying) return;

    setState(() {
      _isResending = true;
    });

    try {
      await widget.mockPayService.requestOtp();

      if (!mounted) return;

      _otpController.clear();

      _showPanelMessage(
        'A new verification code has been sent.',
      );
    } catch (error) {
      _showPanelMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  // ========================================
  // OTP VERIFICATION PANEL UI
  // ========================================

  @override
  Widget build(BuildContext context) {
    final busy = _isVerifying || _isResending;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),

      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          24, 20, 24, 30,
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bottom sheet drag indicator
            Container(
              width: 45,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 20),

            // Title and close button
            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Email Verification',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF134E4A),
                  ),
                ),

                IconButton(
                  onPressed: busy
                      ? null
                      : () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Verification icon
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: Color(0xFFE9F5F4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                size: 44,
                color: primaryColor,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Enter Verification Code',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF171C1D),
              ),
            ),

            const SizedBox(height: 10),

            Text(
              widget.email.isEmpty
                  ? 'We sent a 6-digit verification code '
                  'to your registered email.'
                  : 'We sent a 6-digit verification code to:\n'
                  '${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),

            const SizedBox(height: 28),

            // OTP Input
            TextField(
              controller: _otpController,
              enabled: !busy,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!busy) {
                  _verifyOtp();
                }
              },
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 25,
                fontWeight: FontWeight.bold,
                letterSpacing: 10,
                color: primaryColor,
              ),
              decoration: InputDecoration(
                errorText: _verificationError,
                errorMaxLines: 3,
                errorStyle: const TextStyle(fontSize: 13, letterSpacing: 0),
                hintText: '000000',
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFD1D5DB),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'This code expires in 5 minutes.',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: Color(0xFF64748B),
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 24),

            // Verify button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: busy ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                  const Color(0xFFB8C9CB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isVerifying
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'Verify OTP',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Resend OTP button
            TextButton(
              onPressed: busy ? null : _resendOtp,
              child: _isResending
                  ? const Text(
                'Sending...',
                style: TextStyle(
                  color: primaryColor,
                ),
              )
                  : const Text(
                'Didn\'t receive the code? Resend OTP',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
