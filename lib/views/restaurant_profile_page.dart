import 'package:flutter/material.dart';
import 'package:virtual_queue/views/restaurant_queue_page.dart';
import 'package:virtual_queue/views/restaurant_reservation_page.dart';
import 'package:virtual_queue/models/restaurant_brand_model.dart';
import 'package:virtual_queue/models/restaurant_model.dart';
import 'package:virtual_queue/views/restaurant_profile_setup_page.dart';
import 'package:virtual_queue/viewmodels/restaurant_profile_viewmodel.dart';
import 'package:virtual_queue/views/login_page.dart';
import 'package:virtual_queue/views/restaurant_profile_edit_page.dart';

class RestaurantProfilePage extends StatefulWidget {
  final String restaurantId;
  final String restaurantBrandId;
  final List<String> restaurantIds;

  const RestaurantProfilePage({
    super.key,
    required this.restaurantId,
    required this.restaurantBrandId,
    required this.restaurantIds,
  });

  @override
  State<RestaurantProfilePage> createState() => _RestaurantProfilePageState();
}

class _RestaurantProfilePageState extends State<RestaurantProfilePage>{

  String _formatOpeningHours(Map<String, dynamic> openingHours) {
    if (openingHours.isEmpty) {
      return 'Opening hours not set';
    }

    final dayLabels = {
      'monday': 'Mon',
      'tuesday': 'Tue',
      'wednesday': 'Wed',
      'thursday': 'Thu',
      'friday': 'Fri',
      'saturday': 'Sat',
      'sunday': 'Sun',
    };

    final lines = <String>[];

    for (final entry in dayLabels.entries) {
      final dayKey = entry.key;
      final dayLabel = entry.value;
      final dayData = openingHours[dayKey];

      if (dayData is! Map) continue;

      final isOpen = dayData['is_open'] == true;
      final open = dayData['open'] ?? '';
      final close = dayData['close'] ?? '';

      if (!isOpen) {
        lines.add('$dayLabel: Closed');
      } else {
        lines.add('$dayLabel: $open - $close');
      }
    }

    if (lines.isEmpty) {
      return 'Opening hours not set';
    }

    return lines.join('\n');
  }

  final viewmodel = RestaurantProfileViewModel();

  late String selectedRestaurantId;

  @override
  void initState() {
    super.initState();
    selectedRestaurantId = widget.restaurantId;
  }

  Future<bool?> _showLogoutConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Logout',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to end your session and sign out?',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF48626E)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build (BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6FAFB),
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
              selectedRestaurantId,
            ),
            builder: (context, restaurantSnapshot) {
              if (!restaurantSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final restaurant = restaurantSnapshot.data!;

              final isProfileSetup =
                brand.cuisine.isNotEmpty &&
                brand.about.isNotEmpty &&
                brand.logoUrl.isNotEmpty &&
                restaurant.phone.isNotEmpty &&
                restaurant.openingHours.isNotEmpty &&
                restaurant.estimatedTime > 0 &&
                restaurant.imageUrl.isNotEmpty;

              // UI for setup profile
              if (!isProfileSetup) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Please set up your profile',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 200,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD5E9EB),
                            foregroundColor: Color(0xFF115E59),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: const BorderSide(color: Color(0xFF115E59), width: 1.5),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RestaurantProfileSetupPage(
                                  restaurantId: selectedRestaurantId,
                                  restaurantBrandId: widget.restaurantBrandId,
                                  restaurantIds: widget.restaurantIds,
                                ),
                              )
                            );
                          },
                          child: const Text(
                            'Set Up Profile',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      SizedBox(
                        width: 200,
                        height: 45,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFF1F2),
                            foregroundColor: Colors.redAccent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: const BorderSide(color: Color(0xFFFECDD3), width: 1.5),
                          ),
                          onPressed: () async {
                            final confirm = await _showLogoutConfirmationDialog();

                            if (confirm != true) return;

                            final success = await viewmodel.logout();

                            if (!context.mounted) return;

                            if (success) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginPage()
                                ),
                                (route) => false,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      viewmodel.errorMessage ?? 'Logout failed'
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.logout_rounded, size: 20),
                          label: const Text(
                            'Logout',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // UI after setup
              return Column(
                children: [
                  SizedBox(
                    height: 330,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Image.network(
                          restaurant.imageUrl,
                          width: double.infinity,
                          height: 330,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFFE5E7EB),
                              child: const Center(
                                child: Icon(Icons.image, size: 50),
                              ),
                            );
                          },
                        ),

                        Positioned(
                          top: 60,
                          right: 25,
                          child: widget.restaurantIds.length > 1
                              ? PopupMenuButton<String>(
                            color: Colors.white,
                            onSelected: (restaurantId){
                              setState(() {
                                selectedRestaurantId = restaurantId;
                              });
                            },
                            itemBuilder: (context){
                              return widget.restaurantIds.map((restaurantId){
                                return PopupMenuItem<String>(
                                  value: restaurantId,
                                  child: StreamBuilder<RestaurantModel>(
                                    stream: viewmodel.watchRestaurantBranch(
                                      widget.restaurantBrandId,
                                      restaurantId,
                                    ),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData){
                                        return Text(restaurantId);
                                      }
                                      final restaurant = snapshot.data!;

                                      return Text(restaurant.branchName);
                                    },
                                  ),
                                );
                              }).toList();
                            },
                            child: Container(
                              height: 30,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Color(0xFFF0F4F5),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${widget.restaurantIds.length} branch',
                                    style: const TextStyle(
                                      color: Color(0xFF006670),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Color(0xFF006670),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          )
                              : Container(
                            height: 30,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Color(0xFFF0F4F5),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 4,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '${widget.restaurantIds.length} branch',
                                style: const TextStyle(
                                  color: Color(0xFF006670),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),

                        Positioned(
                          right: 25,
                          bottom: 40,
                          child: InkWell(
                            onTap: (){
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RestaurantProfileEditPage(
                                    restaurantBrandId: widget.restaurantBrandId,
                                    restaurantId: selectedRestaurantId
                                  ),
                                ),
                              );
                            },
                            child: CircleAvatar(
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.edit,
                                color: Color(0xFF006670),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -20),
                      child: SingleChildScrollView(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(bottom: 30, top: 40, left: 25, right: 25),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF6FAFB),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 105,
                                    height: 105,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned(
                                          left: 0,
                                          top: 0,
                                          child: Container(
                                            width: 95,
                                            height: 95,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(14),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.12),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: Image.network(
                                              brand.logoUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return const Icon(
                                                  Icons.restaurant,
                                                  color: Color(0xFF006670),
                                                  size: 40,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                            
                                  const SizedBox(width: 25),
                                            
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${brand.name} •\n${restaurant.branchName}',
                                          style: const TextStyle(
                                            fontSize: 23,
                                            fontWeight: FontWeight.bold,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          brand.cuisine,
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                                            
                              const SizedBox(height: 30),
                                            
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.access_time, size: 20),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(_formatOpeningHours(restaurant.openingHours)),
                                  ),
                                ],
                              ),
                                            
                              const SizedBox(height: 20),
                                            
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 20),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(restaurant.address),
                                  ),
                                ],
                              ),
                                            
                              const SizedBox(height: 20),
                                            
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined, size: 20),
                                  const SizedBox(width: 16),
                                  Text(restaurant.phone),
                                ],
                              ),
                                            
                              const SizedBox(height: 25),
                                            
                              const Text(
                                'About',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                                            
                              const SizedBox(height: 10),
                                            
                              Text(
                                brand.about,
                                style: const TextStyle(
                                  color: Color(0xFF4B5563),
                                  height: 1.5,
                                ),
                              ),
                                            
                              const SizedBox(height: 25),
                                            
                              const Text(
                                'Estimated time per table',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                                            
                              const SizedBox(height: 10),
                                            
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Text('${restaurant.estimatedTime} minutes'),
                              ),
                                            
                              const SizedBox(height: 30),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFF1F2),
                                    foregroundColor: Colors.redAccent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    side: const BorderSide(color: Color(0xFFFECDD3), width: 1.5),
                                  ),
                                  onPressed: () async {
                                    final confirm = await _showLogoutConfirmationDialog();

                                    if (confirm != true) return;

                                    final success = await viewmodel.logout();

                                    if (!context.mounted) return;

                                    if (success) {
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => const LoginPage()
                                        ),
                                            (route) => false,
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              viewmodel.errorMessage ?? 'Logout failed'
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.logout_rounded, size: 20),
                                  label: const Text(
                                    'Logout',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: Container(
        height: 100,
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBottomNavItem(
              icon: Icons.room_service_outlined,
              label: 'Reservation',
              isActive: false,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RestaurantReservationPage(
                      restaurantBrandId: widget.restaurantBrandId,
                      restaurantId: selectedRestaurantId,
                      restaurantIds: widget.restaurantIds,
                    ),
                  ),
                );
              },
            ),
            _buildBottomNavItem(
              icon: Icons.hourglass_empty,
              label: 'Queue',
              isActive: false,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RestaurantQueuePage(
                      restaurantBrandId: widget.restaurantBrandId,
                      restaurantId: selectedRestaurantId,
                      restaurantIds: widget.restaurantIds,
                    ),
                  ),
                );
              },
            ),
            _buildBottomNavItem(
              icon: Icons.person_outline,
              label: 'Profile',
              isActive: true,
              onTap: (){},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        height: 60,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF0FDFA) : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 26,
              color: isActive ? const Color(0xFF115E59) : const Color(0xFF64748B),
            ),
            const SizedBox(height: 2),
            Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isActive ? const Color(0xFF115E59) : const Color(0xFF64748B),
                )
            ),
          ],
        ),
      ),
    );
  }
}
