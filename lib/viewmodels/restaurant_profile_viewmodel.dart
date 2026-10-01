import 'package:flutter/material.dart';
import 'package:virtual_queue/services/auth_service.dart';
import 'package:virtual_queue/models/restaurant_brand_model.dart';
import 'package:virtual_queue/models/restaurant_model.dart';
import 'package:virtual_queue/services/restaurant_service.dart';

class RestaurantProfileViewModel extends ChangeNotifier {

  final RestaurantService _restaurantService = RestaurantService();
  final AuthService _authService = AuthService();

  bool isLoggingOut = false;
  String? errorMessage;

  Future<bool> logout() async {
    isLoggingOut = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _authService.logout();
      return true;
    } catch (e) {
      errorMessage = 'Failed to logout';
      return false;
    } finally {
      isLoggingOut = false;
      notifyListeners();
    }
  }

  Stream<RestaurantBrandModel> watchRestaurantBrand(String restaurantBrandId) {
    return _restaurantService.watchRestaurant(restaurantBrandId);
  }

  Stream<RestaurantModel> watchRestaurantBranch(
    String restaurantBrandId,
      String restaurantId,
  ) {
    return _restaurantService.watchRestaurantBranch(
      restaurantBrandId,
      restaurantId,
    );
  }
}