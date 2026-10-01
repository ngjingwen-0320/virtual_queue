class RestaurantBrandModel {
  final String name;
  final String cuisine;
  final String about;
  final String logoUrl;

  RestaurantBrandModel({
    required this.name,
    required this.cuisine,
    required this.about,
    required this.logoUrl,
  });

  factory RestaurantBrandModel.fromMap(Map<String, dynamic> data) {
    return RestaurantBrandModel(
      name: data['name'] ?? '',
      cuisine: data['cuisine'] ?? '',
      about: data['about'] ?? '',
      logoUrl: data['logo_url'] ?? '',
    );
  }
}