import 'package:flutter/material.dart';
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart' as inset;
import 'package:virtual_queue/views/home_page.dart';
import 'package:virtual_queue/viewmodels/login_viewmodel.dart';
import 'package:virtual_queue/views/registration_page.dart';
import 'package:virtual_queue/views/restaurant_card_page.dart';
import 'package:virtual_queue/views/restaurant_queue_page.dart';
import 'package:flutter/gestures.dart';
import 'package:virtual_queue/views/customer_home_view.dart';

class LoginPage extends StatefulWidget{
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() =>  _LoginPageState();
}

class _LoginPageState  extends State<LoginPage>{
  final viewModel = LoginViewModel();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isPasswordVisible = false;

  Future<void> login() async {
    final profile = await viewModel.login(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    if (!mounted) return;

    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(viewModel.errorMessage ?? 'Login failed')),
      );
      return;
    }

    if (profile.isRestaurant) {
      final restaurantId = profile.firstRestaurantId;
      final restaurantBrandId = profile.restaurantBrandId;

      if (restaurantId == null || restaurantBrandId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restaurant profile not found')),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RestaurantQueuePage(
                restaurantBrandId: restaurantBrandId,
                restaurantId: restaurantId,
                restaurantIds: profile.restaurantIds,
              ),
        ),
      );
    } else if (profile.isCustomer) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => CustomerHomeView(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6FAFB),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0,-1.7),
            radius: 1.5,
            colors: [
              Color(0xFF028390),
              Color(0xFFF6FAFB),
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: SafeArea(
            child: Container(
              margin: EdgeInsets.only(bottom: 50),
              child: Column(
                children: [
                  SizedBox(height: 100),
                  Text(
                    'VirtualQueue',
                    style: TextStyle(
                      fontFamily: 'Kavoon',
                      color: Color(0xFF006670),
                      fontSize: 35,
                    ),
                  ),
                  SizedBox(height: 100),
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Color(0xFFF0F4F5),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 20,
                          offset: Offset(-2, -2),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 20,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height:30),
                        Center(
                          child: Text(
                            'Login Now',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                          ),
                        ),
                        SizedBox(height:35),
                        Text(
                          'Email',
                          style: TextStyle(
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height:10),
                        Container(
                          decoration: inset.BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              inset.BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 2,
                                offset: Offset(0, 2),
                                inset: true,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'example@gmail.com',
                              hintStyle: TextStyle(
                                color: Colors.grey,
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
                        SizedBox(height:30),
                        Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height:10),
                        Container(
                          decoration: inset.BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              inset.BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 2,
                                offset: Offset(0, 2),
                                inset: true,
                              )
                            ]
                          ),
                          child: TextField(
                            controller: passwordController,
                            obscureText: !isPasswordVisible,
                            decoration: InputDecoration(
                              hintText: 'password',
                              hintStyle: TextStyle(
                                color: Colors.grey,
                              ),
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
                        SizedBox(height:30),
                        Center(
                          child: RichText(
                            text: TextSpan(
                              text: "No yet have an account? ",
                              style: TextStyle(
                                color: Colors.black,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Register here',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (cotext) => RegistrationPage(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height:20),
                        Center(
                          child: InkWell(
                            onTap: login,
                            child: Container(
                              width: 180,
                              height: 65,
                              decoration: BoxDecoration(
                                color: Color(0xFF006670),
                                borderRadius: BorderRadius.circular(30),
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
                                  'Login',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFFF6FAFB),
                                    fontSize: 30,
                                    fontFamily: 'JockeyOne',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height:5),
                        Center(
                          child: TextButton(
                            onPressed: () async {
                              final success = await viewModel.resetPassword(
                                emailController.text.trim(),
                              );

                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'Password reset email sent'
                                        : viewModel.errorMessage ?? 'Failed to send reset email',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Forgot Password?'),
                          ),
                        ),
                        SizedBox(height:20),
                      ],
                    )
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}