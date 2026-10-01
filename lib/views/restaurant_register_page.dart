import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart' as inset;
import 'package:flutter/gestures.dart';
import 'package:virtual_queue/viewmodels/register_viewmodel.dart';
import 'package:virtual_queue/views/login_page.dart';

class RestaurantRegisterPage extends StatefulWidget {
  const RestaurantRegisterPage({super.key});

  @override
  State<RestaurantRegisterPage> createState() => _RestaurantRegisterPageState();
}

class _RestaurantRegisterPageState extends State<RestaurantRegisterPage> {

  int currentStep = 1;

  final branchCountController = TextEditingController(text: '1');

  bool hasMultipleBranches = false;
  int branchCount = 1;

  final viewModel = RegisterViewmodel();

  final restaurantNameController = TextEditingController();
  final restaurantAddressController = TextEditingController();
  final restaurantAreaController = TextEditingController();
  final businessRegistrationNoController = TextEditingController();

  final ownerNameController = TextEditingController();
  final ownerEmailController = TextEditingController();
  final ownerPhoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  final branchNameControllers = <TextEditingController>[];
  final branchAddressControllers = <TextEditingController>[];

  void syncBranchControllers() {
    while (branchNameControllers.length < branchCount) {
      branchNameControllers.add(TextEditingController());
      branchAddressControllers.add(TextEditingController());
    }

    while (branchNameControllers.length > branchCount) {
      branchNameControllers.removeLast().dispose();
      branchAddressControllers.removeLast().dispose();
    }
  }

  Future<void> registerRestaurant() async {
    final branches = <Map<String, String>>[];

    if (branchCount == 1) {
      branches.add({
        'branch_name': restaurantAreaController.text.trim(),
        'address': restaurantAddressController.text.trim(),
      });
    } else {
      for (int i = 0; i < branchCount; i++){
        branches.add({
          'branch_name': branchNameControllers[i].text.trim(),
          'address': branchAddressControllers[i].text.trim(),
        });
      }
    }

    final profile = await viewModel.registerRestaurant(
      restaurantName: restaurantNameController.text.trim(),
      businessRegistrationNo: businessRegistrationNoController.text.trim(),
      ownerName: ownerNameController.text.trim(),
      ownerEmail: ownerEmailController.text.trim(),
      ownerPhone: ownerPhoneController.text.trim(),
      password: passwordController.text.trim(),
      confirmPassword: confirmPasswordController.text.trim(),
      branches: branches,
    );

    if (!mounted) return;

    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(viewModel.errorMessage ?? 'Registration failed')),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginPage(),
      ),
    );
  }

  @override
  void dispose() {
    branchCountController.dispose();
    restaurantNameController.dispose();
    restaurantAddressController.dispose();
    restaurantAreaController.dispose();
    businessRegistrationNoController.dispose();
    ownerNameController.dispose();
    ownerEmailController.dispose();
    ownerPhoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    for (final controller in branchNameControllers) {
      controller.dispose();
    }

    for (final controller in branchAddressControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void updateBranchForms(String value) {
    setState(() {
      if (value.isEmpty) {
        branchCount = 0;
        syncBranchControllers();
        return;
      }

      branchCount = int.tryParse(value) ?? 0;

      if (branchCount < 1) {
        branchCount = 0;
      }

      syncBranchControllers();
    });
  }

  @override
  Widget build (BuildContext context) {
    return Container(
      color: Color(0xFFF8FDFD),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Register as Restaurant',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),

            buildStepIndicator(),

            SizedBox(height: 20),

            if (currentStep == 1) restaurantDetailsForm(),
            if (currentStep == 2) ownerDetailsForm(),
          ],
        ),
      )
    );
  }

  Widget buildStepIndicator() {
    return Row(
      children: [
        buildStepCircle(1),
        buildStepLine(),
        buildStepCircle(2),
      ],
    );
  }

  Widget buildStepCircle(int step) {
    final bool isActive = currentStep >= step;

    return CircleAvatar(
      radius: 18,
      backgroundColor: isActive ? const Color(0xFF006670) : Color(0xFFDFDFDF),
      child: Text(
        step.toString(),
        style: TextStyle(
          color: isActive? Colors.white : Colors.black54,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildStepLine() {
    final bool isActive = currentStep == 2;

    return Expanded(
      child: Container(
        height: 5,
        color: isActive ? const Color(0xFF006670) : Color(0xFFDFDFDF),
      ),
    );
  }

  Widget restaurantDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        SizedBox(height: 10),

        Text(
          '1. RESTAURANT DETAILS',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight(600),
            color: Color(0xFF006670),
            decoration: TextDecoration.underline,
          ),
        ),

        SizedBox(height: 20),

        buildLabel('Number of Branches'),

        SizedBox(height:10),

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
            controller: branchCountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: updateBranchForms,
            decoration: InputDecoration(
              hintText: 'e.g. 1',
              hintStyle: TextStyle(
                color: Colors.grey,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(40),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        if (branchCount > 0) ...[
          SizedBox(height: 20),

          buildLabel('Restaurant Name'),
          buildTextField(
            'ABC Restaurant',
            controller: restaurantNameController,
          ),

          if (branchCount == 1) singleAddressField(),
          if (branchCount > 1) multipleBranchField(),

          buildLabel('Business Registration Number'),
          buildTextField(
            'xxxxxxxxxxxx',
            controller: businessRegistrationNoController,
          ),

          SizedBox(height: 20),

          Center(
            child: InkWell(
              onTap: () {
                setState(() {
                  currentStep = 2;
                });
              },
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
                child: Center(
                  child: Text(
                    'Next',
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
      ],
    );
  }

  Widget singleAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLabel('Address'),
        buildTextField(
          'No.0, Street Rainbow, ...',
          controller: restaurantAddressController,
        ),
        buildLabel('Branch/Area Name'),
        buildTextField(
          'e.g. Georgetown',
          controller: restaurantAreaController,
        ),
      ],
    );
  }

  Widget multipleBranchField() {
    return Column(
      children: [
        ...List.generate(branchCount, (index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Text(
                'Branch ${index + 1} Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  color: Color(0xFF006670),
                ),
              ),

              SizedBox(height: 10),

              buildLabel('Branch Name'),
              buildTextField(
                'e.g. Queensbay Mall',
                controller: branchNameControllers[index],
              ),

              buildLabel('Branch Address'),
              buildTextField(
                'No.0, Street Rainbow, ...',
                maxLines: 3,
                controller: branchAddressControllers[index],
              ),

              SizedBox(height: 10),
            ],
          );
        }),
        SizedBox(height: 20),
      ],
    );
  }

  Widget ownerDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        SizedBox(height: 10),

        Text(
          '2. RESTAURANT OWNER DETAILS',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight(600),
            color: Color(0xFF006670),
            decoration: TextDecoration.underline,
          ),
        ),

        SizedBox(height: 20),

        buildLabel('Owner Name'),
        buildTextField(
          'John Doe',
          controller: ownerNameController,
        ),

        buildLabel('Owner Email'),
        buildTextField(
          'example@gmail.com',
          controller: ownerEmailController,
        ),

        buildLabel('Phone Number'),
        buildTextField(
          '+60XX-XXXXXXX',
          controller: ownerPhoneController,
        ),

        buildLabel('Password'),
        buildTextField(
          'password',
          obscureText: !isPasswordVisible,
          controller: passwordController,
          suffixIcon: IconButton(
            icon: Icon(
              isPasswordVisible ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: () {
              setState(() {
                isPasswordVisible = !isPasswordVisible;
              });
            },
          ),
        ),

        buildLabel('Password'),
        buildTextField(
          'confirm password',
          obscureText: !isConfirmPasswordVisible,
          controller: confirmPasswordController,
          suffixIcon: IconButton(
            icon: Icon(
              isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: () {
              setState(() {
                isConfirmPasswordVisible = !isConfirmPasswordVisible;
              });
            },
          ),
        ),

        SizedBox(height: 20),

        Center(
          child: RichText(
            text: TextSpan(
              text: "Already have an account? ",
              style: TextStyle(
                color: Colors.black,
              ),
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
                        MaterialPageRoute(
                          builder: (cotext) => LoginPage(),
                        ),
                      );
                    },
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 30),

        Row(
          children: [

            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    currentStep = 1;
                  });
                },
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color(0xFFA4AEB1),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Previous',
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

            SizedBox(width: 20),

            Expanded(
              child: InkWell(
                onTap: registerRestaurant,
                child: Container(
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
                  child: Center(
                    child: Text(
                      'Register',
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
      ],
    );
  }

  Widget buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight(550),
      ),
    );
  }

  Widget buildTextField(
      String hintText, {
      TextEditingController? controller,
      bool obscureText = false,
      int maxLines = 1,
      Widget? suffixIcon,
  }) {
    final double radius = maxLines > 1 ? 25 : 40;

    return Column(
      children: [
        SizedBox(height: 10),
        Container(
          decoration: inset.BoxDecoration(
            color: Color(0xFFF2F8F8),
            borderRadius: BorderRadius.circular(radius),
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
            controller: controller,
            obscureText: obscureText,
            maxLines: obscureText ? 1 : maxLines,
            decoration: InputDecoration(
              hintText: hintText,
              suffixIcon: suffixIcon,
              hintStyle: TextStyle(
                color: Colors.grey,
              ),
              filled: false,
              fillColor: Color(0xFFFFFFFF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }

}