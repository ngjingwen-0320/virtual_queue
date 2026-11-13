import '../utils/phone_number_utils.dart';
import 'package:flutter/material.dart';

import 'package:virtual_queue/views/restaurant_queue_page.dart';
import 'package:virtual_queue/views/restaurant_reservation_page.dart';
import 'package:virtual_queue/models/restaurant_brand_model.dart';
import 'package:virtual_queue/models/restaurant_model.dart';
import 'package:virtual_queue/views/restaurant_profile_setup_page.dart';
import 'package:virtual_queue/viewmodels/restaurant_profile_viewmodel.dart';
import 'package:virtual_queue/views/login_page.dart';
import 'package:virtual_queue/views/restaurant_profile_edit_page.dart';
import 'package:virtual_queue/views/restaurant_mockpay_setup_page.dart';
import 'package:virtual_queue/services/mockpay_service.dart';

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

class _RestaurantProfilePageState extends State<RestaurantProfilePage> {
  final viewmodel = RestaurantProfileViewModel();

  final MockPayService _mockPayService = MockPayService();

  late String selectedRestaurantId;

  late Future<Map<String, dynamic>> _merchantStatusFuture;

  static const Color primaryColor = Color(0xFF006670);
  static const Color darkTeal = Color(0xFF115E59);
  static const Color pageBackground = Color(0xFFF6FAFB);

  @override
  void initState() {
    super.initState();

    selectedRestaurantId = widget.restaurantId;

    _merchantStatusFuture = _mockPayService.getMerchantStatus();
  }

  // ========================================
  // REFRESH MOCKPAY STATUS
  // ========================================

  void _refreshMerchantStatus() {
    if (!mounted) return;

    setState(() {
      _merchantStatusFuture = _mockPayService.getMerchantStatus();
    });
  }

  // ========================================
  // OPEN MOCKPAY REGISTRATION
  // ========================================

  Future<void> _openMockPaySetup(String brandName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantMockPaySetupPage(
          brandId: widget.restaurantBrandId,
          restaurantName: brandName,
        ),
      ),
    );

    if (!mounted) return;

    _refreshMerchantStatus();
  }

  // ========================================
  // MOCKPAY MERCHANT DETAILS
  // ========================================

  Future<void> _showMerchantDetails(Map<String, dynamic> merchant) async {
    final merchantId = merchant['merchantId']?.toString() ?? '-';

    final businessName = merchant['businessName']?.toString() ?? '-';

    final status = merchant['status']?.toString() ?? 'unknown';

    final bankName = merchant['bankName']?.toString() ?? '-';

    final accountLast4 = merchant['accountLast4']?.toString() ?? '-';

    final paymentEnabled = merchant['paymentEnabled'] == true;

    final verified = merchant['verified'] == true;

    final rawBalance = merchant['balanceCents'];
    final balanceCents = rawBalance is num ? rawBalance.toInt() : 0;

    final balance = (balanceCents / 100).toStringAsFixed(2);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: primaryColor),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'MockPay Account',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Business', businessName),

                const SizedBox(height: 14),

                _detailRow('Merchant ID', merchantId),

                const SizedBox(height: 14),

                _detailRow('Status', status.toUpperCase()),

                const SizedBox(height: 14),

                _detailRow('Bank', bankName),

                const SizedBox(height: 14),

                _detailRow('Account Number', '****$accountLast4'),

                const SizedBox(height: 14),

                _detailRow('Bank Verified', verified ? 'Yes' : 'No'),

                const SizedBox(height: 14),

                _detailRow('Payments Enabled', paymentEnabled ? 'Yes' : 'No'),

                const Divider(height: 30),

                _detailRow('Simulated Balance', 'RM $balance'),

                const SizedBox(height: 12),

                const Text(
                  'MockPay is a simulated payment gateway. '
                  'The displayed balance does not represent '
                  'real money.',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (mounted) {
      _refreshMerchantStatus();
    }
  }

  Widget _detailRow(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 12,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 5),
        SelectableText(
          value,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF171C1D),
          ),
        ),
      ],
    );
  }

  // ========================================
  // MOCKPAY STATUS BUTTON
  // ========================================

  Widget _buildMockPayButton(String brandName) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _merchantStatusFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;

        final hasError = snapshot.hasError;
        final data = snapshot.data;

        final registered = data?['registered'] == true;

        final status = (data?['status'] ?? 'not_registered')
            .toString()
            .toLowerCase();

        final isActive =
            registered &&
            status == 'active' &&
            data?['verified'] == true &&
            data?['paymentEnabled'] == true;

        final isPending = registered && status == 'pending';

        String title;
        String description;
        IconData icon;
        Color color;

        if (loading) {
          title = 'Checking MockPay...';
          description = 'Checking merchant account status';
          icon = Icons.hourglass_top_rounded;
          color = const Color(0xFF64748B);
        } else if (hasError || data == null) {
          title = 'Retry MockPay Status';
          description = 'Unable to retrieve account status';
          icon = Icons.refresh_rounded;
          color = const Color(0xFF64748B);
        } else if (isActive) {
          title = 'Manage MockPay';
          description = 'Active - Payments Enabled';
          icon = Icons.verified_rounded;
          color = primaryColor;
        } else if (isPending) {
          title = 'MockPay Pending';
          description = 'Awaiting Activation';
          icon = Icons.schedule_rounded;
          color = const Color(0xFFD97706);
        } else if (registered) {
          title = 'View MockPay Status';
          description = status.toUpperCase();
          icon = Icons.info_outline_rounded;
          color = const Color(0xFF64748B);
        } else {
          title = 'Set Up MockPay';
          description = 'Not Registered';
          icon = Icons.account_balance_wallet_outlined;
          color = primaryColor;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MockPay Merchant Account',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Icon(
                  isActive
                      ? Icons.check_circle_rounded
                      : isPending
                      ? Icons.schedule_rounded
                      : loading
                      ? Icons.hourglass_top
                      : Icons.info_outline,
                  color: isActive
                      ? const Color(0xFF16A34A)
                      : isPending
                      ? const Color(0xFFD97706)
                      : const Color(0xFF64748B),
                  size: 18,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF48626E),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: loading
                    ? null
                    : () async {
                        if (hasError || data == null) {
                          _refreshMerchantStatus();
                          return;
                        }

                        if (registered) {
                          await _showMerchantDetails(data);
                        } else {
                          await _openMockPaySetup(brandName);
                        }
                      },
                icon: Icon(icon, size: 22),
                label: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ========================================
  // FORMAT OPENING HOURS
  // ========================================

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
      final dayData = openingHours[entry.key];

      if (dayData is! Map) continue;

      final isOpen = dayData['is_open'] == true;
      final open = dayData['open'] ?? '';
      final close = dayData['close'] ?? '';

      if (!isOpen) {
        lines.add('${entry.value}: Closed');
      } else {
        lines.add('${entry.value}: $open - $close');
      }
    }

    return lines.isEmpty ? 'Opening hours not set' : lines.join('\n');
  }

  // ========================================
  // LOGOUT CONFIRMATION
  // ========================================

  Future<bool?> _showLogoutConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Logout',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to end your session '
          'and sign out?',
          style: TextStyle(fontFamily: 'Plus Jakarta Sans'),
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

  Future<void> _logout() async {
    final confirmed = await _showLogoutConfirmationDialog();

    if (confirmed != true) return;

    final success = await viewmodel.logout();

    if (!mounted) return;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(viewmodel.errorMessage ?? 'Logout failed')),
      );
    }
  }

  // ========================================
  // PROFILE SETUP
  // ========================================

  Widget _buildProfileSetup() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Please set up your profile',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: 200,
            height: 45,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD5E9EB),
                foregroundColor: darkTeal,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: const BorderSide(color: darkTeal, width: 1.5),
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
                  ),
                );
              },
              child: const Text(
                'Set Up Profile',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: 200,
            height: 45,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF1F2),
                foregroundColor: Colors.redAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // RESTAURANT PROFILE HEADER
  // ========================================

  Widget _buildHeader(RestaurantModel restaurant) {
    return SizedBox(
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
                child: const Center(child: Icon(Icons.image, size: 50)),
              );
            },
          ),

          // Branch selector
          Positioned(
            top: 60,
            right: 25,
            child: widget.restaurantIds.length > 1
                ? PopupMenuButton<String>(
                    color: Colors.white,
                    onSelected: (restaurantId) {
                      setState(() {
                        selectedRestaurantId = restaurantId;
                      });
                    },
                    itemBuilder: (context) {
                      return widget.restaurantIds.map((restaurantId) {
                        return PopupMenuItem<String>(
                          value: restaurantId,
                          child: StreamBuilder<RestaurantModel>(
                            stream: viewmodel.watchRestaurantBranch(
                              widget.restaurantBrandId,
                              restaurantId,
                            ),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Text(restaurantId);
                              }

                              return Text(snapshot.data!.branchName);
                            },
                          ),
                        );
                      }).toList();
                    },
                    child: _branchBadge(
                      '${widget.restaurantIds.length} branch',
                      showArrow: true,
                    ),
                  )
                : _branchBadge('${widget.restaurantIds.length} branch'),
          ),

          // Edit profile button
          Positioned(
            right: 25,
            bottom: 40,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RestaurantProfileEditPage(
                      restaurantBrandId: widget.restaurantBrandId,
                      restaurantId: selectedRestaurantId,
                    ),
                  ),
                );
              },
              child: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.edit, color: primaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _branchBadge(String text, {bool showArrow = false}) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F5),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          if (showArrow) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              color: primaryColor,
              size: 18,
            ),
          ],
        ],
      ),
    );
  }

  // ========================================
  // GENERAL PROFILE INFORMATION
  // ========================================

  Widget _buildProfileInformation(
    RestaurantBrandModel brand,
    RestaurantModel restaurant,
  ) {
    return Expanded(
      child: Transform.translate(
        offset: const Offset(0, -20),
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              bottom: 30,
              top: 40,
              left: 25,
              right: 25,
            ),
            decoration: const BoxDecoration(
              color: pageBackground,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo and restaurant name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
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
                            color: primaryColor,
                            size: 40,
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 25),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${brand.name} •\n'
                            '${restaurant.branchName}',
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            brand.cuisine,
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                _informationRow(
                  Icons.access_time,
                  _formatOpeningHours(restaurant.openingHours),
                ),

                const SizedBox(height: 20),

                _informationRow(Icons.location_on_outlined, restaurant.address),

                const SizedBox(height: 20),

                _informationRow(
                  Icons.phone_outlined,
                  PhoneNumberUtils.display(restaurant.phone),
                ),

                const SizedBox(height: 25),

                const Text(
                  'About',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),

                const SizedBox(height: 10),

                Text(
                  brand.about,
                  style: const TextStyle(color: Color(0xFF4B5563), height: 1.5),
                ),

                const SizedBox(height: 25),

                const Text(
                  'Estimated time per table',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text('${restaurant.estimatedTime} minutes'),
                ),

                // ==================================
                // MOCKPAY MERCHANT STATUS
                // ==================================
                const SizedBox(height: 25),

                _buildMockPayButton(brand.name),

                // ==================================
                // LOGOUT
                // ==================================
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF1F2),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: const BorderSide(
                        color: Color(0xFFFECDD3),
                        width: 1.5,
                      ),
                    ),
                    onPressed: _logout,
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
    );
  }

  Widget _informationRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 16),
        Expanded(child: Text(text)),
      ],
    );
  }

  // ========================================
  // MAIN BUILD
  // ========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,

      body: StreamBuilder<RestaurantBrandModel>(
        stream: viewmodel.watchRestaurantBrand(widget.restaurantBrandId),
        builder: (context, brandSnapshot) {
          if (!brandSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          final brand = brandSnapshot.data!;

          return StreamBuilder<RestaurantModel>(
            stream: viewmodel.watchRestaurantBranch(
              widget.restaurantBrandId,
              selectedRestaurantId,
            ),
            builder: (context, restaurantSnapshot) {
              if (!restaurantSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
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

              if (!isProfileSetup) {
                return _buildProfileSetup();
              }

              return Column(
                children: [
                  _buildHeader(restaurant),

                  _buildProfileInformation(brand, restaurant),
                ],
              );
            },
          );
        },
      ),

      bottomNavigationBar: Container(
        height: 100,
        padding: const EdgeInsets.all(10),
        color: Colors.white,
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
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // BOTTOM NAVIGATION ITEM
  // ========================================

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
          color: isActive ? const Color(0xFFF0FDFA) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 26,
              color: isActive ? darkTeal : const Color(0xFF64748B),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive ? darkTeal : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
