import 'package:flutter/material.dart';
import 'restaurant_model.dart';
import 'restaurant_brand_model.dart';
import 'restaurant_queue_model.dart';

class RestaurantDisplayState {
  final RestaurantModel restaurant;
  final RestaurantBrandModel brand;
  final RestaurantQueueModel queue; 
  final int queueLength;
  final String badgeText;
  final Color badgeBgColor;
  final Color badgeTextColor;
  final String businessStatusText;
  final Color businessStatusColor;

  RestaurantDisplayState({
    required this.restaurant,
    required this.brand,
    required this.queue,
    required this.queueLength,
    required this.badgeText,
    required this.badgeBgColor,
    required this.badgeTextColor,
    required this.businessStatusText,  
    required this.businessStatusColor,
  });
}