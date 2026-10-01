import 'package:flutter/material.dart';
import 'package:virtual_queue/views/customer_home_view.dart';
import 'package:flutter/services.dart';
import '../models/reservation_model.dart';
import '../viewmodels/reservation_viewmodel.dart';

class CustomerReservationPage extends StatefulWidget {
  const CustomerReservationPage({
    super.key,
  });

  @override
  State<CustomerReservationPage> createState() =>
      _CustomerReservationPageState();
}

class _CustomerReservationPageState
    extends State<CustomerReservationPage> {

  final ReservationViewModel _viewModel =
  ReservationViewModel();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFB),

      appBar: AppBar(
        title: const Text(
          'My Reservations',
        ),
        backgroundColor: const Color(0xFF115E59),
        foregroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF115E59),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ReservationModel>>(
              stream: _viewModel.watchMyReservations(),

              builder: (context,
                  snapshot,) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child:
                    CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyReservationState();
                }

                final reservations = snapshot.data!;

                final currentBookings = reservations.where((reservation) {
                  return reservation.status == 'PENDING' ||
                      reservation.status == 'CONFIRMED';
                }).toList();

                final historyBookings = reservations.where((reservation) {
                  return reservation.status == 'CANCELLED' ||
                      reservation.status == 'REJECTED';
                }).toList();

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildCurrentBookingHeader(currentBookings.isNotEmpty),

                    const SizedBox(height: 16),

                    if (currentBookings.isEmpty)
                      _buildNoCurrentBookingsState()
                    else
                      ...currentBookings.map(
                            (reservation) => _buildReservationCard(reservation),
                      ),

                    const SizedBox(height: 30),

                    _buildHistoryHeader(),

                    const SizedBox(height: 16),

                    if (historyBookings.isEmpty)
                      _buildNoHistoryState()
                    else
                      ...historyBookings.map(
                            (reservation) => _buildReservationCard(reservation),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCancelDialog(ReservationModel reservation,) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          title: const Text(
            'Cancel Reservation',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.bold,
            ),
          ),

          content: const Text(
            'Are you sure you want to cancel this reservation?',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
            ),
          ),

          actions: [

            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text(
                'No',
                style: TextStyle(
                  color: Color(0xFF48626E),
                ),
              ),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text(
                'Yes',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {

        if (!reservation.canCancel) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'You can only cancel at least 24 hours before reservation time.',
              ),
            ),
          );
          return;
        }

        await _viewModel.cancelReservation(reservation);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation cancelled.'),
          ),
        );

      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
          ),
        );
      }
    }
  }

  Widget _buildCurrentBookingHeader(bool hasCurrentBookings) {
    return Row(
      mainAxisAlignment:
      MainAxisAlignment.spaceBetween,
      children: [

        const Text(
          'Current Bookings',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF134E4A),
          ),
        ),

        if (hasCurrentBookings)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor:
              const Color(0xFF006670),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerHomeView(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text(
              'Book',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryHeader() {
    return const Text(
      'History',
      style: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Color(0xFF134E4A),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Icon(
            icon,
            color: const Color(0xFF006670),
            size: 18,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: Colors.black,
                  fontSize: 15,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
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

  Widget _buildReservationCard(ReservationModel reservation,) {
    final bool canCancel =
        reservation.status == 'PENDING' ||
            reservation.status == 'CONFIRMED';

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

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Restaurant + Status
          Row(
            children: [
              Expanded(
                child: Text(
                  reservation.restaurantName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006670),
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: reservation.status == 'CONFIRMED'
                      ? const Color(0xFF006670)
                      : reservation.status == 'PENDING'
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFEF4444),
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
            icon: Icons.person_outline,
            title: 'Name',
            value: reservation.customerName,
          ),

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

          if (reservation.status == 'PENDING' ||
              reservation.status == 'CONFIRMED') ...[

            const SizedBox(height: 24),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                ),
                onPressed: () {
                  _showCancelDialog(reservation);
                },
                child: const Text("Cancel"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyReservationState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Icon(
              Icons.event_available_rounded,
              size: 70,
              color: Color(0xFF006670),
            ),

            const SizedBox(height: 16),

            const Text(
              'First time here?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF134E4A),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Make your first reservation now',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),

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

                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerHomeView(),
                    ),
                  );
                },

                child: const Text(
                  'Book Now',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoActiveReservationState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Icon(
              Icons.restaurant_rounded,
              size: 70,
              color: Color(0xFF006670),
            ),

            const SizedBox(height: 16),

            const Text(
              'Ready for another visit?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF134E4A),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "You don't have any active reservations right now.\nReserve your next table in just a few taps.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),

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

                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerHomeView(),
                    ),
                  );
                },

                child: const Text(
                  'Book Again',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCurrentBookingsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 28,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_busy_outlined,
            size: 48,
            color: Color(0xFF006670),
          ),

          const SizedBox(height: 12),

          const Text(
            'No current reservations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF134E4A),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Ready for your next meal? Book another table anytime.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 20),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006670),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerHomeView(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Book Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoHistoryState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 28,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.history_toggle_off_rounded,
            size: 48,
            color: Color(0xFF006670),
          ),

          const SizedBox(height: 12),

          const Text(
            'No reservation history yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF134E4A),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Cancelled reservations will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}