class RestaurantModel {
  final String branchName;
  final String brandId;
  final String address;
  final Map<String, dynamic> openingHours;
  final String phone;
  final int estimatedTime;
  final bool isActive;
  final String imageUrl;

  RestaurantModel({
    required this.branchName,
    required this.brandId,
    required this.address,
    required this.openingHours,
    required this.phone,
    required this.estimatedTime,
    required this.isActive,
    required this.imageUrl,
  });

  factory RestaurantModel.fromMap(Map<String, dynamic> data) {
    return RestaurantModel(
      branchName: data['branch_name'] ?? '',
      brandId: data['brand_id'] ?? '',
      address: data['address'] ?? '',
      openingHours: Map<String, dynamic>.from(data['opening_hours'] ?? {}),
      phone: data['phone'] ?? '',
      estimatedTime: data['estimated_time'] ?? 0,
      isActive: data['is_active'] ?? false,
      imageUrl: data['image_url'] ?? '',
    );
  }
}
