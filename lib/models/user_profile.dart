class UserProfile {
  final String uid;
  final String email;
  final String name;
  final String role;
  final List<String> restaurantIds;
  final String? restaurantBrandId;

  UserProfile({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.restaurantIds,
    this.restaurantBrandId,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
        uid: uid,
        email: data['email'] ?? '',
        name: data['name'] ?? '',
        role: data['role'] ?? 'customer',
        restaurantIds: List<String>.from(data['restaurant_ids'] ?? []),
        restaurantBrandId: data['brand_id'],
    );
  }

  // check if it is restaurant
  bool get isRestaurant => role == 'restaurant';
  // check if it is customer
  bool get isCustomer => role == 'customer';


  String? get firstRestaurantId {
    if(restaurantIds.isEmpty) return null;
    return restaurantIds.first;
  }
}