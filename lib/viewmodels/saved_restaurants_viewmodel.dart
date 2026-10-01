import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/restaurant_display_state.dart';
import '../models/restaurant_model.dart';
import '../models/restaurant_brand_model.dart';
import '../models/restaurant_queue_model.dart';

class SavedRestaurantsViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🎧 LIVE STREAM: Listens to user's bookmark subcollection changes in real-time
  Stream<List<RestaurantDisplayState>> get savedRestaurantsStream {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]); // Safe fallback fallback exit route if unauthenticated
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('bookmarks')
        .snapshots()
        .asyncMap((bookmarkSnapshot) async {
          List<RestaurantDisplayState> bookmarkedCards = [];

          for (var bookmarkDoc in bookmarkSnapshot.docs) {
            try {
              final String restaurantId = bookmarkDoc.id;
              final String brandId = bookmarkDoc.data()['brand_id'] ?? '';

              if (brandId.isEmpty) continue;

              // 1. Fetch Master Brand Profile Document Data
              final brandSnap = await _firestore.collection('restaurant_brands').doc(brandId).get();
              if (!brandSnap.exists || brandSnap.data() == null) continue;
              
              // 🚀 FIXED: Explicitly cast data snapshot to avoid Dart runtime mapping exceptions
              final brandMap = brandSnap.data() as Map<String, dynamic>;
              final brandModel = RestaurantBrandModel.fromMap(brandMap);

              // 2. Fetch Branch Subcollection Specific Location Details
              final restSnap = await _firestore
                  .collection('restaurant_brands')
                  .doc(brandId)
                  .collection('restaurants')
                  .doc(restaurantId)
                  .get();
              if (!restSnap.exists || restSnap.data() == null) continue;
              
              // 🚀 FIXED: Pass explicit cast maps here too
              final restMap = restSnap.data() as Map<String, dynamic>;
              final restaurantModel = RestaurantModel.fromMap(restMap);

              final bool isActive = restMap['is_active'] ?? false;

              // 3. Fetch Live Queue Node Info Info Document Status
              final queueDoc = await _firestore.collection('queues').doc(restaurantId).get();
              RestaurantQueueModel queueModel;
              
              if (queueDoc.exists && queueDoc.data() != null) {
                final queueMap = queueDoc.data() as Map<String, dynamic>;
                queueModel = RestaurantQueueModel.fromMap(queueMap, queueDoc.id);
              } else {
                // Safe zeroed out structural initialization layout if no active queue line exists yet
                queueModel = RestaurantQueueModel.fromMap({
                  'brand_id': brandId,
                  'restaurant_id': restaurantId,
                  'current_serving': 0,
                  'next_available_number': 1,
                }, restaurantId);
              }

              final waitingTicketsSnap = await _firestore
                  .collection('queues')
                  .doc(restaurantId)
                  .collection('tickets')
                  .where('status', isEqualTo: 'WAITING')
                  .get();

              final waitingCount = waitingTicketsSnap.docs.length;

              // 4. Transform models into UI Presentation States
              final cardState = _calculateCardPresentation(
                restaurantModel,
                brandModel,
                queueModel,
                isActive,
                waitingCount,
              );
              bookmarkedCards.add(cardState);
            } catch (e) {
              debugPrint('🚨 [ViewModel Loop Exception] Processing bookmark failed: $e');
            }
          }
          return bookmarkedCards;
        });
  }

  RestaurantDisplayState _calculateCardPresentation(
    RestaurantModel restaurant,
    RestaurantBrandModel brand,
    RestaurantQueueModel queue,
    bool isActive,
    int waitingCount,
  ) {
    // Safely parse out standard data state sizes
    final int currentQueueLength = waitingCount;

    String statusString;

    if (currentQueueLength == 0) {
      statusString = 'No waiting';
    } else if (currentQueueLength <= 5) {
      statusString = 'Short Wait';
    } else if (currentQueueLength <= 10) {
      statusString = 'Moderate';
    } else {
      statusString = 'Busy';
    }

    // Map theme colors to match your view standards exactly
    Color badgeBgColor = const Color(0xFF008645); // Deep green
    if (statusString == 'Short Wait') badgeBgColor = const Color(0xFFF39850); // Warning orange
    if (statusString == 'Moderate') badgeBgColor = const Color(0xFFFF7890); // Dark pink
    if (statusString == 'Busy') badgeBgColor = const Color(0xFFBA1A1A); // Red Alert

    final String businessStateText = isActive ? 'Opening' : 'Closed';
    final Color businessStateColor = isActive ? const Color(0xFF008645) : const Color(0xFFBA1A1A);

    return RestaurantDisplayState(
      restaurant: restaurant,
      brand: brand,
      queue: queue,
      queueLength: currentQueueLength,
      badgeText: statusString,
      badgeBgColor: badgeBgColor,
      badgeTextColor: Colors.white,
      businessStatusText: businessStateText,  
      businessStatusColor: businessStateColor,
    );
  }
}