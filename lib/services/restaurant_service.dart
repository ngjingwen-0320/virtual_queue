import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:virtual_queue/models/restaurant_model.dart';
import 'package:virtual_queue/models/restaurant_brand_model.dart';

class RestaurantService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<RestaurantBrandModel> watchRestaurant(String restaurantBrandId) {
    return _db
        .collection('restaurant_brands')
        .doc(restaurantBrandId)
        .snapshots()
        .map((doc){
      final data = doc.data() ?? {};
      return RestaurantBrandModel.fromMap(data);
    });
  }

  Stream<RestaurantModel> watchRestaurantBranch(String restaurantBrandId, String restaurantId) {
    return _db
        .collection('restaurant_brands')
        .doc(restaurantBrandId)
        .collection('restaurants')
        .doc(restaurantId)
        .snapshots()
        .map((doc){
      final data = doc.data() ?? {};
      return RestaurantModel.fromMap(data);
    });
  }

  Future<void> updateBrandProfile({
    required String restaurantBrandId,
    required String cuisine,
    required String about,
    required String logoUrl,
  }) async {
    final data = {
      'cuisine': cuisine,
      'about': about,
    };

    if (logoUrl.isNotEmpty) {
      data['logo_url'] = logoUrl;
    }

    await _db
        .collection('restaurant_brands')
        .doc(restaurantBrandId)
        .update(data);
  }

  Future<void> updateRestaurantBranchProfile({
    required String restaurantBrandId,
    required String restaurantId,
    String? address,
    required String phone,
    required Map<String, dynamic> openingHours,
    required int estimatedTime,
    required String imageUrl,
  }) async {
    final data = {
      'phone': phone,
      'opening_hours': openingHours,
      'estimated_time': estimatedTime,
    };

    if (address != null) {
      data['address'] = address;
    }

    if (imageUrl.isNotEmpty) {
      data['image_url'] = imageUrl;
    }

    await _db
        .collection('restaurant_brands')
        .doc(restaurantBrandId)
        .collection('restaurants')
        .doc(restaurantId)
        .update(data);
  }

  Future<String> uploadRestaurantImage({
    required File file,
    required String path,
  }) async {
    const cloudName = 'dxkoy5kdp';
    const uploadPreset = 'virtual_queue';

    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', url);

    request.fields['upload_preset'] = uploadPreset;
    request.fields['folder'] = 'restaurants';

    request.files.add(
      await http.MultipartFile.fromPath('file', file.path),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Cloudinary upload failed: $responseBody');
    }

    final data = jsonDecode(responseBody);
    return data['secure_url'];
  }

  Future<void> updateRestaurantAvailability({
    required String restaurantBrandId,
    required String restaurantId,
    required bool isActive,
  }) async {
    await _db
        .collection('restaurant_brands')
        .doc(restaurantBrandId)
        .collection('restaurants')
        .doc(restaurantId)
        .update({
      'is_active': isActive,
    });
  }

}
// restaurant_brands/{brandId}/restaurants/{restaurantId}
