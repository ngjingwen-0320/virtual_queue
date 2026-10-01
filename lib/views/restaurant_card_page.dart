import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../viewmodels/restaurant_card_viewmodel.dart';
import '../models/restaurant_detail_state.dart';
import 'queue_status_page.dart';
import '../services/queue_service.dart';
import 'reservation_booking_page.dart';

class RestaurantCardPage extends StatefulWidget {
  final String brandId;       
  final String restaurantId; 
  final String? imageUrl; 

  const RestaurantCardPage({
    super.key,
    required this.brandId,
    required this.restaurantId,
    this.imageUrl,
  });

  @override
  State<RestaurantCardPage> createState() => _RestaurantCardPageState();
}

class _RestaurantCardPageState extends State<RestaurantCardPage> {
  final RestaurantCardViewModel _viewModel = RestaurantCardViewModel();
  bool _isLoading = false;
  bool _isBookmarked = false; // Tracks if the restaurant is saved
  
  // TODO: Replace with your actual authenticated user session state
  // final String _userId = "test_customer_123"; 

  @override
  void initState() {
    super.initState();
    // ⏳ Trigger database read as soon as the widget context initializes
    _checkIfBookmarkedInitialState();
  }

  // 🎯 Fetch the real authenticated User ID string from the active session
  String? getRealUserId() {
    final User? user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      debugPrint('ℹ️ [Auth Session] Active User verified: ${user.uid}');
      return user.uid; // 🚀 This is your real, distinct Firestore document key string!
    } else {
      debugPrint('⚠️ [Auth Warning] No user is logged in right now.');
      return null;
    }
  }


  void _checkIfBookmarkedInitialState() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return; // Exit early if anonymous/logged out

    final String realUserId = currentUser.uid;
    
    final docSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(realUserId)
        .collection('bookmarks')
        .doc(widget.restaurantId)
        .get();

    if (mounted && docSnapshot.exists) {
      setState(() {
        _isBookmarked = true;
      });
    }
  }

  void _handleJoinQueue(Map<String, dynamic> restaurantData) async {
    if (_isLoading) return; 

    final String? realUserId = getRealUserId();
    if (realUserId == null) {
      _showErrorDialog('You must be signed in to join an active queue line.');
      return;
    }

    setState(() => _isLoading = true);
    debugPrint('🚀 [Queue System] Attempting to join line...');
    
    try {
      int? assignedNumber = await _viewModel.joinQueueLine(
        brandId: widget.brandId,
        restaurantId: widget.restaurantId,
        restaurantData: restaurantData,
        userId: realUserId,
      );
      
      setState(() => _isLoading = false);

      if (assignedNumber != null && mounted) {
        debugPrint('🎟️ [Queue Success] Ticket #$assignedNumber secured. Sending to Home state...');
        
        // Close the card page and send the assigned number back to the Home View
        Navigator.pop(context, assignedNumber);
      } else {
        if (mounted) {
          _showErrorDialog('Queue is currently closed or configuration error.');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;

      // Convert the error payload cleanly to a readable string format
      final String errorMessage = e.toString();

      // 🚀 THE FIX: Differentiate between validation guardrails and network dropouts
      if (errorMessage.contains('You cannot join a new queue')) {
        // Strip out the "Exception: " prefix cleanly for a premium UI look
        final String cleanWarning = errorMessage.replaceAll('Exception: ', '');
        _showErrorDialog(cleanWarning);
      } else {
        // Fallback for real Firebase/Firestore infrastructure connection failures
        _showErrorDialog('Database connection error: $errorMessage');
      }
    }
  }

  String _formatOpeningHours(dynamic openingHours) {
    if (openingHours is! Map || openingHours.isEmpty) {
      return 'Operating Hours Not Available';
    }

    final dayLabels = {
      'monday': 'Mon',
      'tuesday': 'Tue',
      'wednesday': 'Wed',
      'thursday': 'Thu',
      'friday': 'Fri',
      'saturday': 'Sat',
      'sunday': 'Sun',
    };

    final lines = <String>[];

    for (final entry in dayLabels.entries) {
      final dayData = openingHours[entry.key];

      if (dayData is! Map) continue;

      final isOpen = dayData['is_open'] == true;
      final open = dayData['open'] ?? '';
      final close = dayData['close'] ?? '';

      if (!isOpen) {
        lines.add('${entry.value}: Closed');
      } else {
        lines.add('${entry.value}: $open - $close');
      }
    }

    return lines.isEmpty ? 'Hours Not Available' : lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFB),
      // Wrap the entire body in the unified ViewModel stream to dynamically load metadata
      body: StreamBuilder<RestaurantDetailState>(
        stream: _viewModel.getRestaurantDetailStream(
          brandId: widget.brandId,
          restaurantId: widget.restaurantId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF006670)),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                'Failed to load restaurant details.',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', color: Colors.grey[600]),
              ),
            );
          }

          final state = snapshot.data!;

          // Extract database fields with clean fallbacks if properties are unpopulated
          final String brandName = state.brandData['name'] ?? 'Loading Restaurant...';
          final String branchName = state.restaurantData['branch_name'] ?? '';
          final String cuisineText = state.brandData['cuisine'] ?? 'Local Cuisine';
          final openingHoursData = state.restaurantData['opening_hours'];
          final String openingHours = _formatOpeningHours(openingHoursData);
          final String addressText = state.restaurantData['address'] ?? 'No Address Listed';
          final String phoneText = state.restaurantData['phone'] ?? 'No Contact Phone';
          final String descriptionText = state.brandData['about'] ?? 'No description provided.';
          
          // final String assetName = brandName.replaceAll(' ', '_');
          final String imageUrl = state.restaurantData['image_url'] ?? '';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: Container(
                width: 440,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(color: Color(0xFFF6FAFB)),
                child: Column( 
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    
                    // 1. DYNAMIC HERO IMAGE SECTION
                   SizedBox(
                      height: 431,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl, // 🚀 Powered entirely by real-time Stream data pipeline
                                  fit: BoxFit.cover,
                                  // ⏳ Loading placeholder layer while fetching data from the Cloudinary CDN
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: const Color(0xFFECEFF1),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF006670),
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                                  // 🚨 Fallback asset if connection times out or link fails
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      'assets/images/Restaurant_Icon.png',
                                      fit: BoxFit.cover,
                                    );
                                  },
                                )
                              : Image.asset(
                                  'assets/images/Restaurant_Icon.png',
                                  fit: BoxFit.cover,
                                ),
                          ),

                          // HEADER GRADIENT TINT SHIELD OVERLAY
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Color(0xFFF6FAFB), Color(0x00F6FAFB), Color(0x33000000)],
                                  stops: [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          ),

                          // HEADER BACK & SAVE ACTIONS
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 6,
                            left: 16,
                            right: 16,
                            child: SizedBox(
                              height: 48,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: _buildBlurCircleButton(Icons.arrow_back),
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      // 🚀 STEP 1: Dynamically grab the real authentication user unique ID
                                      final User? currentUser = FirebaseAuth.instance.currentUser;

                                      if (currentUser == null) {
                                        // 🔒 Safety Fallback: Prompt the user to log in if their token expired
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please log in to save your favorite restaurants!')),
                                        );
                                        return;
                                      }

                                      final String realUserId = currentUser.uid; // Your real user ID string (e.g., "f0tM4CtbFiP...")

                                      setState(() {
                                        _isBookmarked = !_isBookmarked; // Toggle visual state immediately
                                      });

                                      // 🚀 STEP 2: Execute your Firestore transaction mutations securely
                                      if (_isBookmarked) {
                                        debugPrint('📌 Saving to profile path: users/$realUserId/bookmarks/${widget.restaurantId}');
                                        await _viewModel.saveToBookmarks(
                                          userId: realUserId,
                                          restaurantId: widget.restaurantId,
                                          brandId: widget.brandId,
                                        );
                                        
                                        // 💎 Professional Success Snackbar
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).clearSnackBars();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              behavior: SnackBarBehavior.floating,
                                              backgroundColor: const Color(0xFF064E3B), // Premium Deep Teal
                                              margin: const EdgeInsets.all(16),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              duration: const Duration(seconds: 2),
                                              content: const Row(
                                                children: [
                                                  Icon(Icons.bookmark_added_rounded, color: Colors.white, size: 20),
                                                  SizedBox(width: 12),
                                                  Text(
                                                    'Saved restaurant!',
                                                    style: TextStyle(
                                                      fontFamily: 'Plus Jakarta Sans',
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        debugPrint('🗑️ Removing from profile path: users/$realUserId/bookmarks/${widget.restaurantId}');
                                        await _viewModel.removeFromBookmarks(
                                          userId: realUserId,
                                          restaurantId: widget.restaurantId,
                                        );
                                        
                                        // 💎 Professional Removal Snackbar
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).clearSnackBars();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              behavior: SnackBarBehavior.floating,
                                              backgroundColor: const Color(0xFF334155), // Clean Slate Gray
                                              margin: const EdgeInsets.all(16),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              duration: const Duration(seconds: 2),
                                              content: const Row(
                                                children: [
                                                  Icon(Icons.bookmark_remove_rounded, color: Colors.white, size: 20),
                                                  SizedBox(width: 12),
                                                  Text(
                                                    'Unsaved restaurant',
                                                    style: TextStyle(
                                                      fontFamily: 'Plus Jakarta Sans',
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: _buildBlurCircleButton(
                                      _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. MAIN CANVAS SHEET
                    Transform.translate(
                      offset: const Offset(0, -82), 
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0D171C1D), 
                                blurRadius: 50,
                                offset: Offset(0, 25),
                              )
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min, 
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                
                                // BRAND TITLE & CALCULATED WAIT STATUS BADGE
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            branchName.isNotEmpty ? '$brandName ($branchName)' : brandName,
                                            style: const TextStyle(
                                              fontFamily: 'Plus Jakarta Sans',
                                              fontSize: 34,
                                              fontWeight: FontWeight.w800, 
                                              color: Color(0xFF171C1D),
                                              height: 38 / 34,
                                              letterSpacing: -0.9,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300), 
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: state.badgeBgColor,
                                        borderRadius: BorderRadius.circular(9999),
                                      ),
                                      child: Text(
                                        state.badgeText,
                                        style: const TextStyle(
                                          fontFamily: 'Plus Jakarta Sans',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800, 
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // DYNAMIC DATABASE METADATA FIELDS
                                _buildMetaRow(Icons.restaurant_menu, cuisineText),
                                const SizedBox(height: 12),
                                _buildMetaRow(Icons.access_time, openingHours),
                                const SizedBox(height: 12),
                                _buildMetaRow(Icons.location_on_outlined, addressText),
                                const SizedBox(height: 12),
                                _buildMetaRow(Icons.phone_in_talk_outlined, phoneText),
                                
                                const SizedBox(height: 24),

                                // BENTO METRIC DISPLAY GRID
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildBentoNode(
                                        title: 'CURRENT SERVING',
                                        value: '#${state.queueData['current_serving'] ?? 0}',
                                        themeColor: const Color(0xFF006670),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildBentoNode(
                                        title: 'QUEUE LENGTH',
                                        value: '${state.queueLength} tables',
                                        themeColor: const Color(0xFF006A35),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                // ACTION CALLS
                                SizedBox(
                                  width: double.infinity, 
                                  height: 68,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF006670), 
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 0,
                                    ),
                                    // 🎯 DISABLE GATEKEEPER: Disable button if loading OR if the restaurant is closed
                                    onPressed: (_isLoading || state.businessStatusText == 'Closed') 
                                      ? null 
                                      : () => _handleJoinQueue(state.restaurantData),
                                    icon: _isLoading 
                                      ? const SizedBox.shrink()
                                      : const Icon(Icons.confirmation_num_outlined, color: Colors.white, size: 20),
                                    label: _isLoading 
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : Text(
                                          // 📝 Dynamic text variation to match the disabled state if you want!
                                          state.businessStatusText == 'Closed' ? 'Restaurant Closed' : 'Join Queue Line',
                                          style: const TextStyle(
                                            fontFamily: 'Plus Jakarta Sans',
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                  ),
                                ),
                                
                                const SizedBox(height: 16),

                                SizedBox(
                                  width: double.infinity,
                                  height: 68,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFCBE7F5), // your existing color
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),

                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ReservationBookingPage(
                                            restaurantId: widget.restaurantId,
                                            brandId: widget.brandId,
                                            restaurantName: branchName.isNotEmpty
                                                ? '$brandName - $branchName'
                                                : brandName,
                                          ),
                                        ),
                                      );
                                    },

                                    icon: const Icon(
                                      Icons.restaurant_menu_outlined,
                                      color: Colors.black87,
                                      size: 20,
                                    ),

                                    label: const Text(
                                      'Book a Table',
                                      style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // ABOUT SECTION
                                const Text(
                                  'About',
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF171C1D),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  descriptionText,
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF3E494B),
                                    height: 26 / 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Refactored Bento Node Component Builder
  Widget _buildBentoNode({required String title, required String value, required Color themeColor}) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F5),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: themeColor, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: themeColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Color(0xFF171C1D),
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurCircleButton(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildMetaRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6E797B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF6E797B),
            ),
          ),
        ),
      ],
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Queue Failure'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }
}