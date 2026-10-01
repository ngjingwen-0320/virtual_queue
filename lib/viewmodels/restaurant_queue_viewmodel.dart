import 'package:flutter/material.dart';
import 'package:virtual_queue/models/restaurant_brand_model.dart';
import 'package:virtual_queue/models/restaurant_model.dart';
import 'package:virtual_queue/models/restaurant_queue_model.dart';
import 'package:virtual_queue/services/queue_service.dart';
import 'package:virtual_queue/services/restaurant_service.dart';

class RestaurantQueueViewmodel extends ChangeNotifier{
  final QueueService _queueService = QueueService();

  bool isCallingNext = false;
  String? errorMessage;

  Stream<RestaurantQueueModel> watchQueue(String restaurantId) {
    return _queueService.watchRestaurantQueue(restaurantId);
  }

  Stream<int> watchWaitingTicketCount(String restaurantId) {
    return _queueService.watchWaitingTicketCount(restaurantId);
  }

  // When staff presses Call Next
  Future<void> callNextCustomer(String restaurantId) async {
    isCallingNext = true;
    errorMessage = null;
    notifyListeners();

    try{
      // Ask service to update Firestore
      await _queueService.callNextCustomer(restaurantId);
    } catch(e) {
      errorMessage = 'Failed to call next customer';
    } finally {
      isCallingNext = false;
      notifyListeners();
    }
  }

  Future<void> skipCurrentCustomer(String restaurantId) async {
    isCallingNext = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _queueService.skipCurrentCustomer(restaurantId);
    } catch (e) {
      errorMessage = 'Failed to skip customer';
    } finally {
      isCallingNext = false;
      notifyListeners();
    }
  }

  Future<void> markCurrentCustomerServed(String restaurantId) async {
    isCallingNext = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _queueService.markCurrentCustomerServed(restaurantId);
    } catch (e) {
      errorMessage = 'Failed to mark customer as served';
    } finally {
      isCallingNext = false;
      notifyListeners();
    }
  }

  Future<void> resetQueue(String restaurantId) async {
    isCallingNext = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _queueService.resetQueue(restaurantId);
    } catch (e) {
      errorMessage = 'Failed to reset queue';
    } finally {
      isCallingNext = false;
      notifyListeners();
    }
  }

  Future<void> updateRestaurantAvailability({
    required String restaurantBrandId,
    required String restaurantId,
    required bool isActive,
  }) async {
    await _restaurantService.updateRestaurantAvailability(
      restaurantBrandId: restaurantBrandId,
      restaurantId: restaurantId,
      isActive: isActive,
    );
  }

  final RestaurantService _restaurantService = RestaurantService();

  Stream<RestaurantBrandModel> watchRestaurantBrand(String restaurantBrandId) {
    return _restaurantService.watchRestaurant(restaurantBrandId);
  }

  Stream<RestaurantModel> watchRestaurantBranch(
    String restaurantBrandId,
    String restaurantId
  ) {
    return _restaurantService.watchRestaurantBranch(
      restaurantBrandId,
      restaurantId
    );
  }

  String getWaitStatus(int waitingCount) {
    if (waitingCount == 0) {
      return 'No waiting';
    }

    if (waitingCount <= 5) {
      return 'Short Wait';
    }

    if (waitingCount <= 10) {
      return 'Moderate';
    }

    return 'Busy';
  }

  Color getWaitStatusColor(int waitingCount) {
    if (waitingCount == 0) {
      return const Color(0xFF008645);
    }

    if (waitingCount <= 5) {
      return const Color(0xFFF39850);
    }

    if (waitingCount <= 10) {
      return const Color(0xFFFF7890);
    }

    return const Color(0xFFBA1A1A);
  }
}