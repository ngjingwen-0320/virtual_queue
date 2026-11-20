import '../widgets/malaysian_phone_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart' as inset;
import 'package:flutter/gestures.dart';
import 'package:virtual_queue/viewmodels/register_viewmodel.dart';
import 'package:virtual_queue/views/login_page.dart';

class CustomerRegisterPage extends StatefulWidget {
  const CustomerRegisterPage({super.key});

  @override
  State<CustomerRegisterPage> createState() => _CustomerRegisterPageState();
}

class _CustomerRegisterPageState extends State<CustomerRegisterPage> {
  final viewModel = RegisterViewmodel();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();

    passwordController.addListener(() {
      setState(() {});
    });
  }

  Future<void> registerCustomer() async {
    final profile = await viewModel.registerCustomer(
      name: nameController.text.trim(),
      email: emailController.text.trim(),
      phone: phoneController.text.trim(),
      password: passwordController.text.trim(),
      confirmPassword: confirmPasswordController.text.trim(),
    );

    // Stop if this page is no longer active after waiting for Firebase.
    if (!mounted) return;

    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.errorMessage ?? 'Registration failed'),
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
    );

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Registration successful!'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget passwordRequirement(String text, bool isValid) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isValid ? Icons.check_circle_outline : Icons.cancel_outlined,
          color: isValid ? Colors.green : Colors.grey,
          size: 15,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: isValid ? Colors.green : Colors.grey,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildPasswordRequirements() {
    final password = passwordController.text;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 15,
            runSpacing: 8,
            children: [
              passwordRequirement('Min. 8 characters', password.length >= 8),
              passwordRequirement(
                'Include lowercase letter',
                RegExp(r'[a-z]').hasMatch(password),
              ),
              passwordRequirement(
                'Include uppercase letter',
                RegExp(r'[A-Z]').hasMatch(password),
              ),
              passwordRequirement(
                'Include number',
                RegExp(r'[0-9]').hasMatch(password),
              ),
              passwordRequirement(
                'Include special character',
                RegExp(
                  r'''[\^$*.\[\]{}()?"!@#%&/\\,><':;|_~]''',
                ).hasMatch(password),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Free the text controllers when this page is removed.
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFF8FDFD),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Register as Customer',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 30),
            Text(
              'Name',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight(550)),
            ),
            SizedBox(height: 10),
            Container(
              decoration: inset.BoxDecoration(
                color: Color(0xFFF2F8F8),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  inset.BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 2,
                    offset: Offset(2, 2),
                    inset: true,
                  ),
                ],
              ),
              child: TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'John Doe',
                  hintStyle: TextStyle(color: Colors.grey),
                  filled: false,
                  fillColor: Color(0xFFFFFFFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Email',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight(550)),
            ),
            SizedBox(height: 10),
            Container(
              decoration: inset.BoxDecoration(
                color: Color(0xFFF2F8F8),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  inset.BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 2,
                    offset: Offset(2, 2),
                    inset: true,
                  ),
                ],
              ),
              child: TextField(
                controller: emailController,
                decoration: InputDecoration(
                  hintText: 'example@gmail.com',
                  hintStyle: TextStyle(color: Colors.grey),
                  filled: false,
                  fillColor: Color(0xFFFFFFFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Phone Number',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight(550)),
            ),
            SizedBox(height: 10),
            MalaysianPhoneField(controller: phoneController),
            SizedBox(height: 20),
            Text(
              'Password',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight(550)),
            ),
            SizedBox(height: 10),
            Container(
              decoration: inset.BoxDecoration(
                color: Color(0xFFF2F8F8),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  inset.BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 2,
                    offset: Offset(2, 2),
                    inset: true,
                  ),
                ],
              ),
              child: TextField(
                controller: passwordController,
                obscureText: !isPasswordVisible,
                decoration: InputDecoration(
                  hintText: 'password',
                  hintStyle: TextStyle(color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        isPasswordVisible = !isPasswordVisible;
                      });
                    },
                  ),
                  filled: false,
                  fillColor: Color(0xFFFFFFFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            buildPasswordRequirements(),
            SizedBox(height: 20),
            Text(
              'Confirm Password',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight(550)),
            ),
            SizedBox(height: 10),
            Container(
              decoration: inset.BoxDecoration(
                color: Color(0xFFF2F8F8),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  inset.BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 2,
                    offset: Offset(2, 2),
                    inset: true,
                  ),
                ],
              ),
              child: TextField(
                controller: confirmPasswordController,
                obscureText: !isConfirmPasswordVisible,
                decoration: InputDecoration(
                  hintText: 'confirm password',
                  hintStyle: TextStyle(color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isConfirmPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        isConfirmPasswordVisible = !isConfirmPasswordVisible;
                      });
                    },
                  ),
                  filled: false,
                  fillColor: Color(0xFFFFFFFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(height: 35),
            Center(
              child: RichText(
                text: TextSpan(
                  text: "Already have an account? ",
                  style: TextStyle(color: Colors.black),
                  children: [
                    TextSpan(
                      text: 'Login here',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (cotext) => LoginPage()),
                          );
                        },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: InkWell(
                onTap: registerCustomer,
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color(0xFF006670),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Center(
                    child: Text(
                      'Register',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFF6FAFB),
                        fontSize: 25,
                        fontFamily: 'JockeyOne',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
