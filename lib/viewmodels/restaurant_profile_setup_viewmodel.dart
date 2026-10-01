import 'dart:io';
import 'package:flutter/material.dart';
import 'package:virtual_queue/services/restaurant_service.dart';
import 'package:virtual_queue/models/restaurant_brand_model.dart';
import 'package:virtual_queue/models/restaurant_model.dart';
import 'package:rxdart/rxdart.dart';

class RestaurantProfileSetupViewModel extends ChangeNotifier {
  final RestaurantService _restaurantService = RestaurantService();

  bool isSaving = false;
  String? errorMessage;

  Future<bool> saveProfile({
    required String restaurantBrandId,
    required List<String> restaurantIds,
    required File? logoFile,
    required Map<String, File?> branchImageFiles,
    required String cuisine,
    required String about,
    required String phone,
    required Map<String, dynamic> openingHours,
    required int estimatedTime,
  }) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      String logoUrl = '';

      if (logoFile != null) {
        logoUrl = await _restaurantService.uploadRestaurantImage(
          file: logoFile,
          path: 'restaurant_brands/$restaurantBrandId/logo.jpg',
        );
      }

      await _restaurantService.updateBrandProfile(
        restaurantBrandId: restaurantBrandId,
        cuisine: cuisine,
        about: about,
        logoUrl: logoUrl,
      );

      for (final restaurantId in restaurantIds) {
        String imageUrl = '';

        final branchImage = branchImageFiles[restaurantId];
        if (branchImage != null) {
          imageUrl = await _restaurantService.uploadRestaurantImage(
            file: branchImage,
            path: 'restaurants/$restaurantId/main.jpg',
          );
        }

        await _restaurantService.updateRestaurantBranchProfile(
          restaurantBrandId: restaurantBrandId,
          restaurantId: restaurantId,
          phone: phone,
          openingHours: openingHours,
          estimatedTime: estimatedTime,
          imageUrl: imageUrl,
        );
      }

      return true;
    } catch (e) {
      errorMessage = 'Failed to save profile';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> saveBrandProfile({
    required String restaurantBrandId,
    required File? logoFile,
    required String cuisine,
    required String about,
  }) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      String logoUrl = '';

      if(logoFile != null) {
        logoUrl = await _restaurantService.uploadRestaurantImage(
          file: logoFile,
          path: 'restaurant_brands/$restaurantBrandId/logo.jpg',
        );
      }

      await _restaurantService.updateBrandProfile(
        restaurantBrandId: restaurantBrandId,
        cuisine: cuisine,
        about: about,
        logoUrl: logoUrl,
      );

      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> saveBranchProfile({
    required String restaurantBrandId,
    required String restaurantId,
    required File? imageFile,
    String? address,
    required String phone,
    required Map<String, dynamic> openingHours,
    required int estimatedTime,
  }) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      String imageUrl = '';

      if(imageFile != null) {
        imageUrl = await _restaurantService.uploadRestaurantImage(
          file: imageFile,
          path: 'restaurants/$restaurantId/main.jpg',
        );
      }

      await _restaurantService.updateRestaurantBranchProfile(
        restaurantBrandId: restaurantBrandId,
        restaurantId: restaurantId,
        address: address,
        phone: phone,
        openingHours: openingHours,
        estimatedTime: estimatedTime,
        imageUrl: imageUrl
      );

      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  // Get restaurant data from firestore
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

  // watch all branches for a restaurant
  Stream<List<RestaurantModel>> watchRestaurantBranches(
      String restaurantBrandId,
      List<String> restaurantIds,
      ) {
    final streams = restaurantIds.map((restaurantId) {
      return watchRestaurantBranch(restaurantBrandId, restaurantId);
    }).toList();

    return Rx.combineLatestList(streams);
  }
}
