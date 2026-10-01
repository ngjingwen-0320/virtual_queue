import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/restaurant_display_state.dart';
import '../models/restaurant_model.dart';
import '../models/restaurant_brand_model.dart';
import '../models/restaurant_queue_model.dart';

class CustomerHomeViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🎯 Track both the Category Selection AND Text Search Inputs
  final BehaviorSubject<String?> _filterSubject = BehaviorSubject<String?>.seeded(null);
  final BehaviorSubject<String> _searchQuerySubject = BehaviorSubject<String>.seeded('');

  // UI inputs hook here
  void applyCuisineFilter(String? cuisine) {
    debugPrint('⚡ [ViewModel] UI requested category change to: "$cuisine"');
    _filterSubject.add(cuisine); 
  }

  void updateSearchQuery(String query) {
    _searchQuerySubject.add(query);
  }

  /// 🎧 UNIFIED REAL-TIME STREAM PIPELINE: Reacts to text queries, category choices, and DB edits!
  Stream<List<RestaurantDisplayState>> get restaurantCardsStream {
    return Rx.combineLatest3<String?, String, QuerySnapshot, Stream<List<RestaurantDisplayState>>>(
      _filterSubject.stream,
      _searchQuerySubject.stream,
      _firestore.collection('restaurant_brands').snapshots(),
      (activeCuisine, activeSearchText, brandSnapshot) {
        return Stream.fromFuture(_fetchAndFilterDisplayStates(activeCuisine, activeSearchText, brandSnapshot));
      },
    ).flatMap((stream) => stream);
  }

  /// Deep pipeline data hydrator and filtering processor
  Future<List<RestaurantDisplayState>> _fetchAndFilterDisplayStates(
    String? activeCuisineFilter, 
    String searchText,
    QuerySnapshot brandSnapshot,
  ) async {
    List<RestaurantDisplayState> displayCards = [];
    final String cleanSearchText = searchText.trim().toLowerCase();

    for (var brandDoc in brandSnapshot.docs) {
      try {
        final brandData = brandDoc.data() as Map<String, dynamic>;
        final brandModel = RestaurantBrandModel.fromMap(brandData);
        final String brandId = brandDoc.id;

        // 🎯 1. CUISINE CATEGORY FILTER ENGINE
        if (activeCuisineFilter != null) {
          final String dbCuisine = (brandData['cuisine'] ?? '').toString().trim().toLowerCase();
          final String selectedCuisine = activeCuisineFilter.trim().toLowerCase();
          if (dbCuisine != selectedCuisine) continue; 
        }

        // Fetch children restaurant branches
        Query restaurantCollectionRef = _firestore
            .collection('restaurant_brands')
            .doc(brandId)
            .collection('restaurants');

        final restaurantQuery = await restaurantCollectionRef.get();

        for (var restaurantDoc in restaurantQuery.docs) {
          final String restaurantId = restaurantDoc.id;
          final restaurantRawData = restaurantDoc.data() as Map<String, dynamic>;
          // final restaurantModel = RestaurantModel.fromMap(restaurantDoc.data() as Map<String, dynamic>);
          final restaurantModel = RestaurantModel.fromMap(restaurantRawData);

          final bool isActive = restaurantRawData['is_active'] ?? false;

          // 🎯 2. REAL-TIME TEXT SEARCH FILTERING
          // Verifies if the user's query string maps to either the brand title or cuisine categorization tag strings
          if (cleanSearchText.isNotEmpty) {
            final String brandName = (brandModel.name ?? '').isNotEmpty 
                ? brandModel.name!.toLowerCase() 
                : (brandData['name'] ?? brandData['brand_id'] ?? '').toString().toLowerCase();
            final String cuisineType = (brandModel.cuisine ?? '').toLowerCase();
            final String branchName = (restaurantModel.branchName ?? '').toLowerCase(); // Fallback if applicable

            final bool matchesSearch = brandName.contains(cleanSearchText) || 
                                       cuisineType.contains(cleanSearchText) ||
                                       branchName.contains(cleanSearchText);
            
            if (!matchesSearch) continue; // Skip card item entry mapping loops
          }

          // 🟢 3. FETCH LIVE QUEUES
          final queueDoc = await _firestore.collection('queues').doc(restaurantId).get();

          final waitingTicketsSnap = await _firestore
              .collection('queues')
              .doc(restaurantId)
              .collection('tickets')
              .where('status', isEqualTo: 'WAITING')
              .get();

          final waitingCount = waitingTicketsSnap.docs.length;

          RestaurantQueueModel queueModel;
          if (queueDoc.exists) {
            queueModel = RestaurantQueueModel.fromMap(queueDoc.data()!, queueDoc.id);
          } else {
            queueModel = RestaurantQueueModel.fromMap({
              'brand_id': brandId,
              'restaurant_id': restaurantId,
              'current_serving': 0,
              'next_available_number': 1,
            }, restaurantId);
          }

          final cardState = _calculateCardPresentation(
            restaurantModel,
            brandModel,
            queueModel,
            isActive,
            waitingCount,
          );

          displayCards.add(cardState);
        }
      } catch (e) {
        debugPrint('🚨 Processing engine subcollection pipeline failure: $e');
      }
    }
    return displayCards;
  }

  RestaurantDisplayState _calculateCardPresentation(
    RestaurantModel restaurant,
    RestaurantBrandModel brand,
    RestaurantQueueModel queue,
    bool isActive,
    int waitingCount,
  ) {
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

    Color badgeBgColor = const Color(0xFF008645); 
    if (statusString == 'Short Wait') badgeBgColor = const Color(0xFFF39850); 
    if (statusString == 'Moderate') badgeBgColor = const Color(0xFFFF7890); 
    if (statusString == 'Busy') badgeBgColor = const Color(0xFFBA1A1A); 

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

  void dispose() {
    _filterSubject.close();
    _searchQuerySubject.close();
  }
}