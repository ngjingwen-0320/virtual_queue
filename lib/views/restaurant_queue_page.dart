import 'package:flutter/material.dart';
import 'package:virtual_queue/models/restaurant_brand_model.dart';
import 'package:virtual_queue/models/restaurant_queue_model.dart';
import 'package:virtual_queue/viewmodels/restaurant_queue_viewmodel.dart';
import 'package:virtual_queue/models/restaurant_model.dart';
import 'package:virtual_queue/views/restaurant_profile_page.dart';
import 'package:virtual_queue/views/restaurant_reservation_page.dart';

class RestaurantQueuePage extends StatefulWidget{
  final String restaurantId;
  final String restaurantBrandId;
  final List<String> restaurantIds;

  const RestaurantQueuePage({super.key, required this.restaurantId, required this.restaurantBrandId, required this.restaurantIds,});

  @override
  State<RestaurantQueuePage> createState() => _RestaurantQueuePageState();
}

class _RestaurantQueuePageState extends State<RestaurantQueuePage> {

  final viewmodel = RestaurantQueueViewmodel();

  late String selectedRestaurantId;

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
  void initState() {
    super.initState();
    selectedRestaurantId = widget.restaurantId;
  }

  @override
  Widget build(BuildContext context) {
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
                  builder: (context, restaurantSnapshot){
                    if(!restaurantSnapshot.hasData){
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    final restaurant = restaurantSnapshot.data!;

                    if (!_isProfileSetupComplete(brand, restaurant)) {
                      return _buildSetupRequiredMessage();
                    }

                    return StreamBuilder<RestaurantQueueModel>(
                      stream: viewmodel.watchQueue(selectedRestaurantId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final queue = snapshot.data!;
                        final hasCurrentCustomer = queue.currentServing > 0;

                        return StreamBuilder<int>(
                          stream: viewmodel.watchWaitingTicketCount(selectedRestaurantId),
                          builder: (context, waitingSnapshot){
                            final waitingCount = waitingSnapshot.data ?? 0;
                            final statusString = viewmodel.getWaitStatus(waitingCount);
                            final badgeBgColor = viewmodel.getWaitStatusColor(waitingCount);
                            final hasWaitingCustomer = waitingCount > 0;
                            final servedCustomer = hasCurrentCustomer && !hasWaitingCustomer;
                            final callButtonText = hasWaitingCustomer
                                ? 'Call Next'
                                : servedCustomer
                                ? 'Served'
                                : 'No Customer';

                            final callButtonIcon = hasWaitingCustomer
                                ? Icons.notifications
                                : servedCustomer
                                ? Icons.check_circle
                                : Icons.notifications_off;
                            return Padding(
                              padding: const EdgeInsets.all(25.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Queue Management',
                                        style: TextStyle(
                                          fontWeight: FontWeight(1000),
                                          color: Color(0xFF006670),
                                          fontSize: 25,
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        onPressed: () async {
                                          final confirmReset = await _showResetQueueDialog();
                                          if (confirmReset == true) {
                                            await viewmodel.resetQueue(selectedRestaurantId);
                                          }
                                        },
                                        icon: Icon(
                                          Icons.restart_alt,
                                          color: Color(0xFF006670),
                                        )
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 20),
                                  _buildAvailabilityToggle(),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF0F4F5),
                                      borderRadius: BorderRadius.circular(20),
                                      border: const Border(
                                        left: BorderSide(color: Color(0xFF006670), width: 8),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.25),
                                          blurRadius: 5,
                                          offset: const Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '# ${queue.currentServing}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 40,
                                          ),
                                        ),
                                        Text(
                                          'Now Serving',
                                          style: TextStyle(
                                            color: Color(0xFF777777),
                                            fontSize: 16,
                                          ),
                                        ),
                                        Divider(height: 32),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: hasCurrentCustomer
                                                    ? () async {
                                                  final confirmSkip = await _showSkipConfirmationDialog();
                                                  if (confirmSkip == true) {
                                                    await viewmodel.skipCurrentCustomer(selectedRestaurantId);
                                                  }
                                                }
                                                    : null,
                                                style: OutlinedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFFFF1F2),
                                                  foregroundColor: Colors.redAccent,
                                                  side: BorderSide(
                                                    color: hasCurrentCustomer ? Colors.redAccent : Colors.grey,
                                                  ),
                                                ),
                                                icon: const Icon(
                                                  Icons.cancel_outlined,
                                                ),
                                                label: const Text('Skip'),
                                              ),
                                              const SizedBox(width: 10),
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Color(0xFF006670),
                                                  padding: const EdgeInsets.only(left: 20, top: 10, right: 20, bottom: 10),
                                                ),
                                                onPressed: hasWaitingCustomer
                                                    ? () {
                                                  viewmodel.callNextCustomer(selectedRestaurantId);
                                                }
                                                    : servedCustomer
                                                    ? () {
                                                  viewmodel.markCurrentCustomerServed(selectedRestaurantId);
                                                }
                                                    : null,
                                                icon: Icon(
                                                  callButtonIcon,
                                                  color: Color(0xFFFFFFFF),
                                                  size: 20,
                                                ),
                                                label: Text(
                                                  callButtonText,
                                                  style: const TextStyle(
                                                    color: Color(0xFFFFFFFF),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 30),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDDF1F2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          '$waitingCount',
                                          style: const TextStyle(
                                            fontSize: 35,
                                            fontWeight: FontWeight(1000),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Tables in Queue',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: badgeBgColor,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            statusString,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        );
                      }
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
              isActive: true,
              onTap: () {},
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

  Widget _buildAvailabilityToggle() {
    return StreamBuilder<RestaurantModel>(
      stream: viewmodel.watchRestaurantBranch(
        widget.restaurantBrandId,
        selectedRestaurantId,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final restaurant = snapshot.data!;

        return Container(
          margin: const EdgeInsets.only(bottom: 30),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Color(0xFFF0F4F5),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Text(
                restaurant.isActive ? 'Queue available' : 'Queue unavailable',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),

              const Spacer(),

              Switch(
                value: restaurant.isActive,
                activeThumbColor: const Color(0xFF006670),
                onChanged: (value) async {
                  await viewmodel.updateRestaurantAvailability(
                    restaurantBrandId: widget.restaurantBrandId,
                    restaurantId: selectedRestaurantId,
                    isActive: value,
                  );
                },
              ),
            ],
          ),
        );
      },
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
                          size: 12,
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
              'Queue will be available once you complete your restaurant profile setup. Please go to Profile to finish setup.',
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

  Future<bool?> _showSkipConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Skip Customer',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to skip the queue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF48626E),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Skip Queue',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            )
          ),
        ],
      ),
    );
  }

  Future<bool?> _showResetQueueDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Reset Queue',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to reset the queue? Waiting and called tickets will be marked as expired.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF48626E),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Reset',
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
}
