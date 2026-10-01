import 'package:cloud_firestore/cloud_firestore.dart';

class ReservationModel {
  final String reservationId;

  final String customerId;
  final String customerName;
  final String customerPhone;

  final String brandId;
  final String restaurantId;
  final String restaurantName;

  final String bookingType;
  // SELF
  // OTHER

  final String guestName;
  final String guestPhone;

  final int pax;

  final DateTime reservationDateTime;

  final String specialRequest;

  final String status;
  // PENDING
  // CONFIRMED
  // REJECTED
  // CANCELLED

  final DateTime? createdAt;

  ReservationModel({
    required this.reservationId,

    required this.customerId,
    required this.customerName,
    required this.customerPhone,

    required this.brandId,
    required this.restaurantId,
    required this.restaurantName,

    required this.bookingType,
    //SELF
    //OTHER

    required this.guestName,
    required this.guestPhone,

    required this.pax,

    required this.reservationDateTime,

    required this.specialRequest,

    required this.status,

    this.createdAt,
  });

  factory ReservationModel.fromMap(
      String id,
      Map<String, dynamic> data,
      ) {
    return ReservationModel(
      reservationId: id,

      customerId: data['customer_id'] ?? '',
      customerName: data['customer_name'] ?? '',
      customerPhone: data['customer_phone'] ?? '',

      brandId: data['brand_id'] ?? '',
      restaurantId: data['restaurant_id'] ?? '',
      restaurantName: data['restaurant_name'] ?? '',

      bookingType: data['booking_type'] ?? 'SELF',

      guestName: data['guest_name'] ?? '',
      guestPhone: data['guest_phone'] ?? '',

      pax: data['pax'] ?? 1,

      reservationDateTime:
      (data['reservation_datetime'] as Timestamp)
          .toDate(),

      specialRequest:
      data['special_request'] ?? '',

      status:
      data['status'] ?? 'PENDING',

      createdAt:
      (data['created_at'] as Timestamp?)
          ?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reservation_id': reservationId,

      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,

      'brand_id': brandId,
      'restaurant_id': restaurantId,
      'restaurant_name': restaurantName,

      'booking_type': bookingType,

      'guest_name': guestName,
      'guest_phone': guestPhone,

      'pax': pax,

      'reservation_datetime':
      Timestamp.fromDate(
        reservationDateTime,
      ),

      'special_request': specialRequest,

      'status': status,

      'created_at':
      createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(
        createdAt!,
      ),
    };
  }

  bool get isPending =>
      status == 'PENDING';

  bool get isConfirmed =>
      status == 'CONFIRMED';

  bool get isRejected =>
      status == 'REJECTED';

  bool get isCancelled =>
      status == 'CANCELLED';

  bool get canCancel {
    final cutoff =
    reservationDateTime.subtract(
      const Duration(hours: 24),
    );

    return DateTime.now().isBefore(
      cutoff,
    );
  }
}