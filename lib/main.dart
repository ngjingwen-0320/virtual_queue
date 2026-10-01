import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
// import 'firebase_options.dart';
import 'views/login_page.dart';
// import 'views/restaurant_card_page.dart';
// import 'views/home_page.dart';
// import 'views/customer_home_view.dart';
// import 'views/registration_page.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginPage(),
      },
      home: LoginPage(),
      // home: RestaurantCardPage(),
      // home: CustomerHomeView(),
      // home: RegistrationPage(),
    );
  }
}
