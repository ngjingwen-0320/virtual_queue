import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../viewmodels/login_viewmodel.dart';
import '../models/user_profile.dart';

class OtpVerificationDialog extends StatefulWidget {
  final LoginViewModel viewModel;
  final Function(UserProfile profile) onSuccess;

  const OtpVerificationDialog({
    super.key,
    required this.viewModel,
    required this.onSuccess,
  });

  @override
  State<OtpVerificationDialog> createState() => _OtpVerificationDialogState();
}

class _OtpVerificationDialogState extends State<OtpVerificationDialog> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _timer;
  int _secondsRemaining = 300; // 5-minute duration
  bool _isExpired = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  /// Starts or restarts the 5-minute countdown timer
  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 300;
      _isExpired = false;
      _errorMessage = null;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() {
          _isExpired = true;
          _errorMessage = 'OTP has expired. Please request a new one.';
        });
        _timer?.cancel();
      }
    });
  }

  /// Handles 6-digit paste event into any single text box
  void _handlePaste(String pastedText) {
    final cleanDigits = pastedText.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.length == 6) {
      for (int i = 0; i < 6; i++) {
        _controllers[i].text = cleanDigits[i];
      }
      _focusNodes[5].requestFocus();
      _verifyOtp();
    }
  }

  /// Executes Phase 2 OTP validation via LoginViewModel
  Future<void> _verifyOtp() async {
    final enteredOtp = _controllers.map((c) => c.text).join();
    if (enteredOtp.length < 6 || _isExpired || widget.viewModel.isLoading) return;

    setState(() => _errorMessage = null);

    final profile = await widget.viewModel.verifyOtp(enteredOtp);
    if (!mounted) return;

    if (profile != null) {
      Navigator.of(context).pop();
      widget.onSuccess(profile);
    } else {
      setState(() {
        _errorMessage = widget.viewModel.errorMessage ?? 'Invalid OTP code.';
      });
    }
  }

  /// Resends a fresh OTP using stored pending credentials and resets timer
  Future<void> _resendOtp() async {
    final email = widget.viewModel.pendingEmail;
    final password = widget.viewModel.pendingPassword;

    if (email == null || password == null) {
      setState(() => _errorMessage = 'Session expired. Please log in again.');
      return;
    }

    // Clear input fields
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();

    final success = await widget.viewModel.requestOtp(email, password);
    if (!mounted) return;

    if (success) {
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new OTP has been sent to your email.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _errorMessage = widget.viewModel.errorMessage ?? 'Failed to resend OTP.';
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        widget.viewModel.cancelOtpSession();
        Navigator.of(context).pop();
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter OTP',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006670),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Sent to ${widget.viewModel.pendingEmail ?? "your email"}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // 6-Digit Pin Input Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 38,
                    height: 50,
                    child: KeyboardListener(
                      focusNode: FocusNode(), // Scoped listener for backspace
                      onKeyEvent: (event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.backspace &&
                            _controllers[i].text.isEmpty &&
                            i > 0) {
                          _focusNodes[i - 1].requestFocus();
                        }
                      },
                      child: TextField(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        enabled: !widget.viewModel.isLoading,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFF006670),
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (val) {
                          if (val.length > 1) {
                            _handlePaste(val);
                            return;
                          }
                          if (val.isNotEmpty && i < 5) {
                            _focusNodes[i + 1].requestFocus();
                          }
                          if (i == 5 && val.isNotEmpty) {
                            _verifyOtp();
                          }
                        },
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 15),

              // Expiry Timer Status
              Text(
                _isExpired ? 'Code Expired' : 'Expires in $minutes:$seconds',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: _isExpired ? Colors.red : Colors.grey[700],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],

              const SizedBox(height: 20),

              // Actions Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: widget.viewModel.isLoading ? null : _resendOtp,
                    child: const Text('Resend Code'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006670),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: (_isExpired || widget.viewModel.isLoading)
                        ? null
                        : _verifyOtp,
                    child: widget.viewModel.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Verify & Login',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}