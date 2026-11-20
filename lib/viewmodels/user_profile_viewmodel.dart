import '../utils/password_utils.dart';
import '../utils/phone_number_utils.dart';
// viewmodels/user_profile_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../models/user_profile.dart';
import 'package:virtual_queue/services/app_logger.dart';

class UserProfileViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = false;
  UserProfile? _cachedProfile; 
  
  // A map to hold all dynamic unmapped fields from Firestore
  Map<String, dynamic> _allFieldsMap = {}; 

  bool get isLoading => _isLoading;
  UserProfile? get cachedProfile => _cachedProfile;
  
  /// Exposes all document data keys dynamically to the form fields
  Map<String, dynamic> get allUserData => _allFieldsMap;

  UserProfileViewModel() {
    fetchRealUserData();
  }

  /// FETCH: Pulls the complete user document dynamically from Firestore
  Future<void> fetchRealUserData() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      _isLoading = true;
      notifyListeners();
      AppLogger.info(
        'UserProfileVM',
        '📥 Fetching custom profile data',
      );
      final DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final rawData = doc.data() as Map<String, dynamic>;
        
        // 1. Maintain our raw dynamic data map tracking all client metadata details
        _allFieldsMap = Map<String, dynamic>.from(rawData);

        // 2. Map standard structured details into your explicit model configuration
        _cachedProfile = UserProfile.fromMap(
          currentUser.uid, 
          rawData,
        );
        AppLogger.info(
          'UserProfileVM',
          '✅ Full user profile map parsed successfully',
        );
      } else {
        AppLogger.warning(
          'UserProfileVM',
          '⚠️ No custom profile document found in /users collection.',
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      AppLogger.error(
        'UserProfileVM',
        '❌ Error pulling profile document',
      );
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 📤 EDIT & SAVE: Commits bulk payload modifications directly back to Firestore
  Future<bool> updateCustomerProfile(Map<String, dynamic> updatedDataPayload) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    if (updatedDataPayload.containsKey('phone')) {
      final normalized = PhoneNumberUtils.tryNormalize(
        updatedDataPayload['phone']?.toString() ?? '',
      );
      if (normalized == null) return false;
      updatedDataPayload = {...updatedDataPayload, 'phone': normalized};
    }
    try {
      _isLoading = true;
      notifyListeners();

      AppLogger.info(
        'UserProfileVM',
        '📤 Saving customer profile changes to Firestore',
      );

      // 1. Update document in Firestore using merge:true to avoid clearing unselected background data values
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .set(updatedDataPayload, SetOptions(merge: true));

      // 2. Sync local variables immediately so changes appear instantly on screen
      _allFieldsMap.addAll(updatedDataPayload);
      
      // 3. Re-instantiate our clean typed model framework wrapper utilizing the new mixed runtime maps
      _cachedProfile = UserProfile.fromMap(currentUser.uid, _allFieldsMap);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error(
        'UserProfileVM',
        '❌ Failed to save edited customer details',
      );
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // --- UI Getters ---
  String get userEmail =>
      _cachedProfile?.email ??
      (_auth.currentUser?.email ?? 'guest.user@example.com');
  String get userDisplayName => _cachedProfile?.name ?? 'Queue Guest';
  String get userPhone => PhoneNumberUtils.display(
    _allFieldsMap['phone']?.toString() ?? '',
  ); // Safely exposes phone field out of raw dataset maps

  String get userJoinedDate {
    final DateTime? creationTime = _auth.currentUser?.metadata.creationTime;
    if (creationTime != null) {
      return 'Member since ${creationTime.year}';
    }
    return 'Member since 2026'; 
  }

  /// 🔐 SECURE: Updates the user's password in Firebase Auth with optional re-authentication
  /// 🔐 SECURE: Updates the user's password with clear error mapping strings
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final passwordError = PasswordUtils.validate(newPassword);
    if (passwordError != null) return passwordError;
    final User? currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.email == null) {
      return 'Session expired. Please log out and sign in again.';
    }

    try {
      _isLoading = true;
      notifyListeners();

      // 1. Re-authenticate the user immediately to guarantee active session tokens
      AuthCredential credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: currentPassword,
      );
      await currentUser.reauthenticateWithCredential(credential);

      // 2. Attempt the password update operation
      await currentUser.updatePassword(newPassword);

      // Log successful password changes without exposing sensitive user information.
      AppLogger.securityEvent(
        '🔐 User password changed successfully',
      );

      _isLoading = false;
      notifyListeners();
      return null; // Return null to indicate complete success
    } on FirebaseAuthException catch (authError) {
      _isLoading = false;
      notifyListeners();

      // Explicit error mapping categorization rules
      switch (authError.code) {
        case 'wrong-password':
          return 'The current password you entered is incorrect.';
        case 'weak-password':
          return 'Password is too weak. Please use a mix of letters and numbers.';
        case 'requires-recent-login':
          return 'Security authentication timeout. Please log out and log back in to verify your identity.';
        case 'user-disabled':
          return 'This user account has been deactivated by an administrator.';
        case 'network-request-failed':
          return 'Network error. Please verify your internet connection connection status.';
        default:
          return authError.message ??
              'An unexpected authentication error occurred.';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'System Error: Unable to complete your request at this time.';
    }
  }

  /// Clear session tokens safely
  Future<bool> logoutUser() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _auth.signOut();

      AppLogger.info(
        'UserProfileVM',
        '🚪 Erasing authenticated session state token...',
      );

      _cachedProfile = null;
      _allFieldsMap.clear();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error(
        'UserProfileVM',
        '❌ Failed to logout session',
      );
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}