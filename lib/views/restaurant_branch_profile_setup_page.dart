import 'package:flutter/material.dart';
import 'package:virtual_queue/models/restaurant_model.dart';
import 'package:virtual_queue/viewmodels/restaurant_profile_setup_viewmodel.dart';
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart' as inset;
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class RestaurantBranchProfileSetupPage extends StatefulWidget {
  final String restaurantId;
  final String restaurantBrandId;

  const RestaurantBranchProfileSetupPage({
    super.key,
    required this.restaurantId,
    required this.restaurantBrandId,
  });

  @override
  State<RestaurantBranchProfileSetupPage> createState() =>
      _RestaurantBranchProfileSetupPageState();
}

class _RestaurantBranchProfileSetupPageState extends State<RestaurantBranchProfileSetupPage>{

  final viewmodel = RestaurantProfileSetupViewModel();

  final phoneController = TextEditingController();
  final openingHoursController = TextEditingController();
  final estimatedTimeController = TextEditingController();

  File? restaurantImageFile;

  final days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  final openControllers = <String, TextEditingController>{};
  final closeControllers = <String, TextEditingController>{};
  final isOpenByDay = <String, bool>{};

  @override
  void initState() {
    super.initState();

    for (final day in days) {
      openControllers[day] = TextEditingController();
      closeControllers[day] = TextEditingController();
      isOpenByDay[day] = true;
    }
  }

  Map<String, dynamic> buildOpeningHoursMap() {
    final openingHours = <String, dynamic>{};
    for (final day in days) {
      openingHours[day] = {
        'is_open': isOpenByDay[day] ?? false,
        'open': openControllers[day]?.text.trim() ?? '',
        'close': closeControllers[day]?.text.trim() ?? '',
      };
    }
    return openingHours;
  }

  // opens phone gallery and stores the selected image locally
  Future<void> pickRestaurantImage() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
    );

    if (picked == null) return;

    setState(() {
      restaurantImageFile = File(picked.path);
    });
  }

  bool validateBranchProfile() {
    if (restaurantImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload restaurant image')),
      );
      return false;
    }

    if (phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter phone number')),
      );
      return false;
    }

    if (estimatedTimeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter estimated time')),
      );
      return false;
    }

    for (final day in days) {
      final isOpen = isOpenByDay[day] ?? false;

      if (!isOpen) continue;

      final open = openControllers[day]?.text.trim() ?? '';
      final close = closeControllers[day]?.text.trim() ?? '';

      if (open.isEmpty || close.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter opening hours for $day'),
          ),
        );
        return false;
      }
    }

    return true;
  }

  @override
  void dispose() {
    // Free the text controllers when this page is removed.
    phoneController.dispose();
    openingHoursController.dispose();
    estimatedTimeController.dispose();

    for (final controller in openControllers.values) {
      controller.dispose();
    }

    for (final controller in closeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build (BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6FAFB),
      appBar: AppBar(
        title: Text(
          'Branch Setup'
        ),
        backgroundColor: Color(0xFF115E59),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            StreamBuilder<RestaurantModel>(
              stream: viewmodel.watchRestaurantBranch(
                widget.restaurantBrandId,
                widget.restaurantId,
              ),
              builder: (context, snapshot){
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                if(!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final restaurant = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Restaurant Branch',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    Text(restaurant.branchName),

                    SizedBox(height: 20),
                    Text(
                      'Address',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    Text(restaurant.address),

                    SizedBox(height: 20),
                    
                    Text(
                      'Restaurant Image',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: 10),
                    GestureDetector(
                      onTap: pickRestaurantImage,
                      child: Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Color(0xFFF2F8F8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Color(0xFF115E59),
                            width: 1,
                          )
                        ),
                        child: restaurantImageFile == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Color(0xFF115E59),
                                size: 50,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Upload restaurant image',
                                style: TextStyle(
                                  color: Color(0xFF115E59),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.file(
                            restaurantImageFile!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    Text(
                      'Phone Number',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
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
                        controller: phoneController,
                        decoration: InputDecoration(
                          hintText: '+6012-1234567',
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

                    SizedBox(height: 20),

                    Text(
                      'Opening Hours',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: 10),
                    ...days.map((day) {
                      final isOpen = isOpenByDay[day] ?? false;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 90,
                              child: Text(
                                day[0].toUpperCase() + day.substring(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            Switch(
                              value: isOpen,
                              activeThumbColor: Color(0xFF115E59),
                              onChanged: (value) {
                                setState(() {
                                  isOpenByDay[day] = value;
                                });
                              },
                            ),

                            const SizedBox(width: 20),

                            Expanded(
                              child: TextField(
                                controller: openControllers[day],
                                enabled: isOpen,
                                decoration: InputDecoration(
                                  labelText: 'Open Time',
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: isOpen ? Colors.white : const Color(0xFFE5E7EB),
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: TextField(
                                controller: closeControllers[day],
                                enabled: isOpen,
                                decoration: InputDecoration(
                                  labelText: 'Close Time',
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: isOpen ? Colors.white : const Color(0xFFE5E7EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    SizedBox(height: 20),
                    Text(
                      'Estimated Time (minutes)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
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
                        controller: estimatedTimeController,
                        decoration: InputDecoration(
                          hintText: 'e.g. 10',
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

                    SizedBox(height: 30),

                    Center(
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF115E59),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () async {
                            if (!validateBranchProfile()) return;

                            final openingHours = buildOpeningHoursMap();

                            final success = await viewmodel.saveBranchProfile(
                              restaurantBrandId: widget.restaurantBrandId,
                              restaurantId: widget.restaurantId,
                              imageFile: restaurantImageFile,
                              phone: phoneController.text.trim(),
                              openingHours: openingHours,
                              estimatedTime: int.tryParse(
                                estimatedTimeController.text.trim(),
                              ) ?? 0,
                            );

                            if (!context.mounted) return;

                            if(success){
                              Navigator.pop(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(viewmodel.errorMessage ?? 'Failed to save branch'),
                                ),
                              );
                            }
                          },
                          child: Text(
                            'Save',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
            )
          ],
        ),
      ),
    );
  }
}