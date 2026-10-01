import 'package:flutter/material.dart';
import '../models/restaurant_display_state.dart';
import '../viewmodels/customer_home_viewmodel.dart';
import 'restaurant_card_page.dart'; 
import 'queue_status_page.dart'; 
import 'user_profile_view.dart';
import 'customer_reservation_page.dart';

class CustomerHomeView extends StatefulWidget {
  const CustomerHomeView({super.key});

  @override
  State<CustomerHomeView> createState() => _CustomerHomeViewState();
}

class _CustomerHomeViewState extends State<CustomerHomeView> {
  int _currentIndex = 0; // Tracks active structural page selection

  String? activeRestaurantId;
  int? activeTicketNumber;

  // 🔄 Callback helper to handle state transitions cleanly
  void _updateQueueState(String restId, int ticketNum) {
    setState(() {
      activeRestaurantId = restId;
      activeTicketNumber = ticketNum;
      _currentIndex = 1; // Auto-route user straight to the active Queue tab
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🛠️ FIX: We keep the tabs structure inside a dynamically evaluated array 
    // but pass live state down explicitly every build run.
    final List<Widget> structuralTabs = [
      ExploreTabContent(onQueueRegisteredInChild: _updateQueueState),
      
      // The Queue View block now remains consistently tracked by the underlying engine
      _buildQueueTabContent(),
      // const QueueStatusPage(),
          
      const CustomerReservationPage(),
      const UserProfileView(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFB),
      
      body: SafeArea(
        // Disable the top SafeArea for the Reservations tab (index 2)
        top: _currentIndex != 2,
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: structuralTabs, // 👈 Consuming the stable stack structures
        ),
      ),

      // 📌 FIXED BOTTOM DOCK NAVIGATION BAR
      bottomNavigationBar: Container(
        width: double.infinity,
        height: 88,
        decoration: BoxDecoration(
          color: const Color(0xF8F8FAFC).withOpacity(0.8),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D134E4A),
              blurRadius: 50,
              offset: Offset(0, -5), 
            )
          ],
        ),
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavButton(0, Icons.storefront_rounded, "Explore"),
            _buildNavButton(1, Icons.confirmation_num_rounded, "Queue"),
            _buildNavButton(2, Icons.calendar_today_rounded, "Reservation"),
            _buildNavButton(3, Icons.person_rounded, "Profile"),
          ],
        ),
      ),
    );
  }

  // 🛠️ CRITICAL FIX: Separates structural initialization from render conditions
  Widget _buildQueueTabContent() {
    // If the home view already has the variables in memory, pass them down immediately
    if (activeTicketNumber != null && activeRestaurantId != null) {
      return QueueStatusPage(
        key: ValueKey(activeTicketNumber), 
        restaurantId: activeRestaurantId!,
        myTicketNumber: activeTicketNumber!,
        ticketId: '',
      );
    }
    
    // 🚀 THE RESCUE PATHWAY: If variables are null on fresh login, 
    // STILL return the QueueStatusPage so its internal fallback engine can fetch the active ticket!
    return const QueueStatusPage(
      restaurantId: null,
      myTicketNumber: null,
      ticketId: null,
    );
  }

  Widget _buildNavButton(int index, IconData icon, String label) {
    final bool isActive = _currentIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: isActive 
            ? BoxDecoration(
                color: const Color(0xFFF0FDFA), 
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon, 
              color: isActive ? const Color(0xFF115E59) : const Color(0xFF64748B), 
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? const Color(0xFF115E59) : const Color(0xFF64748B),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 🌐 SUB-WIDGET COMPONENT: EXPLORE FEED SCROLL VIEW
// =========================================================================
class ExploreTabContent extends StatefulWidget {
  // ✅ FIXED: Constructor now accepts the parameter pass-through handler
  final Function(String restaurantId, int ticketNumber) onQueueRegisteredInChild;

  const ExploreTabContent({
    super.key,
    required this.onQueueRegisteredInChild,
  });

  @override
  State<ExploreTabContent> createState() => _ExploreTabContentState();
}

class _ExploreTabContentState extends State<ExploreTabContent> {
  final CustomerHomeViewModel _viewModel = CustomerHomeViewModel();
  final TextEditingController _searchController = TextEditingController();

  // List<RestaurantDisplayState> _allRestaurants = [];
  // List<RestaurantDisplayState> _filteredRestaurants = [];
  // bool _isSearching = false;

  final ValueNotifier<bool> _isSearchingNotifier = ValueNotifier<bool>(false);
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final String text = _searchController.text;
      _viewModel.updateSearchQuery(text);
      _isSearchingNotifier.value = text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _isSearchingNotifier.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  // String? _selectedCategory;

  // 🚀 SEARCH FILTER ENGINE
  // void _onSearchChanged() {
  //   final String query = _searchController.text.trim().toLowerCase();

  //   if (query.isEmpty) {
  //     setState(() {
  //       _isSearching = false;
  //       _filteredRestaurants = List.from(_allRestaurants);
  //     });
  //     return;
  //   }

  //   setState(() {
  //     _isSearching = true;
  //     _filteredRestaurants = _allRestaurants.where((restaurantItem) {
  //       // Extracting values
  //       final String name = (restaurantItem.brand.name ?? '').toLowerCase();
  //       final String cuisine = (restaurantItem.brand.cuisine ?? '').toLowerCase();
  //       final String branch = (restaurantItem.restaurant.branchName ?? '').toLowerCase();
        
  //       // 🖨️ THE DIAGNOSTIC LOG: This prints the exact strings the app is searching through!
  //       // debugPrint('🔎 [SEARCHING] User Typed: "$query"');
  //       // debugPrint('   ├── Brand Name found in Model: "$name"');
  //       // debugPrint('   ├── Cuisine Type found in Model: "$cuisine"');
  //       // debugPrint('   └── Branch Name found in Model: "$branch"');

  //       return name.contains(query) || cuisine.contains(query) || branch.contains(query);
  //     }).toList();
  //   });
  // }

  String _formatOpeningHours(Map<String, dynamic> openingHours) {
    if (openingHours.isEmpty) {
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
      final dayKey = entry.key;
      final dayLabel = entry.value;
      final dayData = openingHours[dayKey];

      if (dayData is! Map) continue;

      final isOpen = dayData['is_open'] == true;
      final open = dayData['open'] ?? '';
      final close = dayData['close'] ?? '';

      if (!isOpen) {
        lines.add('$dayLabel: Closed');
      } else {
        lines.add('$dayLabel: $open - $close');
      }
    }

    if (lines.isEmpty) {
      return 'Opening hours not set';
    }

    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFB),
      
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        toolbarHeight: 72,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.menu_rounded, color: Color.fromARGB(0, 17, 94, 89), size: 24),
                onPressed: () {},
              ),
              const Text(
                'VQ',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF134E4A),
                  letterSpacing: -0.6,
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E9EA),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x1A006670), width: 2),
                ),
                child: const Icon(Icons.person, color: Colors.grey),
              )
            ],
          ),
        ),
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchSection(),
            const SizedBox(height: 32),
            _buildCategoriesSection(),
            const SizedBox(height: 12),
            const Text(
              'Restaurants',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Color(0xFF134E4A),
                letterSpacing: -0.75,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Popular entry queues nearby',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF3E494B),
              ),
            ),
            const SizedBox(height: 24),

            // StreamBuilder<List<RestaurantDisplayState>>(
            //   stream: _viewModel.restaurantCardsStream,
            //   builder: (context, snapshot) {
            //     if (snapshot.connectionState == ConnectionState.waiting) {
            //       return const Center(
            //         child: Padding(
            //           padding: EdgeInsets.only(top: 40.0),
            //           child: CircularProgressIndicator(color: Color(0xFF006670)),
            //         ),
            //       );
            //     }
            //     if (!snapshot.hasData || snapshot.data!.isEmpty) {
            //       return _buildEmptyState();
            //     }

            //     _allRestaurants = snapshot.data!;
            //     if (!_isSearching) {
            //       _filteredRestaurants = List.from(_allRestaurants);
            //     }

            //     if (_filteredRestaurants.isEmpty) {
            //       return Center(
            //         child: Padding(
            //           padding: const EdgeInsets.only(top: 40.0),
            //           child: Text(
            //             'No matching locations found.',
            //             style: TextStyle(fontFamily: 'Plus Jakarta Sans', color: Colors.grey[600]),
            //           ),
            //         ),
            //       );
            //     }

            //     return ListView.builder(
            //       shrinkWrap: true,
            //       physics: const NeverScrollableScrollPhysics(),
            //       itemCount: _filteredRestaurants.length,
            //       itemBuilder: (context, index) {
            //         final restaurantItem = _filteredRestaurants[index];
            //         return GestureDetector(
            //           onTap: () async {
            //             final returnedResult = await Navigator.push(
            //               context,
            //               MaterialPageRoute(
            //                 builder: (context) => RestaurantCardPage(
            //                   brandId: restaurantItem.queue.brandId ?? '',       
            //                   restaurantId: restaurantItem.queue.restaurantId ?? '', 
            //                 ),
            //               ),
            //             );

            //             if (returnedResult != null && returnedResult is int) {
            //               widget.onQueueRegisteredInChild(
            //                 restaurantItem.queue.restaurantId ?? '',
            //                 returnedResult,
            //               );
            //             }
            //           },
            //           child: _buildRestaurantCard(context, restaurantItem),
            //         );
            //       },
            //     );
            //   },
            // ),

            // 🎯 THE LIVE COMBINED-FILTER FEED (Handled cleanly via business layer)
            StreamBuilder<List<RestaurantDisplayState>>(
              stream: _viewModel.restaurantCardsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40.0),
                      child: CircularProgressIndicator(color: Color(0xFF006670)),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40.0),
                      child: Text(
                        'No matching restaurants found.',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans', 
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600]
                        ),
                      ),
                    ),
                  );
                }

                final List<RestaurantDisplayState> displayCards = snapshot.data!;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayCards.length,
                  itemBuilder: (context, index) {
                    final restaurantItem = displayCards[index];
                    return GestureDetector(
                      onTap: () async {
                        final returnedResult = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RestaurantCardPage(
                              brandId: restaurantItem.queue.brandId ?? '',       
                              restaurantId: restaurantItem.queue.restaurantId ?? '', 
                            ),
                          ),
                        );

                        if (returnedResult != null && returnedResult is int) {
                          widget.onQueueRegisteredInChild(
                            restaurantItem.queue.restaurantId ?? '',
                            returnedResult,
                          );
                        }
                      },
                      child: _buildRestaurantCard(context, restaurantItem),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      height: 55,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFDFE3E4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search for restaurants, cuisines...',
          hintStyle: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF3E494B),
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6E797B), size: 18),
          suffixIcon: ValueListenableBuilder<bool>(
            valueListenable: _isSearchingNotifier,
            builder: (context, isSearching, child) {
              return isSearching
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF3E494B), size: 18),
                      onPressed: () {
                        _searchController.clear();
                        FocusScope.of(context).unfocus();
                      },
                    )
                  : const Icon(Icons.tune_rounded, color: Color(0xFF006670), size: 18);
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final categories = [
      {'label': 'Western', 'icon': Icons.restaurant_rounded},
      {'label': 'Sushi', 'icon': Icons.rice_bowl_rounded},
      {'label': 'Burgers', 'icon': Icons.lunch_dining_rounded},
      {'label': 'Beverages', 'icon': Icons.coffee_rounded},
      {'label': 'Local', 'icon': Icons.dinner_dining_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Categories',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF171C1D),
                letterSpacing: -0.5,
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = null;
                });
                _viewModel.applyCuisineFilter(null);
              },
              child: const Text(
                'See all',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF006670),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 104, 
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final String currentLabel = categories[index]['label'] as String;
              final bool isSelected = _selectedCategory == currentLabel;

              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedCategory = null; 
                      } else {
                        _selectedCategory = currentLabel; 
                      }
                      _viewModel.applyCuisineFilter(_selectedCategory);
                    });
                  },
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF006670) : const Color(0xFFF0F4F5),
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected 
                              ? Border.all(color: const Color(0xFF006670), width: 1)
                              : Border.all(color: Colors.transparent, width: 1),
                        ),
                        child: Icon(
                          categories[index]['icon'] as IconData,
                          color: isSelected ? Colors.white : const Color(0xFF006670),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentLabel,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? const Color(0xFF006670) : const Color(0xFF3E494B),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantCard(BuildContext context, RestaurantDisplayState cardState) {
    final String liveImageUrl = cardState.restaurant.imageUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), 
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000), 
            blurRadius: 15,
            spreadRadius: -3,
            offset: Offset(0, 10),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RestaurantCardPage(
                brandId: cardState.queue.brandId,
                restaurantId: cardState.queue.restaurantId,
              ),
            ),
          ).then((assignedNumber) {
            // ✅ FIXED: Using the native Flutter route completion engine framework!
            // When the card detail view is popped off the screen stack, if it passes back an int ticket,
            // we relay that data back up using our callback.
            if (assignedNumber != null && assignedNumber is int) {
              
              widget.onQueueRegisteredInChild(
                cardState.queue.restaurantId,
                assignedNumber,
              );
            }
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
           // 🖼️ LIVE FIREBASE NETWORK IMAGE VIEWPORT HOUSING
            SizedBox(
              height: 213.75, 
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: liveImageUrl.isNotEmpty
                        ? Image.network(
                            liveImageUrl,
                            fit: BoxFit.cover,
                            // ⏳ Loading placeholder while fetching bytes from Cloudinary CDN
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
                            // 🚨 Fallback vector layer if link expires or network breaks
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
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0x66000000), Color(0x00000000)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cardState.badgeBgColor,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        cardState.badgeText,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cardState.badgeTextColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cardState.brand.name} (${cardState.restaurant.branchName})', 
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 20, 
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF171C1D),
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  
                  Row(
                    children: [
                      const Icon(Icons.restaurant_menu_rounded, color: Color(0xFF6E797B), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        cardState.brand.cuisine.isNotEmpty ? cardState.brand.cuisine : 'Local',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6E797B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),                  
                  
                  const Divider(height: 24, thickness: 1, color: Color(0xFFEDF2F4)),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded, 
                              color: cardState.businessStatusColor, // 🎨 Dynamic: Green if open, Red if closed
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 130, 
                              child: Text(
                                cardState.businessStatusText, // 🎯 Displays exactly "Opening" or "Closed"
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: cardState.businessStatusColor, // 🎨 Dynamic matching text color
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start, // Align icon cleanly with the top line of text
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 3.0), // Precision alignment for the icon vector
                            child: const Icon(
                              Icons.people_alt_outlined, 
                              color: Color(0xFF006670), 
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8), // Clean spacing separation from icon to text block
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${cardState.queueLength}',
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 20, // Increased size to make the primary data metric stand out
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF006670),
                                  height: 1.0, // Forces the font container box to fit the character bounds tightly
                                  leadingDistribution: TextLeadingDistribution.even,
                                ),
                              ),
                              const SizedBox(height: 4), // Controlled margin gap preventing vertical collision
                              const Text(
                                'tables waiting',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6E797B), // Slate color creates visual hierarchy against the bold number
                                  height: 1.0,
                                  leadingDistribution: TextLeadingDistribution.even,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40.0),
        child: Column(
          children: [
            Icon(Icons.restaurant_menu_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'No registered restaurants found.',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6E797B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}