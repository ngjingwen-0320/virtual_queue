// viewmodels/restaurant_card_viewmodel.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/queue_service.dart';
import '../models/restaurant_detail_state.dart';
import '../services/app_logger.dart';

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
    // ⚠️ Record when no authenticated session is available.
    AppLogger.warning(
      'RestaurantCardViewModel',
      '⚠️ No authenticated session detected. Using secure temporary context.',
    );
    return "anonymous_guest_or_test_id";
  }

  Stream<RestaurantDetailState> getRestaurantDetailStream({
    required String brandId,
    required String restaurantId,
  }) {
    // 1. Listen to real-time changes on the root 'queues' document
    final queueStream = _firestore.collection('queues').doc(restaurantId).snapshots();

    return queueStream.asyncMap((queueSnap) async {
      // 📥 Track restaurant document retrieval without exposing database IDs.
      AppLogger.info(
        'RestaurantCardViewModel',
        '📥 Requesting restaurant detail documents',
      );

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
      // Record completion of the brand document lookup without listing its fields.
      AppLogger.info(
        'RestaurantCardViewModel',
        '📦 Brand document retrieval completed',
      );

      // Record completion of the restaurant subdocument lookup without exposing its contents.
      AppLogger.info(
        'RestaurantCardViewModel',
        '📦 Restaurant subdocument retrieval completed',
      );

      // Track restaurant data processing without printing the full database payload.
      AppLogger.info(
        'RestaurantCardViewModel',
        '📦 Restaurant detail payload loaded successfully',
      );

      return RestaurantDetailState(
        brandData: brandMap,
        restaurantData: restMap,
        queueData: queueMap,
        waitingCount: waitingCount,
      );
    });
  }

  Future<void> saveToBookmarks({
    required String userId,
    required String restaurantId,
    required String brandId,
  }) async {
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
      // 💾 Record successful bookmark creation after the Firestore operation.
      AppLogger.info(
        'RestaurantCardViewModel',
        '💾 Bookmark saved successfully.',
      );
    } catch (e) {
      // 🚨 Record bookmark-saving failures without exposing exception details.
      AppLogger.error(
        'RestaurantCardViewModel',
        '🚨 Failed to save bookmark.',
      );
    }
  }

  // 🗑️ Remove bookmark from user profile subcollection
  Future<void> removeFromBookmarks({
    required String userId,
    required String restaurantId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .doc(restaurantId)
          .delete();
      // 💾 Record successful bookmark removal after the Firestore operation.
      AppLogger.info(
        'RestaurantCardViewModel',
        '💾 Bookmark removed successfully.',
      );
    } catch (e) {
      // 🚨 Record bookmark-removal failures without exposing exception details.
      AppLogger.error(
        'RestaurantCardViewModel',
        '🚨 Failed to delete bookmark.',
      );
    }
  }

  Future<int?> joinQueueLine({
    required String brandId,
    required String restaurantId,
    required Map<String, dynamic> restaurantData,
    String? userId,
  }) async {
    final String targetUserId = userId ?? currentUserId;

    // 🎫 Track queue requests forwarded to QueueService without logging user IDs.
    AppLogger.info(
      'RestaurantCardViewModel',
      '🎫 Forwarding request to QueueService',
    );

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

      // 📝 Record email content preparation without exposing the restaurant details.
      AppLogger.info(
        'RestaurantCardViewModel',
        '📝 Formatted branch name prepared for email ticket',
      );

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
      // 📨 Record the start of ticket email delivery without exposing the recipient.
      AppLogger.info(
        'RestaurantCardViewModel',
        '📨 Initializing mail routing pipeline',
      );

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
        // ✅ Record successful ticket email delivery without exposing customer information.
        AppLogger.info(
          'RestaurantCardViewModel',
          '✅ Virtual queue ticket dispatched securely to user.',
        );
      } else {
        // 🚨 Record email API failures using the HTTP status without logging response bodies.
        AppLogger.warning(
          'RestaurantCardViewModel',
          '🚨 Relay rejected payload. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      // 🚨 Record email network failures without exposing raw exception information.
      AppLogger.error(
        'RestaurantCardViewModel',
        '🚨 Network request failure on mail thread.',
      );
    }
  }
}