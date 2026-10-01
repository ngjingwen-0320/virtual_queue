import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reservation_model.dart';

class ReservationService {
  final FirebaseFirestore _db =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ==================================================
  // CREATE RESERVATION
  // ==================================================

  Future<void> createReservation(
      ReservationModel reservation,
      ) async {

    final minimumBookingTime =
    DateTime.now().add(
      const Duration(hours: 24),
    );

    if (
    reservation.reservationDateTime
        .isBefore(minimumBookingTime)
    ) {
      throw Exception(
        'Reservations must be made at least 24 hours in advance.',
      );
    }

    final doc =
    _db.collection('reservations').doc();

    final reservationData = {
      'reservation_id': doc.id,
      'customer_id': reservation.customerId,
      'customer_name': reservation.customerName,
      'customer_phone': reservation.customerPhone,
      'brand_id': reservation.brandId,
      'restaurant_id': reservation.restaurantId,
      'restaurant_name': reservation.restaurantName,
      'booking_type': reservation.bookingType,
      'guest_name': reservation.guestName,
      'guest_phone': reservation.guestPhone,
      'pax': reservation.pax,
      'reservation_datetime': Timestamp.fromDate(reservation.reservationDateTime),
      'special_request': reservation.specialRequest,
      'status': 'PENDING',
      'created_at': FieldValue.serverTimestamp(),
    };
    await doc.set(reservationData);
  }

  // CUSTOMER RESERVATIONS
  Stream<List<ReservationModel>>
  watchMyReservations() {

    final user =
        _auth.currentUser;

    if (user == null) {
      return Stream.value([]);
    }

    return _db
        .collection('reservations')
        .where(
      'customer_id',
      isEqualTo: user.uid,
    )
        .snapshots()
        .map(
          (snapshot) {
        return snapshot.docs
            .map(
              (doc) =>
              ReservationModel.fromMap(
                doc.id,
                doc.data(),
              ),
        )
            .toList();
      },
    );
  }

  // RESTAURANT RESERVATIONS
  Stream<List<ReservationModel>>
  watchRestaurantReservations(
      String restaurantId,
      ) {

    return _db
        .collection('reservations')
        .where(
      'restaurant_id',
      isEqualTo: restaurantId,
    )
        .snapshots()
        .map(
          (snapshot) {
        return snapshot.docs
            .map(
              (doc) =>
              ReservationModel.fromMap(
                doc.id,
                doc.data(),
              ),
        )
            .toList();
      },
    );
  }

  // APPROVE RESERVATION
  Future<void> approveReservation(
      String reservationId,
      ) async {

    await _db
        .collection('reservations')
        .doc(reservationId)
        .update({
      'status': 'CONFIRMED',
    });
  }

  // REJECT RESERVATION
  Future<void> rejectReservation(
      String reservationId,
      ) async {

    await _db
        .collection('reservations')
        .doc(reservationId)
        .update({
      'status': 'REJECTED',
    });
  }

  // CUSTOMER CANCEL
  Future<void> cancelReservation(
      ReservationModel reservation,
      ) async {

    if (!reservation.canCancel) {
      throw Exception(
        'Reservations can only be cancelled at least 24 hours before the reservation time.',
      );
    }

    await _db.collection('reservations')
        .doc(reservation.reservationId)
        .update({
      'status': 'CANCELLED',
    });
  }

  // UPDATE RESERVATION

  Future<void> updateReservation({
    required String reservationId,
    required DateTime reservationDateTime,
    required int pax,
    String? specialRequest,
  }) async {

    await _db
        .collection('reservations')
        .doc(reservationId)
        .update({
      'reservation_datetime':
      Timestamp.fromDate(
        reservationDateTime,
      ),

      'pax': pax,

      'special_request':
      specialRequest ?? '',
    });
  }
}