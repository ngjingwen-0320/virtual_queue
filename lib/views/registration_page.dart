import 'package:flutter/material.dart';
import 'package:virtual_queue/views/customer_register_page.dart';
import 'package:virtual_queue/views/restaurant_register_page.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // 2 tabs
      child: Scaffold(
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
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: (){
                            Navigator.pop(context);
                          },
                          icon: Icon(Icons.arrow_back),
                        ),
                      ),
                      Text(
                        'VQ',
                        style: TextStyle(
                          fontFamily: 'Kavoon',
                          color: Color(0xFF028390),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  labelColor: Color(0xFF028390),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Color(0xFF028390),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontWeight: null,
                    fontSize: 18,
                  ),
                  tabs: [
                    Tab(text: 'Customer'),
                    Tab(text: 'Restaurant')
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Center(
                      //   child: Text('Customer Register Page'),
                      // ),
                      // Center(
                      //   child: Text('Restaurant Owner Register Page'),
                      // ),
                      CustomerRegisterPage(),
                      RestaurantRegisterPage(),
                    ],
                  )
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}