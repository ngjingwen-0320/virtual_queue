// viewmodels/restaurant_card_viewmodel.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // Required for debugPrint
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/queue_service.dart';
import '../models/restaurant_detail_state.dart';

class RestaurantCardViewModel {
  final QueueService _queueService = QueueService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId {
    final User? firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      return firebaseUser.uid; // ✅ Returns actual Firestore uid matching your AuthService setup
    }
    
    // Fail-safe protective tracking fallback for local debugging profiles
    debugPrint('⚠️ [VM Session Alert] No authenticated session detected. Using secure temporary context.');
    return "anonymous_guest_or_test_id"; 
  }

  Stream<RestaurantDetailState> getRestaurantDetailStream({
    required String brandId,
    required String restaurantId,
  }) {
    // 1. Listen to real-time changes on the root 'queues' document
    final queueStream = _firestore.collection('queues').doc(restaurantId).snapshots();

    return queueStream.asyncMap((queueSnap) async {
      debugPrint('📥 [VM Query] Requesting Documents ➔ Brand ID: "$brandId" | Restaurant ID: "$restaurantId"');

      // 2. Fetch the parent brand document from root collection
      final brandSnap = await _firestore.collection('restaurant_brands').doc(brandId).get();
      
      // 3. ✅ FIXED: Walk down the subcollection path to fetch the specific restaurant branch
      final restSnap = await _firestore
          .collection('restaurant_brands')
          .doc(brandId)
          .collection('restaurants')
          .doc(restaurantId)
          .get();

      final brandMap = brandSnap.data() as Map<String, dynamic>? ?? {};
      final restMap = restSnap.data() as Map<String, dynamic>? ?? {};
      final queueMap = queueSnap.data() as Map<String, dynamic>? ?? {};

      final waitingTicketsSnap = await _firestore
          .collection('queues')
          .doc(restaurantId)
          .collection('tickets')
          .where('status', isEqualTo: 'WAITING')
          .get();

      final waitingCount = waitingTicketsSnap.docs.length;

      // 🔍 Debug logs to verify structural sync is succeeding
      debugPrint('📦 [VM Payload Result] Brands Doc Exists: ${brandSnap.exists} -> Keys: ${brandMap.keys.toList()}');
      debugPrint('📦 [VM Payload Result] Restaurants Subdoc Exists: ${restSnap.exists} -> Keys: ${restMap.keys.toList()}');
      debugPrint('📦 [VM Payload Result] Full Restaurant Map Content: $restMap');

      return RestaurantDetailState(
        brandData: brandMap,
        restaurantData: restMap,
        queueData: queueMap,
        waitingCount: waitingCount,
      );
    });
  }

  Future<void> saveToBookmarks({required String userId, required String restaurantId, required String brandId}) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .doc(restaurantId) // Store using restaurantId as document ID to make checks incredibly easy
          .set({
            'restaurant_id': restaurantId,
            'brand_id': brandId,
            'saved_at': FieldValue.serverTimestamp(),
          });
      debugPrint('💾 [Firestore] Bookmark saved successfully.');
    } catch (e) {
      debugPrint('🚨 [Firestore Error] Failed to save bookmark: $e');
    }
  }

  // 🗑️ Remove bookmark from user profile subcollection
  Future<void> removeFromBookmarks({required String userId, required String restaurantId}) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .doc(restaurantId)
          .delete();
      debugPrint('💾 [Firestore] Bookmark removed successfully.');
    } catch (e) {
      debugPrint('🚨 [Firestore Error] Failed to delete bookmark: $e');
    }
  }

  Future<int?> joinQueueLine({
    required String brandId,
    required String restaurantId,
    required Map<String, dynamic> restaurantData,
    String? userId,
  }) async {
    final String targetUserId = userId ?? currentUserId;

    debugPrint('🎫 [VM Queue Request] Forwarding request to QueueService for User: $targetUserId');

    // return await _queueService.joinQueue(
    //   brandId: brandId,
    //   restaurantId: restaurantId,
    //   userId: targetUserId,
    // );
    final int? queueNumberResult = await _queueService.joinQueue(
      brandId: brandId,
      restaurantId: restaurantId,
      userId: targetUserId,
    );

    // 2. 🚀 Trigger the email ticket immediately if the join database action succeeds
    if (queueNumberResult != null) {
      // Safely fetch user data fields out of your session model mapping profile
      final String userEmail = _auth.currentUser?.email ?? 'customer@example.com'; 
      // final String branchName = restaurantData['branch_name'] ?? 'Our Branch';

      // 🔍 STEP 1: Fetch the parent brand document to pull the top-level "name" 
      final brandSnap = await _firestore.collection('restaurant_brands').doc(brandId).get();
      final String brandName = brandSnap.data()?['name'] ?? 'Restaurant';

      // 🔍 STEP 2: Pull the specific branch location string from your passed parameter map
      final String branchNameOnly = restaurantData['branch_name'] ?? 'Our Branch';

      // 🤝 STEP 3: String interpolation to join them exactly as requested
      final String fullFormattedBranchName = "$brandName ($branchNameOnly)";

      debugPrint('📝 [Email System] Combined Output String: "$fullFormattedBranchName"');

      // Fire and forget in the background so the UI doesn't stutter or freeze up waiting
      unawaited(_sendEmailTicket(
        userEmail: userEmail,
        branchName: fullFormattedBranchName,
        queueNumber: queueNumberResult.toString(),
      ));
    }

    return queueNumberResult;
  }

  Future<void> _sendEmailTicket({
    required String userEmail,
    required String branchName,
    required String queueNumber,
  }) async {
    const String serviceId = "service_otndmwn";
    const String templateId = "template_v790uff";
    const String publicKey = "m0-pjpXqF0pD4BpH4";

    try {
      debugPrint('📨 [Email API] Initializing mail routing pipeline to: $userEmail');
      
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'http://localhost', // Required parameter by the EmailJS verification network
        },
        body: json.encode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': publicKey,
          'template_params': {
            'user_email': userEmail,
            'branch_name': branchName,
            'queue_number': queueNumber,
            'issue_time': DateTime.now().toString().split('.')[0], 
          }
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ [Email API Success] Virtual queue ticket dispatched securely to user.');
      } else {
        debugPrint('🚨 [Email API Warning] Relay rejected payload. Status: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('🚨 [Email API Error] Network request failure on mail thread: $e');
    }
  }
}