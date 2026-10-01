import 'package:flutter/material.dart';
import 'package:virtual_queue/views/restaurant_queue_page.dart';
import 'package:virtual_queue/views/restaurant_profile_page.dart';
import 'package:virtual_queue/models/restaurant_brand_model.dart';
import 'package:virtual_queue/models/restaurant_model.dart';
import 'package:virtual_queue/viewmodels/restaurant_profile_viewmodel.dart';
import '../models/reservation_model.dart';
import '../viewmodels/reservation_viewmodel.dart';

class RestaurantReservationPage extends StatefulWidget {
  final String restaurantId;
  final String restaurantBrandId;
  final List<String> restaurantIds;

  const RestaurantReservationPage({
    super.key,
    required this.restaurantId,
    required this.restaurantBrandId,
    required this.restaurantIds,
  });

  @override
  State<RestaurantReservationPage> createState() => _RestaurantReservationPageState();
}

class _RestaurantReservationPageState extends State<RestaurantReservationPage>{

  final viewmodel = RestaurantProfileViewModel();
  final ReservationViewModel reservationViewModel = ReservationViewModel();
  // bool _showActive = true;
  int selectedTab = 0;

  late String selectedRestaurantId;

  @override
  void initState() {
    super.initState();
    selectedRestaurantId = widget.restaurantId;
  }

  bool _isProfileSetupComplete(
      RestaurantBrandModel brand,
      RestaurantModel restaurant,
      ) {
    return brand.cuisine.isNotEmpty &&
        brand.about.isNotEmpty &&
        brand.logoUrl.isNotEmpty &&
        restaurant.phone.isNotEmpty &&
        restaurant.openingHours.isNotEmpty &&
        restaurant.estimatedTime > 0 &&
        restaurant.imageUrl.isNotEmpty;
  }

  @override
  Widget build (BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6FAFB),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<RestaurantBrandModel>(
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

                    if (!_isProfileSetupComplete(brand, restaurant)) {
                      return _buildSetupRequiredMessage();
                    }

                    return StreamBuilder<List<ReservationModel>>(
                      stream: reservationViewModel
                          .watchRestaurantReservations(
                        selectedRestaurantId,
                      ),
                      builder: (context, reservationSnapshot) {

                        if (!reservationSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final reservations =
                        reservationSnapshot.data!;

                        final now = DateTime.now();
                        
                        final activeReservations = reservations.where((reservation) {
                          return reservation.status == 'PENDING' ||
                              reservation.status == 'CONFIRMED';
                        }).toList();

                        final historyReservations = reservations.where((reservation) {
                          return reservation.status == 'REJECTED' ||
                              reservation.status == 'CANCELLED';
                        }).toList();

                        return Column(
                          children: [

                            const SizedBox(height: 15),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [

                                _buildTabButton(
                                  title: "Active",
                                  selected: selectedTab == 0,
                                  onTap: () {
                                    setState(() {
                                      selectedTab = 0;
                                    });
                                  },
                                ),

                                _buildTabButton(
                                  title: "History",
                                  selected: selectedTab == 1,
                                  onTap: () {
                                    setState(() {
                                      selectedTab = 1;
                                    });
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 15),

                            Expanded(
                              child: selectedTab == 0
                                  ? activeReservations.isEmpty
                                  ? _buildEmptyReservationState(
                                icon: Icons.event_busy_rounded,
                                title: 'No Active Reservations',
                                subtitle:
                                'There are currently no pending or confirmed reservations.',
                              )
                                  : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: activeReservations.length,
                                itemBuilder: (context, index) {
                                  return _buildReservationCard(
                                    activeReservations[index],
                                  );
                                },
                              )
                                  : historyReservations.isEmpty
                                  ? _buildEmptyReservationState(
                                icon: Icons.history_rounded,
                                title: 'No Reservation History',
                                subtitle:
                                'Rejected and cancelled reservations will appear here.',
                              )
                                  : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: historyReservations.length,
                                itemBuilder: (context, index) {
                                  return _buildReservationCard(
                                    historyReservations[index],
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
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
              isActive: true,
              onTap: () {},
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
              isActive: false,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RestaurantProfilePage(
                      restaurantBrandId: widget.restaurantBrandId,
                      restaurantId: selectedRestaurantId,
                      restaurantIds: widget.restaurantIds,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyReservationState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Icon(
              icon,
              size: 70,
              color: const Color(0xFF006670),
            ),

            const SizedBox(height: 16),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF134E4A),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),

            if (buttonText != null && onPressed != null) ...[
              const SizedBox(height: 20),

              SizedBox(
                width: 180,
                height: 45,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006670),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onPressed,
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
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

  Widget _buildSetupRequiredMessage() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 60,
              color: Color(0xFF006670),
            ),
            SizedBox(height: 18),
            Text(
              'Profile setup required',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Reservation will be available once you complete your restaurant profile setup. Please go to Profile to finish setup.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<RestaurantBrandModel>(
      stream: viewmodel.watchRestaurantBrand(widget.restaurantBrandId),
      builder: (context, snapshot){
        if(!snapshot.hasData){
          return Container(
            height: 55,
            width: 55,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.restaurant,
              color: Color(0xFF006670),
            ),
          );
        }

        final brand = snapshot.data!;
        return Container(
          height: 140,
          width: double.infinity,
          padding: EdgeInsets.only(
            top: 70,
            bottom: 20,
            left: 20,
            right: 20,
          ),
          color: Color(0xFF006670),
          child: Row(
            children: [
              Container(
                height: 55,
                width: 55,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: brand.logoUrl.isEmpty
                    ? Center(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.restaurant,
                      color: Color(0xFF006670),
                      size: 30,
                    ),
                  ),
                )
                    : Image.network(
                  brand.logoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.restaurant,
                      color: Color(0xFF006670),
                      size: 30,
                    );
                  },
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StreamBuilder<RestaurantBrandModel>(
                      stream: viewmodel.watchRestaurantBrand(widget.restaurantBrandId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Text(
                            'Loading...',
                            style: TextStyle(color: Colors.white),
                          );
                        }
                        final brand = snapshot.data!;
                        return Text(
                          brand.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                            Icons.location_on_outlined,
                            color: Colors.white,
                            size: 12
                        ),
                        SizedBox(width: 2),
                        Expanded(
                          child: StreamBuilder<RestaurantModel> (
                              stream: viewmodel.watchRestaurantBranch(
                                widget.restaurantBrandId,
                                selectedRestaurantId,
                              ),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Text(
                                    '',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  );
                                }
                                final restaurant = snapshot.data!;
                                return Text(
                                  restaurant.branchName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                );
                              }
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              widget.restaurantIds.length > 1
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
            ],
          ),
        );
      }
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Icon(
            icon,
            color: const Color(0xFF006670),
            size: 22,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: Colors.black,
                  fontSize: 17,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Color(0xFF48626E),
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: selected
                    ? const Color(0xFF006670)
                    : const Color(0xFF64748B),
              ),
            ),

            const SizedBox(height: 6),

            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 3,
              width: 55,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF006670)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationCard(
      ReservationModel reservation,
      ) {

    Color statusColor = Colors.grey;

    if (reservation.status == 'PENDING') {
      statusColor = Colors.orange;
    }

    if (reservation.status == 'CONFIRMED') {
      statusColor = Color(0xFF006670);
    }

    if (reservation.status.contains('CANCELLED')) {
      statusColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [

            Row(
              children: [

                Expanded(
                  child: Text(
                    reservation.customerName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006670),
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    reservation.status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            _buildInfoRow(
              icon: Icons.groups_outlined,
              title: 'No. of Pax',
              value: reservation.pax.toString(),
            ),

            _buildInfoRow(
              icon: Icons.calendar_today_outlined,
              title: 'Date',
              value:
              '${reservation.reservationDateTime.day}/${reservation.reservationDateTime.month}/${reservation.reservationDateTime.year}',
            ),

            _buildInfoRow(
              icon: Icons.access_time_outlined,
              title: 'Time',
              value:
              '${reservation.reservationDateTime.hour}:${reservation.reservationDateTime.minute.toString().padLeft(2, '0')}',
            ),

            if (reservation.status == 'PENDING') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF006670),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        await reservationViewModel.approveReservation(
                          reservation.reservationId,
                        );
                      },
                      icon: const Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Approve',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFF1F2),
                        foregroundColor: Colors.redAccent,
                      ),
                      onPressed: () async {
                        await reservationViewModel.rejectReservation(
                          reservation.reservationId,
                        );
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                      ),
                      label: const Text(
                        'Reject',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
