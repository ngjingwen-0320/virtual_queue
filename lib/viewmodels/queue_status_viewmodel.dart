// // viewmodels/queue_status_viewmodel.dart
// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import '../models/queue_status_state.dart';

// class QueueStatusViewModel {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   Future<Map<String, dynamic>?> fetchActiveUserTicket() async {
//     final String? currentUserId = _auth.currentUser?.uid;
//     if (currentUserId == null) {
//       debugPrint('⚠️ [Queue Status VM] No authenticated user detected.');
//       return null;
//     }

//     try {
//       debugPrint('🔎 [Queue Status VM] Querying active tickets for user: $currentUserId');
      
//       // Look up tickets across the root collection matching the user state
//       final querySnapshot = await _firestore
//           .collection('tickets') // Ensure this exactly matches your collection name
//           .where('user_id', isEqualTo: currentUserId)
//           .where('status', isEqualTo: 'WAITING') // Filters out cancelled or called tickets
//           .limit(1)
//           .get();

//       if (querySnapshot.docs.isNotEmpty) {
//         final doc = querySnapshot.docs.first;
//         final data = doc.data();
        
//         debugPrint('🎟️ [Queue Status VM] Active ticket found! ID: ${doc.id}');
//         return {
//           'ticketId': doc.id,
//           'restaurantId': data['restaurant_id'] ?? '',
//           'myTicketNumber': data['queue_number'] ?? 0,
//         };
//       } else {
//         debugPrint('ℹ️ [Queue Status VM] No active "WAITING" ticket discovered for this user.');
//       }
//     } catch (e) {
//       debugPrint('❌ [Queue Status VM] Error retrieving active ticket: $e');
//     }
//     return null;
//   }

//   Stream<QueueStatusState> getLiveTrackingStream({
//     required String brandId,
//     required String restaurantId,
//   }) {
//     // 1. Establish the reactive core real-time tracker
//     final queueSnapshotStream = _firestore.collection('queues').doc(restaurantId).snapshots();

//     return queueSnapshotStream.asyncMap((queueSnap) async {
//       // 2. Hydrate configuration parameters by reading master files
//       final brandSnap = await _firestore.collection('restaurant_brands').doc(brandId).get();
      
//       // 3. Drill down into the child subcollection path
//       final restSnap = await _firestore
//           .collection('restaurant_brands')
//           .doc(brandId)
//           .collection('restaurants')
//           .doc(restaurantId)
//           .get();

//       return QueueStatusState(
//         queueData: queueSnap.data() as Map<String, dynamic>? ?? {},
//         restaurantData: restSnap.data() as Map<String, dynamic>? ?? {},
//         brandData: brandSnap.data() as Map<String, dynamic>? ?? {},
//       );
//     });
//   }
// }

import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/queue_status_state.dart';
import '../services/queue_service.dart';

class QueueStatusViewModel with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final QueueService _queueService = QueueService();

  bool _isCancelling = false;
  bool get isCancelling => _isCancelling;

  // Future<Map<String, dynamic>?> fetchActiveUserTicket() async {
  //   final String? currentUserId = _auth.currentUser?.uid;
  //   if (currentUserId == null) {
  //     debugPrint('⚠️ [Queue Status VM] No authenticated user detected.');
  //     return null;
  //   }

  //   try {
  //     debugPrint('🔎 [Queue Status VM] Querying active tickets for user: $currentUserId');
      
  //     final querySnapshot = await _firestore
  //         .collection('tickets')
  //         .where('user_id', isEqualTo: currentUserId)
  //         .where('status', isEqualTo: 'WAITING')
  //         .limit(1)
  //         .get();

  //     if (querySnapshot.docs.isNotEmpty) {
  //       final doc = querySnapshot.docs.first;
  //       final data = doc.data();
        
  //       debugPrint('🎟️ [Queue Status VM] Active ticket found! ID: ${doc.id}');
  //       return {
  //         'ticketId': doc.id,
  //         'restaurantId': data['restaurant_id'] ?? '',
  //         'myTicketNumber': data['queue_number'] ?? 0,
  //       };
  //     }
  //   } catch (e) {
  //     debugPrint('❌ [Queue Status VM] Error retrieving active ticket: $e');
  //   }
  //   return null;
  // }

  /// 🔍 1. FETCH ACTIVE TICKET META ON DEMAND
  Future<Map<String, dynamic>?> fetchActiveUserTicket() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ [Queue Status VM] Aborted: No authenticated user object in state memory.');
      return null;
    }

    final String currentUserId = user.uid;
    debugPrint('🔎 [Queue Status VM] Fetching direct shortcut ticket for UID: $currentUserId');

    try {
      // Direct shortcut lookup instead of an expensive collectionGroup search
      final querySnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('active_queue')
          .where('status', whereIn: ['WAITING', 'CALLED'])
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();

        return {
          'ticketId': data['ticket_id'] ?? '',
          'restaurantId': doc.id, // The document ID is our restaurantId!
          'brandId': data['brand_id'] ?? '',
          'myTicketNumber': data['ticket_number'] ?? 0,
        };
      }
    } catch (e) {
      debugPrint('❌ [Queue Status VM] Error fetching user active_queue document: $e');
    }
    return null;
  }

  /// 🎧 2. LIVE TRACKING STREAM (AUTO-RECOVERS ON FRESH LOGIN)
  /// Instead of passing in IDs explicitly, this stream discovers who the user is waiting for automatically.
  Stream<QueueStatusState?> get liveQueueTrackingStream {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    // A. Listen in real-time to changes in the user's personal active queue shortcut
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('active_queue')
        .where('status', whereIn: ['WAITING', 'CALLED'])
        .limit(1)
        .snapshots()
        .switchMap((userShortcutSnap) {
          
          // If the user isn't holding any active tickets, emit null instantly to clear the UI
          if (userShortcutSnap.docs.isEmpty) {
            debugPrint('ℹ️ [Queue Status Stream] User has no active waiting tickets.');
            return Stream.value(null);
          }

          final shortcutData = userShortcutSnap.docs.first.data();
          final String restaurantId = userShortcutSnap.docs.first.id;
          final String brandId = shortcutData['brand_id'] ?? '';

          if (brandId.isEmpty || restaurantId.isEmpty) {
            return Stream.value(null);
          }

          debugPrint('🔗 [Queue Status Stream] User ticket found (#${shortcutData['ticket_number']}). Subscribing to live updates for restaurant: $restaurantId');

          // B. 🚀 THE REAL-TIME FIX: Listen to real-time SNAPSHOTS of the master queue document
          final Stream<DocumentSnapshot> masterQueueStream = 
              _firestore.collection('queues').doc(restaurantId).snapshots();

          // C. Map master snapshot events into your unified tracking state object as they occur
          return masterQueueStream.asyncMap((queueSnap) async {
            final masterQueueData = queueSnap.data() as Map<String, dynamic>? ?? {};

            // Combine live master counters with our persistent user ticket parameters
            final Map<String, dynamic> combinedQueueData = {
              ...masterQueueData, 
              'ticket_number': shortcutData['ticket_number'] ?? 0,
              'ticket_id': shortcutData['ticket_id'] ?? '',
              'brand_id': brandId,
              'restaurant_id': restaurantId,
              'user_ticket_status': shortcutData['status'] ?? 'WAITING',
            };

            // D. Fetch static reference blocks for copywriting strings
            final brandSnap = await _firestore.collection('restaurant_brands').doc(brandId).get();
            final restSnap = await _firestore
                .collection('restaurant_brands')
                .doc(brandId)
                .collection('restaurants')
                .doc(restaurantId)
                .get();

            final myTicketNumber = shortcutData['ticket_number'] ?? 0;

            final peopleAheadSnap = await _firestore
                .collection('queues')
                .doc(restaurantId)
                .collection('tickets')
                .where('status', isEqualTo: 'WAITING')
                .where('queue_number', isLessThan: myTicketNumber)
                .get();

            final peopleAhead = peopleAheadSnap.docs.length;

            return QueueStatusState(
              queueData: combinedQueueData,
              restaurantData: restSnap.data() as Map<String, dynamic>? ?? {},
              brandData: brandSnap.data() as Map<String, dynamic>? ?? {},
              peopleAhead: peopleAhead,
            );
          });
        });
  }

  /// ❌ ACTION ROUTE: Called when the user clicks "Cancel My Position" on the Status Screen
  Future<bool> cancelActiveTicket({
    required String restaurantId,
    required String ticketId,
  }) async {
    final user = _auth.currentUser;
    if (user == null || ticketId.isEmpty || restaurantId.isEmpty) {
      debugPrint('⚠️ [Queue Status VM] Cancel aborted: Missing session credentials or document identifiers.');
      return false;
    }

    _isCancelling = true;
    notifyListeners(); // Updates UI to show a spinner on the cancel button

    // Execute the unified atomic batch cancellation in QueueService
    final bool success = await _queueService.cancelQueueTicket(
      userId: user.uid,
      restaurantId: restaurantId,
      ticketId: ticketId,
    );

    _isCancelling = false;
    notifyListeners();
    return success;
  }
}