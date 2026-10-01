import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart' as inset;
import 'package:image_picker/image_picker.dart';
import 'package:virtual_queue/models/restaurant_brand_model.dart';
import 'package:virtual_queue/models/restaurant_model.dart';
import 'package:virtual_queue/viewmodels/restaurant_profile_setup_viewmodel.dart';

class RestaurantProfileEditPage extends StatefulWidget {
  final String restaurantBrandId;
  final String restaurantId;

  const RestaurantProfileEditPage({
    super.key,
    required this.restaurantBrandId,
    required this.restaurantId,
  });

  @override
  State<RestaurantProfileEditPage> createState() =>
      _RestaurantProfileEditPageState();
}

class _RestaurantProfileEditPageState extends State<RestaurantProfileEditPage> {
  final viewmodel = RestaurantProfileSetupViewModel();

  final cuisineController = TextEditingController();
  final aboutController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final estimatedTimeController = TextEditingController();

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

  File? logoFile;
  File? restaurantImageFile;
  bool hasLoadedData = false;

  @override
  void initState() {
    super.initState();

    for (final day in days) {
      openControllers[day] = TextEditingController();
      closeControllers[day] = TextEditingController();
      isOpenByDay[day] = true;
    }
  }

  @override
  void dispose() {
    cuisineController.dispose();
    aboutController.dispose();
    addressController.dispose();
    phoneController.dispose();
    estimatedTimeController.dispose();

    for (final controller in openControllers.values) {
      controller.dispose();
    }

    for (final controller in closeControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  void loadExistingData(
    RestaurantBrandModel brand,
    RestaurantModel restaurant,
  ) {
    if (hasLoadedData && addressController.text.isNotEmpty) return;

    cuisineController.text = brand.cuisine;
    aboutController.text = brand.about;
    addressController.text = restaurant.address;
    phoneController.text = restaurant.phone;
    estimatedTimeController.text = restaurant.estimatedTime.toString();

    for (final day in days) {
      final dayData = restaurant.openingHours[day];

      if (dayData is Map) {
        isOpenByDay[day] = dayData['is_open'] == true;
        openControllers[day]?.text = dayData['open'] ?? '';
        closeControllers[day]?.text = dayData['close'] ?? '';
      }
    }

    hasLoadedData = true;
  }

  Future<void> pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      logoFile = File(picked.path);
    });
  }

  Future<void> pickRestaurantImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      restaurantImageFile = File(picked.path);
    });
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

  bool validateProfile(RestaurantBrandModel brand, RestaurantModel restaurant) {
    if (cuisineController.text.trim().isEmpty ||
        aboutController.text.trim().isEmpty ||
        addressController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        estimatedTimeController.text.trim().isEmpty) {
      showMessage('Please fill in all required fields');
      return false;
    }

    if (brand.logoUrl.isEmpty && logoFile == null) {
      showMessage('Please upload restaurant logo');
      return false;
    }

    if (restaurant.imageUrl.isEmpty && restaurantImageFile == null) {
      showMessage('Please upload branch image');
      return false;
    }

    for (final day in days) {
      final isOpen = isOpenByDay[day] ?? false;
      if (!isOpen) continue;

      final open = openControllers[day]?.text.trim() ?? '';
      final close = closeControllers[day]?.text.trim() ?? '';

      if (open.isEmpty || close.isEmpty) {
        showMessage('Please enter opening hours for $day');
        return false;
      }
    }

    return true;
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> saveChanges(
    RestaurantBrandModel brand,
    RestaurantModel restaurant,
  ) async {
    if (!validateProfile(brand, restaurant)) return;

    final brandSuccess = await viewmodel.saveBrandProfile(
      restaurantBrandId: widget.restaurantBrandId,
      logoFile: logoFile,
      cuisine: cuisineController.text.trim(),
      about: aboutController.text.trim(),
    );

    final branchSuccess = await viewmodel.saveBranchProfile(
      restaurantBrandId: widget.restaurantBrandId,
      restaurantId: widget.restaurantId,
      imageFile: restaurantImageFile,
      address: addressController.text.trim(),
      phone: phoneController.text.trim(),
      openingHours: buildOpeningHoursMap(),
      estimatedTime: int.tryParse(estimatedTimeController.text.trim()) ?? 0,
    );

    if (!mounted) return;

    if (brandSuccess && branchSuccess) {
      Navigator.pop(context);
    } else {
      showMessage(viewmodel.errorMessage ?? 'Failed to update profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFB),
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF006670),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<RestaurantBrandModel>(
        stream: viewmodel.watchRestaurantBrand(widget.restaurantBrandId),
        builder: (context, brandSnapshot) {
          if (!brandSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final brand = brandSnapshot.data!;

          return StreamBuilder<RestaurantModel>(
            stream: viewmodel.watchRestaurantBranch(
              widget.restaurantBrandId,
              widget.restaurantId,
            ),
            builder: (context, restaurantSnapshot) {
              if (!restaurantSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final restaurant = restaurantSnapshot.data!;
              loadExistingData(brand, restaurant);

              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildImageHeader(restaurant),
                    Transform.translate(
                      offset: const Offset(0, -22),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            _buildBrandCard(brand),
                            const SizedBox(height: 18),
                            _buildBranchCard(restaurant),
                            const SizedBox(height: 24),
                            _buildSaveButton(brand, restaurant),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildImageHeader(RestaurantModel restaurant) {
    return GestureDetector(
      onTap: pickRestaurantImage,
      child: SizedBox(
        height: 230,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildImagePreview(
              localFile: restaurantImageFile,
              imageUrl: restaurant.imageUrl,
              icon: Icons.image,
              borderRadius: BorderRadius.zero,
            ),
            Container(
              color: Colors.black.withValues(alpha: 0.18),
            ),
            Positioned(
              right: 20,
              bottom: 34,
              child: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.camera_alt,
                  color: Color(0xFF006670),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandCard(RestaurantBrandModel brand) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: pickLogo,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildImagePreview(
                        localFile: logoFile,
                        imageUrl: brand.logoUrl,
                        icon: Icons.restaurant,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    const Positioned(
                      right: -5,
                      bottom: -5,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: Color(0xFF006670),
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brand.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Restaurant details',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _buildLabel('Cuisine Type'),
          _buildTextInput(
            controller: cuisineController,
            hintText: 'e.g. Nanyang Cuisine',
          ),
          const SizedBox(height: 18),
          _buildLabel('About'),
          _buildTextInput(
            controller: aboutController,
            hintText: 'Describe your restaurant',
            maxLines: 5,
            borderRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildBranchCard(RestaurantModel restaurant) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20, top: 30),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Branch: ${restaurant.branchName}',
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 22),
          _buildLabel('Address'),
          _buildTextInput(
            controller: addressController,
            hintText: 'Branch address',
            maxLines: 3,
            borderRadius: 18,
          ),
          const SizedBox(height: 18),
          _buildLabel('Phone'),
          _buildTextInput(
            controller: phoneController,
            hintText: '+04-10263288',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 18),
          _buildLabel('Estimated time per table'),
          _buildTextInput(
            controller: estimatedTimeController,
            hintText: '30 minutes',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          _buildLabel('Opening Hours'),
          const SizedBox(height: 10),
          ...days.map(_buildOpeningHourRow),
        ],
      ),
    );
  }

  Widget _buildOpeningHourRow(String day) {
    final isOpen = isOpenByDay[day] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDay(day),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Switch(
                value: isOpen,
                activeThumbColor: const Color(0xFF006670),
                onChanged: (value) {
                  setState(() {
                    isOpenByDay[day] = value;
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTimeInput(
                  controller: openControllers[day]!,
                  hintText: '09:00',
                  enabled: isOpen,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '-',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: _buildTimeInput(
                  controller: closeControllers[day]!,
                  hintText: '21:30',
                  enabled: isOpen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(RestaurantBrandModel brand, RestaurantModel restaurant) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF006670),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () => saveChanges(brand, restaurant),
        child: const Text(
          'Save Changes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    double borderRadius = 40,
  }) {
    return Container(
      decoration: inset.BoxDecoration(
        color: const Color(0xFFF2F8F8),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          inset.BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 2,
            offset: const Offset(2, 2),
            inset: true,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInput({
    required TextEditingController controller,
    required String hintText,
    required bool enabled,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.datetime,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFE5E7EB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildImagePreview({
    required File? localFile,
    required String imageUrl,
    required IconData icon,
    required BorderRadius borderRadius,
  }) {
    if (localFile != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.file(
          localFile,
          fit: BoxFit.cover,
        ),
      );
    }

    if (imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildImagePlaceholder(icon);
          },
        ),
      );
    }

    return _buildImagePlaceholder(icon);
  }

  Widget _buildImagePlaceholder(IconData icon) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Icon(
          icon,
          color: const Color(0xFF006670),
          size: 40,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  String _formatDay(String day) {
    return day.substring(0, 1).toUpperCase() + day.substring(1);
  }
}
