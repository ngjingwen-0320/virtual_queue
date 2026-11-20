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
  
  // A map to hold all dynamic unmapped fields from Firestore (e.g., phone, gender, birthday, points)
  Map<String, dynamic> _allFieldsMap = {}; 

  bool get isLoading => _isLoading;
  UserProfile? get cachedProfile => _cachedProfile;
  
  /// Exposes all document data keys dynamically to the form fields
  Map<String, dynamic> get allUserData => _allFieldsMap;

  UserProfileViewModel() {
    fetchRealUserData();
  }

  /// 📥 FETCH: Pulls the complete user document dynamically from Firestore
  Future<void> fetchRealUserData() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      // 📥 Track profile retrieval without recording the user's UID.
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
        // ✅ Confirm profile data was loaded without exposing its contents.
        AppLogger.info(
          'UserProfileVM',
          '✅ User profile data loaded successfully',
        );
      } else {
        // ⚠️ Record that no matching profile document was found.
        AppLogger.warning(
          'UserProfileVM',
          '⚠️ No custom profile document found in users collection',
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // ❌ Record profile retrieval errors without displaying exception details.
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

    try {
      _isLoading = true;
      notifyListeners();

      // 📤 Track profile updates without printing customer information.
      AppLogger.info(
        'UserProfileVM',
        '📤 Saving customer profile changes',
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
      // ❌ Record unsuccessful profile updates without exposing sensitive data.
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
  String get userEmail => _cachedProfile?.email ?? (_auth.currentUser?.email ?? 'guest.user@example.com');
  String get userDisplayName => _cachedProfile?.name ?? 'Queue Guest';
  String get userPhone => _allFieldsMap['phone'] ?? ''; // Safely exposes phone field out of raw dataset maps
  
  String get userJoinedDate {
    final DateTime? creationTime = _auth.currentUser?.metadata.creationTime;
    if (creationTime != null) {
      return 'Member since ${creationTime.year}';
    }
    return 'Member since 2026'; 
  }

  /// Clear session tokens safely
  Future<bool> logoutUser() async {
    try {
      _isLoading = true;
      notifyListeners();

      // 🚪 Record the start of the logout process without logging session tokens.
      AppLogger.info(
        'UserProfileVM',
        '🚪 Erasing authenticated session state',
      );
      await _auth.signOut();

      _cachedProfile = null; 
      _allFieldsMap.clear();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // ❌ Record unsuccessful logout attempts without exposing error details.
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