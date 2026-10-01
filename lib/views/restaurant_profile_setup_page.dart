import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:virtual_queue/models/restaurant_brand_model.dart';
import 'package:virtual_queue/models/restaurant_model.dart';
import 'package:virtual_queue/viewmodels/restaurant_profile_setup_viewmodel.dart';
import 'package:virtual_queue/views/restaurant_branch_profile_setup_page.dart';
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart' as inset;

class RestaurantProfileSetupPage extends StatefulWidget {
  final String restaurantId;
  final String restaurantBrandId;
  final List<String> restaurantIds;

  const RestaurantProfileSetupPage({
    super.key,
    required this.restaurantId,
    required this.restaurantBrandId,
    required this.restaurantIds,
  });

  @override
  State<RestaurantProfileSetupPage> createState() =>
      _RestaurantProfileSetupPageState();
}

class _RestaurantProfileSetupPageState extends State<RestaurantProfileSetupPage>{

  final viewmodel = RestaurantProfileSetupViewModel();

  File? logoFile;

  final cuisineController = TextEditingController();
  final aboutController = TextEditingController();

  // Pick Image Functions
  Future<void> pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    setState(() {
      logoFile = File(picked.path);
    });
  }

  bool isBrandSetupComplete(RestaurantBrandModel brand) {
    return brand.cuisine.isNotEmpty &&
        brand.about.isNotEmpty &&
        brand.logoUrl.isNotEmpty;
  }

  bool isBranchSetupComplete(RestaurantModel restaurant) {
    return restaurant.phone.isNotEmpty &&
        restaurant.openingHours.isNotEmpty &&
        restaurant.estimatedTime > 0 &&
        restaurant.imageUrl.isNotEmpty;
  }

  @override
  void dispose() {
    cuisineController.dispose();
    aboutController.dispose();
    super.dispose();
  }

  @override
  Widget build (BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6FAFB),
      appBar: AppBar(
        title: Text(
          'Set Up Profile',
        ),
        backgroundColor: Color(0xFF115E59),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<RestaurantBrandModel>(
              stream: viewmodel.watchRestaurantBrand(widget.restaurantBrandId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                final brand = snapshot.data!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brand.name,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Set up restaurant profile',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (!isBrandSetupComplete(brand))
                      _buildBrandSetupSection()
                    else
                      _buildBranchSetupSection(),

                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBranchCards() {
    return widget.restaurantIds.map((restaurantId) {
      return StreamBuilder<RestaurantModel>(
        stream: viewmodel.watchRestaurantBranch(
          widget.restaurantBrandId,
          restaurantId,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Text(
                'Error loading $restaurantId: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 15),
              child: CircularProgressIndicator(),
            );
          }

          final restaurant = snapshot.data!;

          if (isBranchSetupComplete(restaurant)) {
            return const SizedBox.shrink();
          }

          return _buildBranchCard(
            branchName: restaurant.branchName,
            address: restaurant.address,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RestaurantBranchProfileSetupPage(
                    restaurantId: restaurantId,
                    restaurantBrandId: widget.restaurantBrandId,
                  ),
                ),
              );
            },
          );
        },
      );
    }).toList();
  }

  Widget _buildBrandSetupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Restaurant Logo',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 16),

        GestureDetector(
          onTap: pickLogo,
          child: Container(
            width: double.infinity,
            height: 130,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F8F8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF115E59),
              ),
            ),
            child: logoFile == null
                ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  color: Color(0xFF115E59),
                  size: 40,
                ),
                SizedBox(height: 10),
                Text(
                  'Upload restaurant logo image',
                  style: TextStyle(
                    color: Color(0xFF115E59),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
                : ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.file(
                logoFile!,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'Cuisine Type',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
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
            controller: cuisineController,
            decoration: InputDecoration(
              hintText: 'e.g. Western',
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

        const SizedBox(height: 20),

        Text(
          'About',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        SizedBox(height: 10),
        Container(
          decoration: inset.BoxDecoration(
            color: Color(0xFFF2F8F8),
            borderRadius: BorderRadius.circular(15),
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
            controller: aboutController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Describe your restaurant',
              hintStyle: TextStyle(
                color: Colors.grey,
              ),
              filled: false,
              fillColor: Color(0xFFFFFFFF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF115E59),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              if (logoFile == null ||
                  cuisineController.text.trim().isEmpty ||
                  aboutController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please complete restaurant profile'),
                  ),
                );
                return;
              }

              final success = await viewmodel.saveBrandProfile(
                restaurantBrandId: widget.restaurantBrandId,
                logoFile: logoFile,
                cuisine: cuisineController.text.trim(),
                about: aboutController.text.trim(),
              );

              if (!context.mounted) return;

              if (!success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(viewmodel.errorMessage ?? 'Failed to save restaurant profile'),
                  ),
                );
              }
            },
            child: const Text(
              'Save Restaurant Profile',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBranchCard({
    required String branchName,
    required String address,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storefront,
              color: Color(0xFF115E59),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branchName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  address,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF115E59),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onTap,
            child: const Text(
              'Set Up',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchSetupSection() {
    return StreamBuilder<List<RestaurantModel>>(
      stream: viewmodel.watchRestaurantBranches(
        widget.restaurantBrandId,
        widget.restaurantIds,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final restaurants = snapshot.data!;
        final incompleteBranches = <Widget>[];

        for (int i = 0; i < restaurants.length; i++) {
          final restaurant = restaurants[i];
          final restaurantId = widget.restaurantIds[i];

          if (!isBranchSetupComplete(restaurant)) {
            incompleteBranches.add(
              _buildBranchCard(
                branchName: restaurant.branchName,
                address: restaurant.address,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RestaurantBranchProfileSetupPage(
                        restaurantId: restaurantId,
                        restaurantBrandId: widget.restaurantBrandId,
                      ),
                    ),
                  );
                },
              ),
            );
          }
        }

        if (incompleteBranches.isEmpty) {
          return _buildAllBranchesDone();
        }

        return Column(
          children: incompleteBranches,
        );
      },
    );
  }

  Widget _buildAllBranchesDone() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle,
            color: Color(0xFF115E59),
            size: 56,
          ),
          const SizedBox(height: 16),
          const Text(
            'All branch profiles are complete!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You can go back to your restaurant profile now.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF115E59),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Back to Profile',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}