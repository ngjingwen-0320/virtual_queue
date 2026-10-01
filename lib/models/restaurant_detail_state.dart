import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RestaurantDetailState {
  final Map<String, dynamic> brandData;
  final Map<String, dynamic> restaurantData;
  final Map<String, dynamic> queueData;
  final int waitingCount;

  RestaurantDetailState({
    required this.brandData,
    required this.restaurantData,
    required this.queueData,
    required this.waitingCount,
  });

  int get queueLength {
    return waitingCount;
  }

  String get badgeText {
    if (queueLength == 0) return 'No waiting';
    if (queueLength <= 5) return 'Short wait';
    if (queueLength <= 10) return 'Moderate';
    return 'Busy';
  }

  Color get badgeBgColor {
    if (queueLength == 0) return const Color(0xFF008645);
    if (queueLength <= 5) return const Color(0xFFF39850);
    if (queueLength <= 10) return const Color(0xFFFF7890);
    return const Color(0xFFBA1A1A);
  }

  String get businessStatusText {
    final bool isActive = restaurantData['is_active'] ?? false;
    return isActive ? 'Opening' : 'Closed';
  }
}