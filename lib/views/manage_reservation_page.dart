import 'package:flutter/material.dart';

import '../models/reservation_model.dart';
import '../viewmodels/reservation_viewmodel.dart';

class ManageReservationPage extends StatefulWidget {
  final ReservationModel reservation;

  const ManageReservationPage({
    super.key,
    required this.reservation,
  });

  @override
  State<ManageReservationPage> createState() =>
      _ManageReservationPageState();
}

class _ManageReservationPageState
    extends State<ManageReservationPage> {

  final ReservationViewModel _viewModel =
  ReservationViewModel();

  bool isCancelling = false;

  Future<void> cancelReservation() async {

    final confirm =
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Cancel Reservation',
          ),
          content: const Text(
            'Are you sure you want to cancel this reservation?',
          ),
          actions: [

            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'No',
              ),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'Yes',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {

      setState(() {
        isCancelling = true;
      });

      await _viewModel.cancelReservation(
        widget.reservation,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Reservation cancelled successfully.',
          ),
        ),
      );

      Navigator.pop(context);

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
        ),
      );

    } finally {

      if (mounted) {
        setState(() {
          isCancelling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    final reservation =
        widget.reservation;

    Color statusColor =
        Colors.grey;

    if (reservation.status ==
        'PENDING') {
      statusColor =
          Colors.orange;
    }

    if (reservation.status ==
        'CONFIRMED') {
      statusColor =
          Colors.green;
    }

    if (reservation.status
        .contains('CANCELLED')) {
      statusColor =
          Colors.red;
    }

    return Scaffold(
      backgroundColor:
      const Color(0xFFF6FAFB),

      appBar: AppBar(
        title: const Text(
          'Reservation Details',
        ),
        backgroundColor:
        const Color(0xFF006670),
        foregroundColor:
        Colors.white,
      ),

      body: SingleChildScrollView(
        padding:
        const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [

            Card(
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(
                  16,
                ),
              ),

              child: Padding(
                padding:
                const EdgeInsets.all(20),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    Center(
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),

                        decoration:
                        BoxDecoration(
                          color:
                          statusColor,
                          borderRadius:
                          BorderRadius.circular(
                            20,
                          ),
                        ),

                        child: Text(
                          reservation.status,
                          style:
                          const TextStyle(
                            color:
                            Colors.white,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _detailRow(
                      'Restaurant',
                      reservation.restaurantName,
                    ),

                    _detailRow(
                      'Booking Type',
                      reservation.bookingType,
                    ),

                    _detailRow(
                      'Customer Name',
                      reservation.customerName,
                    ),

                    _detailRow(
                      'Customer Phone',
                      reservation.customerPhone,
                    ),

                    if (reservation
                        .bookingType ==
                        'OTHER') ...[

                      _detailRow(
                        'Guest Name',
                        reservation.guestName,
                      ),

                      _detailRow(
                        'Guest Phone',
                        reservation.guestPhone,
                      ),
                    ],

                    _detailRow(
                      'Pax',
                      reservation.pax.toString(),
                    ),

                    _detailRow(
                      'Date',
                      '${reservation.reservationDateTime.day}/${reservation.reservationDateTime.month}/${reservation.reservationDateTime.year}',
                    ),

                    _detailRow(
                      'Time',
                      '${reservation.reservationDateTime.hour}:${reservation.reservationDateTime.minute.toString().padLeft(2, '0')}',
                    ),

                    _detailRow(
                      'Remarks',
                      reservation.specialRequest,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 30,
            ),

            if (reservation.canCancel &&
                (reservation.status ==
                    'PENDING' ||
                reservation.status == 'CONFIRMED')
            )

              SizedBox(
                width: double.infinity,
                height: 55,

                child: ElevatedButton(
                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    Colors.red,
                  ),

                  onPressed:
                  isCancelling
                      ? null
                      : cancelReservation,

                  child:
                  isCancelling
                      ? const CircularProgressIndicator(
                    color:
                    Colors.white,
                  )
                      : const Text(
                    'Cancel Reservation',
                    style:
                    TextStyle(
                      color:
                      Colors.white,
                    ),
                  ),
                ),
              ),

            if (!reservation.canCancel &&
                (reservation.status ==
                    'PENDING' ||
                reservation.status == 'CONFIRMED')
            )

              const Center(
                child: Text(
                  'Cancellation is no longer allowed (less than 24 hours before reservation).',
                  textAlign:
                  TextAlign.center,
                  style: TextStyle(
                    color:
                    Colors.red,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
      String label,
      String value,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 12,
      ),

      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          SizedBox(
            width: 120,
            child: Text(
              label,
              style:
              const TextStyle(
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value.isEmpty
                  ? '-'
                  : value,
            ),
          ),
        ],
      ),
    );
  }
}