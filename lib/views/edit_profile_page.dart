// viewmodels/user_profile_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../models/user_profile.dart'; 

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

      debugPrint('📥 [UserProfileVM] Fetching custom profile data for UID: ${currentUser.uid}');
      
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
        debugPrint('✅ [UserProfileVM] Full user profile map parsed! Data keys found: ${_allFieldsMap.keys.toList()}');
      } else {
        debugPrint('⚠️ [UserProfileVM] No custom profile document found in /users collection.');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [UserProfileVM] Error pulling profile document: $e');
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

      debugPrint('📤 [UserProfileVM] Saving customer payload data to Firestore: $updatedDataPayload');

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
      debugPrint('❌ [UserProfileVM] Failed to save edited customer details: $e');
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

      debugPrint('🚪 [UserProfileVM] Erasing authenticated session state token...');
      await _auth.signOut();

      _cachedProfile = null; 
      _allFieldsMap.clear();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ [UserProfileVM] Failed to logout session: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}