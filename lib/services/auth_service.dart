import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import 'otp_email_service.dart';

// Talk to Firebase
class AuthService {

  // used for login
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // used for read Firestore data
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final OtpEmailService _otpEmailService = OtpEmailService();

  String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<Map<String, String>> sendLoginOtp(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = result.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Authentication failed.',
      );
    }

    await user.reload();
    final updatedUser = _auth.currentUser;

    if (updatedUser == null || !updatedUser.emailVerified) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'email-not-verified',
        message: 'Please verify your email address before logging in.',
      );
    }

    // Generate 6-digit OTP and set 5-minute expiry
    final otp = _generateOtp();
    final now = DateTime.now();
    final expiryTime = now.add(const Duration(minutes: 5));

    // 1. Save OTP document to Firestore `otps` collection
    final otpRef = _db.collection('otps').doc(updatedUser.uid);
    await otpRef.set({
      'otp': otp,
      'created_at': Timestamp.fromDate(now),
      'expires_at': Timestamp.fromDate(expiryTime),
      'email': updatedUser.email,
      'attempts': 0,
    });

    // 2. Dispatch OTP email directly via EmailJS
    final bool emailSent = await _otpEmailService.sendOtpEmail(
      userEmail: updatedUser.email ?? email,
      otpCode: otp,
    );

    // 3. Sign out temporary Firebase Auth session
    await _auth.signOut();

    if (!emailSent) {
      throw FirebaseAuthException(
        code: 'email-send-failed',
        message: 'Failed to send OTP email. Please try again.',
      );
    }

    return {
      'uid': updatedUser.uid,
      'email': updatedUser.email ?? email,
    };
  }

  Future<UserProfile?> verifyOtpAndLogin({
    required String uid,
    required String email,
    required String password,
    required String enteredOtp,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = result.user;
    if (user == null) return null;

    final otpDocRef = _db.collection('otps').doc(user.uid);

    try {
      final otpDoc = await otpDocRef.get();

      if (!otpDoc.exists || otpDoc.data() == null) {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'otp-not-found',
          message: 'No OTP request found. Please request a new code.',
        );
      }

      final data = otpDoc.data()!;
      final String storedOtp = data['otp'] ?? '';
      final Timestamp? expiresAtTimestamp = data['expires_at'] as Timestamp?;
      final int attempts = data['attempts'] ?? 0;

      if (attempts >= 5) {
        await otpDocRef.delete();
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'too-many-attempts',
          message: 'Maximum OTP attempts exceeded. Please request a new code.',
        );
      }

      if (expiresAtTimestamp == null || DateTime.now().isAfter(expiresAtTimestamp.toDate())) {
        await otpDocRef.delete();
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'otp-expired',
          message: 'OTP has expired. Please request a new OTP.',
        );
      }

      if (storedOtp != enteredOtp.trim()) {
        await otpDocRef.update({'attempts': FieldValue.increment(1)});
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'invalid-otp',
          message: 'Incorrect OTP entered. Access denied.',
        );
      }

      await otpDocRef.delete();

      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return UserProfile.fromMap(user.uid, doc.data()!);
    } catch (e) {
      if (_auth.currentUser != null && e is FirebaseAuthException) {
        await _auth.signOut();
      }
      rethrow;
    }
  }

  // Future<UserProfile?> login(String email, String password) async {

  //     final result = await _auth.signInWithEmailAndPassword(
  //         email: email,
  //         password: password,
  //     );

  //     final user = result.user;
  //     if (user == null) return null;

  //     await user.reload();
  //     final updatedUser = _auth.currentUser;

  //     if (updatedUser == null || !updatedUser.emailVerified) {
  //       await _auth.signOut();
  //       throw FirebaseAuthException(
  //         code: 'email-not-verified',
  //         message: 'Please verify your email address before logging in.',
  //       );
  //     }

  //     // final doc = await _db.collection('users').doc(user.uid).get();
  //     final doc = await _db.collection('users').doc(updatedUser.uid).get();
  //     if(!doc.exists || doc.data() == null){
  //       return null;
  //     }

  //     // return UserProfile.fromMap(user.uid, doc.data()!);
  //     return UserProfile.fromMap(updatedUser.uid, doc.data()!);
  // }

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

    await user.sendEmailVerification();

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

    await user.sendEmailVerification();

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

  // Future<void> resendVerificationEmail() async {
  //   final user = _auth.currentUser;
  //   if (user != null && !user.emailVerified) {
  //     await user.sendEmailVerification();
  //   }
  // }

  Future<void> resendVerificationEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = result.user;
    if (user != null) {
      await user.sendEmailVerification();
      await _auth.signOut();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

}