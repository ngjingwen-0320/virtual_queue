import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

// Talk to Firebase
class AuthService {

  // used for login
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // used for read Firestore data
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserProfile?> login(String email, String password) async {

      final result = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
      );

      final user = result.user;
      if (user == null) return null;

      final doc = await _db.collection('users').doc(user.uid).get();
      if(!doc.exists || doc.data() == null){
        return null;
      }

      return UserProfile.fromMap(user.uid, doc.data()!);
  }

  Future<UserProfile?> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password
    );

    final user = result.user;
    if (user == null) return null;

    await _db.collection('users').doc(user.uid).set({
      'created_at': FieldValue.serverTimestamp(),
      'email': email,
      'name': name,
      'phone': phone,
      'role': 'customer',
    });

    return UserProfile(
      uid: user.uid,
      email: email,
      name: name,
      role: 'customer',
      restaurantIds: [],
    );
  }

  Future<UserProfile?> registerRestaurant({
    required String restaurantName,
    required String businessRegistrationNo,
    required String ownerName,
    required String ownerEmail,
    required String ownerPhone,
    required String password,
    required List<Map<String, String>> branches,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: ownerEmail,
      password: password,
    );

    final user = result.user;
    if (user == null) return null;

    final brandId = restaurantName.toLowerCase().replaceAll(' ', '_');
    final brandRef = _db.collection('restaurant_brands').doc(brandId);

    await brandRef.set({
      'created_at': FieldValue.serverTimestamp(),
      'name': restaurantName,
      'business_registration_no': businessRegistrationNo,
      'branch_count': branches.length,
      'owner_id': user.uid,
      'cuisine': '',
      'about': '',
    });

    final restaurantIds = <String>[];

    for (final branch in branches) {
      final branchName = branch['branch_name'] ?? '';
      final branchId = branches.length == 1
          ? brandId
          : '${brandId}_${branchName.toLowerCase().replaceAll(' ', '_')}';
      final restaurantRef = brandRef.collection('restaurants').doc(branchId);
      restaurantIds.add(restaurantRef.id);

      await restaurantRef.set({
        'created_at': FieldValue.serverTimestamp(),
        'branch_name': branchName,
        'address': branch['address'],
        'brand_id': brandRef.id,
        'owner_id': user.uid,
        'phone': ownerPhone,
        'estimated_time': 0,
        'is_active': true,
        'opening_hours': {},
      });
    }

    await _db.collection('users').doc(user.uid).set({
      'created_at': FieldValue.serverTimestamp(),
      'email': ownerEmail,
      'name': ownerName,
      'owner_phone': ownerPhone,
      'role': 'restaurant',
      'brand_id': brandRef.id,
      'restaurant_ids': restaurantIds,
    });

    return UserProfile(
      uid: user.uid,
      email: ownerEmail,
      name: ownerName,
      role: 'restaurant',
      restaurantIds: restaurantIds,
      restaurantBrandId: brandRef.id,
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

}