import '../models/reservation_model.dart';
import '../services/reservation_service.dart';

class ReservationViewModel {

  final ReservationService _service =
  ReservationService();

  // CUSTOMER
  Stream<List<ReservationModel>>
  watchMyReservations() {
    return _service.watchMyReservations();
  }

  Future<void> createReservation(
      ReservationModel reservation,
      ) async {
    await _service.createReservation(
      reservation,
    );
  }

  Future<void> cancelReservation(
      ReservationModel reservation,
      ) async {
    await _service.cancelReservation(
      reservation,
    );
  }

  Future<void> updateReservation({
    required String reservationId,
    required DateTime reservationDateTime,
    required int pax,
    String? specialRequest,
  }) async {

    await _service.updateReservation(
      reservationId: reservationId,
      reservationDateTime:
      reservationDateTime,
      pax: pax,
      specialRequest:
      specialRequest,
    );
  }

  // RESTAURANT
  Stream<List<ReservationModel>>
  watchRestaurantReservations(
      String restaurantId,
      ) {

    return _service
        .watchRestaurantReservations(
      restaurantId,
    );
  }

  Future<void> approveReservation(
      String reservationId,
      ) async {

    await _service.approveReservation(
      reservationId,
    );
  }

  Future<void> rejectReservation(
      String reservationId,
      ) async {

    await _service.rejectReservation(
      reservationId,
    );
  }
}