import '../utils/phone_number_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reservation_model.dart';
import 'mockpay_service.dart';

class ReservationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================================================
  // CREATE RESERVATION
  // ==================================================

  Future<String> createReservation(
    ReservationModel reservation, {
    String? reservationId,
  }) async {
    final minimumBookingTime = DateTime.now().add(const Duration(hours: 24));

    if (reservation.reservationDateTime.isBefore(minimumBookingTime)) {
      throw Exception(
        'Reservations must be made at least 24 hours in advance.',
      );
    }

    final doc = _db.collection('reservations').doc(reservationId);
    final data = reservation.toMap();
    data['customer_phone'] = PhoneNumberUtils.normalize(
      reservation.customerPhone,
    );
    data['guest_phone'] = reservation.bookingType == 'OTHER'
        ? PhoneNumberUtils.normalize(reservation.guestPhone)
        : '';
    data.remove('status');
    data.remove('created_at');
    data['reservation_id'] = doc.id;
    data['reservation_datetime'] = reservation.reservationDateTime
        .toUtc()
        .toIso8601String();
    final result = await MockPayService().createReservation(data);
    return result['reservationId'] as String;
  }

  // CUSTOMER RESERVATIONS
  Stream<List<ReservationModel>> watchMyReservations() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.value([]);
    }

    return _db
        .collection('reservations')
        .where('customer_id', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ReservationModel.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  // RESTAURANT RESERVATIONS
  Stream<List<ReservationModel>> watchRestaurantReservations(
    String restaurantId,
    String brandId,
  ) {
    return _db
        .collection('reservations')
        .where('restaurant_id', isEqualTo: restaurantId)
        .where('brand_id', isEqualTo: brandId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ReservationModel.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  // APPROVE RESERVATION
  Future<void> approveReservation(String reservationId) async {
    await MockPayService().reservationAction(reservationId, 'approve');
  }

  Future<void> rejectReservation(String reservationId) async {
    await MockPayService().reservationAction(reservationId, 'reject');
  }

  Future<void> cancelReservation(ReservationModel reservation) async {
    await MockPayService().reservationAction(
      reservation.reservationId,
      'cancel',
    );
  }

  Future<void> updateReservation({
    required String reservationId,
    required DateTime reservationDateTime,
    required int pax,
    String? specialRequest,
  }) async {
    await MockPayService().reservationAction(reservationId, 'update', {
      'reservationDateTime': reservationDateTime.toUtc().toIso8601String(),
      'pax': pax,
      'specialRequest': specialRequest ?? '',
    });
  }
}
