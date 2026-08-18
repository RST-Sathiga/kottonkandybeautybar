import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'booking_page.dart';
import 'client_chat_system.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  // ==========================================================
  // FIREBASE
  // ============================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // COLOURS
  // ============================================================

  static const Color primaryPurple = Color(0xFF6B3A82);
  static const Color fieldPurple = Color(0xFF9156A1);
  static const Color lightPurple = Color(0xFFF3EAF6);

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _searchController =
  TextEditingController();

  // ============================================================
  // VARIABLES
  // ============================================================

  int _selectedIndex = 0;
  bool _isLoading = false;

  // ============================================================
  // CART
  // ============================================================

  final List<Map<String, dynamic>> _cart = [];

  // ============================================================
  // FAVOURITES
  // ============================================================

  final Set<String> _favourites = {};

  // ============================================================
  // YOUR ORIGINAL PRODUCTS
  // ============================================================

  final List<Map<String, dynamic>> _sampleServices = [
    // ------------------------------------------------------------
    // HAIR CARE PRODUCTS
    // ------------------------------------------------------------

    {
      'id': 'aki_shampoo',
      'name': 'Aki Asili Clarifying Shampoo',
      'category': 'Hair',
      'description':
      'Deep cleansing shampoo formulated to eliminate build-up.',
      'price': 150.00,
      'duration': 'Product',
      'isProduct': true,
      'icon': Icons.water_drop,
      'image': 'assets/images/shampoo.jpeg',
    },

    {
      'id': 'hair_spray',
      'name': 'Aki Asili Hair Spray',
      'category': 'Hair',
      'description':
      'Lightweight hold spray to lock in styles and reduce frizz.',
      'price': 90.00,
      'duration': 'Product',
      'isProduct': true,
      'icon': Icons.air,
      'image': 'assets/images/hair_spary.jpeg',
    },

    {
      'id': 'creamy_hair_food',
      'name': 'Aki Asili Creamy Hair Food',
      'category': 'Hair',
      'description':
      'Nourishing formula that seals in moisture and adds shine.',
      'price': 120.00,
      'duration': 'Product',
      'isProduct': true,
      'icon': Icons.spa,
      'image': 'assets/images/creamy_hair_food.jpeg',
    },

    {
      'id': 'protein_conditioner',
      'name': 'Aki Asili Protein Conditioner',
      'category': 'Hair',
      'description':
      'Restorative treatment to strengthen and repair damaged hair.',
      'price': 180.00,
      'duration': 'Product',
      'isProduct': true,
      'icon': Icons.sanitizer,
      'image': 'assets/images/protien_conditioner.jpeg',
    },

    // ------------------------------------------------------------
    // PRESS-ON NAILS
    // ------------------------------------------------------------

    {
      'id': 'french_tip_nails',
      'name': 'Classic French Tip Press-Ons',
      'category': 'Nails',
      'description':
      'Elegant and timeless French tip press-on nails with adhesive.',
      'price': 150.00,
      'duration': 'Product',
      'isProduct': true,
      'icon': Icons.back_hand,
      'image': 'assets/images/nails.jpeg',
    },

    {
      'id': 'matte_nude_nails',
      'name': 'Matte Nude Press-On Nails',
      'category': 'Nails',
      'description':
      'Sophisticated matte nude finish for everyday wear.',
      'price': 130.00,
      'duration': 'Product',
      'isProduct': true,
      'icon': Icons.back_hand,
      'image': 'assets/images/matte_nails.jpeg',
    },
  ];

  // ============================================================
  // USER
  // ============================================================

  User? get _currentUser => _auth.currentUser;

  String get _userName {
    final String? displayName = _currentUser?.displayName;

    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.split(' ').first;
    }

    final String? email = _currentUser?.email;

    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return 'User';
  }

  // ============================================================
  // INIT / DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // FILTER PRODUCTS
  // ============================================================

  List<Map<String, dynamic>> get _filteredServices {
    final String search =
    _searchController.text.trim().toLowerCase();

    return _sampleServices.where((service) {
      final String name =
      service['name'].toString().toLowerCase();

      final String description =
      service['description'].toString().toLowerCase();

      final String category =
      service['category'].toString().toLowerCase();

      return search.isEmpty ||
          name.contains(search) ||
          description.contains(search) ||
          category.contains(search);
    }).toList();
  }

  // ============================================================
  // SHOW MESSAGE
  // ============================================================

  void _showMessage(
      String message, {
        bool isError = true,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Colors.red.shade700
              : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ============================================================
  // ADD TO CART
  // ============================================================

  void _addToCart(Map<String, dynamic> service) {
    final String id = service['id'].toString();

    final int existingIndex = _cart.indexWhere(
          (item) =>
      item['id'] == id &&
          item['name'] == service['name'],
    );

    if (existingIndex >= 0) {
      _cart[existingIndex]['quantity'] =
          (_cart[existingIndex]['quantity'] as int) + 1;
    } else {
      _cart.add({
        ...service,
        'quantity': 1,
      });
    }

    setState(() {});

    _showMessage(
      '${service['name']} added to cart.',
      isError: false,
    );
  }

  // ============================================================
  // REMOVE FROM CART
  // ============================================================

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  // ============================================================
  // CART TOTAL
  // ============================================================

  double get _cartTotal {
    double total = 0;

    for (final item in _cart) {
      final double price =
      (item['price'] as num).toDouble();

      final int quantity =
      item['quantity'] as int;

      total += price * quantity;
    }

    return total;
  }

  // ============================================================
  // CART COUNT
  // ============================================================

  int get _cartItemCount {
    int count = 0;

    for (final item in _cart) {
      count += item['quantity'] as int;
    }

    return count;
  }

  // ============================================================
  // FAVOURITES
  // ============================================================

  void _toggleFavourite(String id) {
    setState(() {
      if (_favourites.contains(id)) {
        _favourites.remove(id);
      } else {
        _favourites.add(id);
      }
    });
  }

  // ============================================================
  // BOOKING PAGE
  // ============================================================

  void _openBookingPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BookingPage(),
      ),
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    final bool? confirmed =
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to log out?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('LOGOUT'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _auth.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
          (route) => false,
    );
  }

  // ============================================================
  // PRODUCT DETAILS
  // ============================================================

  void _showServiceDetails(
      Map<String, dynamic> service,
      ) {
    final bool isNails =
        service['category'] == 'Nails';

    final String? imagePath =
    service['image'];

    bool includeInstallation = false;

    final double basePrice =
    (service['price'] as num).toDouble();

    const double installationFee = 50.00;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (
              context,
              setModalState,
              ) {
            final double currentTotal =
                basePrice +
                    (includeInstallation && isNails
                        ? installationFee
                        : 0);

            return Container(
              padding:
              const EdgeInsets.all(24),
              decoration:
              const BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 45,
                          height: 5,
                          decoration:
                          BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius:
                            BorderRadius.circular(
                              10,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // PRODUCT IMAGE
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration:
                        BoxDecoration(
                          color: lightPurple,
                          borderRadius:
                          BorderRadius.circular(
                            20,
                          ),
                          image: imagePath != null
                              ? DecorationImage(
                            image: AssetImage(
                              imagePath,
                            ),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: imagePath != null
                            ? null
                            : Icon(
                          service['icon']
                          as IconData,
                          size: 65,
                          color:
                          primaryPurple,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        service['name']
                            .toString(),
                        style:
                        const TextStyle(
                          fontSize: 24,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        service['description']
                            .toString(),
                        style: TextStyle(
                          fontSize: 15,
                          color:
                          Colors.grey[700],
                        ),
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          const Icon(
                            Icons.category_outlined,
                            color:
                            primaryPurple,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Text(
                            service['category']
                                .toString(),
                            style:
                            const TextStyle(
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'R${currentTotal.toStringAsFixed(2)}',
                            style:
                            const TextStyle(
                              fontSize: 20,
                              fontWeight:
                              FontWeight.bold,
                              color:
                              primaryPurple,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          const Icon(
                            Icons.inventory_2,
                            color:
                            primaryPurple,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Text(
                            service['duration']
                                .toString(),
                          ),
                        ],
                      ),

                      // PRESS-ON INSTALLATION
                      if (isNails) ...[
                        const SizedBox(height: 15),

                        CheckboxListTile(
                          title: const Text(
                            'Include Salon Installation (+R50.00)',
                            style:
                            TextStyle(
                              fontWeight:
                              FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle:
                          const Text(
                            'Have our professionals install your press-ons at the salon.',
                          ),
                          value:
                          includeInstallation,
                          activeColor:
                          primaryPurple,
                          contentPadding:
                          EdgeInsets.zero,
                          onChanged: (value) {
                            setModalState(() {
                              includeInstallation =
                                  value ?? false;
                            });
                          },
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ADD TO CART
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(
                              context,
                            );

                            final Map<
                                String,
                                dynamic>
                            modifiedService = {
                              ...service,
                              'price':
                              currentTotal,
                              'name':
                              includeInstallation &&
                                  isNails
                                  ? '${service['name']} (+ Installation)'
                                  : service['name'],
                            };

                            _addToCart(
                              modifiedService,
                            );
                          },
                          icon: const Icon(
                            Icons.shopping_bag_outlined,
                          ),
                          label: const Text(
                            'ADD TO CART',
                            style:
                            TextStyle(
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                          style:
                          ElevatedButton
                              .styleFrom(
                            backgroundColor:
                            primaryPurple,
                            foregroundColor:
                            Colors.white,
                            shape:
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius
                                  .circular(
                                16,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // FAVOURITE
                      SizedBox(
                        width: double.infinity,
                        child:
                        TextButton.icon(
                          onPressed: () {
                            _toggleFavourite(
                              service['id']
                                  .toString(),
                            );

                            Navigator.pop(
                              context,
                            );
                          },
                          icon: Icon(
                            _favourites.contains(
                              service['id']
                                  .toString(),
                            )
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Colors.red,
                          ),
                          label: Text(
                            _favourites.contains(
                              service['id']
                                  .toString(),
                            )
                                ? 'Remove from favourites'
                                : 'Add to favourites',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // HOME DASHBOARD
  // ============================================================

  Widget _buildDashboard() {
    return RefreshIndicator(
      color: primaryPurple,
      onRefresh: () async {
        await Future.delayed(
          const Duration(milliseconds: 400),
        );

        if (mounted) {
          setState(() {});
        }
      },
      child: CustomScrollView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ======================================================
          // APP BAR
          // ======================================================

          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: Colors.white,
            elevation: 0,
            titleSpacing: 20,
            title: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $_userName!',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                Text(
                  'Find authentic Aki Asili products & press-on nails',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () {
                  _showMessage(
                    'No new notifications.',
                    isError: false,
                  );
                },
                icon: const Icon(
                  Icons.notifications_none,
                  color: Colors.black87,
                ),
              ),
              _buildCartButton(),
              const SizedBox(width: 10),
            ],
          ),

          // ======================================================
          // CONTENT
          // ======================================================

          SliverPadding(
            padding:
            const EdgeInsets.fromLTRB(
              20,
              15,
              20,
              30,
            ),
            sliver: SliverList(
              delegate:
              SliverChildListDelegate(
                [
                  // SEARCH
                  Container(
                    decoration:
                    BoxDecoration(
                      color:
                      Colors.grey[100],
                      borderRadius:
                      BorderRadius.circular(
                        18,
                      ),
                    ),
                    child: TextField(
                      controller:
                      _searchController,
                      onChanged: (value) {
                        setState(() {});
                      },
                      decoration:
                      InputDecoration(
                        hintText:
                        'Search products...',
                        prefixIcon:
                        const Icon(
                          Icons.search,
                          color:
                          primaryPurple,
                        ),
                        suffixIcon:
                        _searchController
                            .text
                            .isNotEmpty
                            ? IconButton(
                          icon:
                          const Icon(
                            Icons.clear,
                          ),
                          onPressed:
                              () {
                            _searchController
                                .clear();

                            setState(
                                  () {},
                            );
                          },
                        )
                            : null,
                        border:
                        InputBorder.none,
                        contentPadding:
                        const EdgeInsets
                            .symmetric(
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // =================================================
                  // BANNER
                  // =================================================

                  Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.all(
                      22,
                    ),
                    decoration:
                    BoxDecoration(
                      gradient:
                      const LinearGradient(
                        colors: [
                          Color(0xFF6B3A82),
                          Color(0xFF9156A1),
                        ],
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        24,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              const Text(
                                'BEAUTY & GLORY,\nALL IN ONE.',
                                style:
                                TextStyle(
                                  color:
                                  Colors.white,
                                  fontSize: 22,
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                ),
                              ),

                              const SizedBox(
                                height: 8,
                              ),

                              const Text(
                                'Shop professional hair care and press-on nails.',
                                style:
                                TextStyle(
                                  color:
                                  Colors.white70,
                                  fontSize: 13,
                                ),
                              ),

                              const SizedBox(
                                height: 15,
                              ),

                              // =================================================
                              // CHANGED ONLY:
                              // SHOP NOW -> BOOK NOW
                              // =================================================

                              ElevatedButton.icon(
                                onPressed:
                                _openBookingPage,
                                icon:
                                const Icon(
                                  Icons
                                      .calendar_month,
                                ),
                                style:
                                ElevatedButton
                                    .styleFrom(
                                  backgroundColor:
                                  Colors.white,
                                  foregroundColor:
                                  primaryPurple,
                                  shape:
                                  RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius
                                        .circular(
                                      15,
                                    ),
                                  ),
                                ),
                                label:
                                const Text(
                                  'BOOK NOW',
                                  style:
                                  TextStyle(
                                    fontWeight:
                                    FontWeight
                                        .bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        const Icon(
                          Icons.spa,
                          color:
                          Colors.white54,
                          size: 80,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // =================================================
                  // PRODUCTS
                  // =================================================

                  _buildSectionTitle(
                    'Products',
                  ),

                  const SizedBox(height: 14),

                  if (_filteredServices
                      .isEmpty)
                    _buildEmptyState()
                  else
                    ..._filteredServices.map(
                          (service) => Padding(
                        padding:
                        const EdgeInsets
                            .only(
                          bottom: 14,
                        ),
                        child:
                        _buildServiceCard(
                          service,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(
      String title, {
        VoidCallback? onTap,
      }) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight:
            FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const Spacer(),
        if (onTap != null)
          TextButton(
            onPressed: onTap,
            child: const Text(
              'View All',
              style: TextStyle(
                color: primaryPurple,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // PRODUCT CARD
  // ============================================================

  Widget _buildServiceCard(
      Map<String, dynamic> service,
      ) {
    final String id =
    service['id'].toString();

    final bool favourite =
    _favourites.contains(id);

    final String? imagePath =
    service['image'];

    return GestureDetector(
      onTap: () =>
          _showServiceDetails(service),
      child: Container(
        padding:
        const EdgeInsets.all(14),
        decoration:
        BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(
            20,
          ),
          boxShadow: [
            BoxShadow(
              color:
              Colors.black.withValues(
                alpha: 0.07,
              ),
              blurRadius: 10,
              offset:
              const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // IMAGE
            Container(
              width: 82,
              height: 82,
              decoration:
              BoxDecoration(
                color: lightPurple,
                borderRadius:
                BorderRadius.circular(
                  16,
                ),
                image: imagePath != null
                    ? DecorationImage(
                  image: AssetImage(
                    imagePath,
                  ),
                  fit: BoxFit.cover,
                )
                    : null,
              ),
              child: imagePath != null
                  ? null
                  : Icon(
                service['icon']
                as IconData,
                color:
                primaryPurple,
                size: 40,
              ),
            ),

            const SizedBox(width: 14),

            // DETAILS
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    service['name']
                        .toString(),
                    maxLines: 1,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style:
                    const TextStyle(
                      fontSize: 16,
                      fontWeight:
                      FontWeight.bold,
                      color:
                      Colors.black,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    service[
                    'description']
                        .toString(),
                    maxLines: 2,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                      Colors.grey[600],
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Row(
                    children: [
                      const Icon(
                        Icons.inventory_2,
                        size: 14,
                        color:
                        primaryPurple,
                      ),

                      const SizedBox(
                        width: 4,
                      ),

                      Text(
                        service[
                        'duration']
                            .toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors
                              .grey[700],
                        ),
                      ),

                      const Spacer(),

                      Text(
                        'R${(service['price'] as num).toStringAsFixed(2)}',
                        style:
                        const TextStyle(
                          color:
                          primaryPurple,
                          fontWeight:
                          FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // FAVOURITE + ADD
            Column(
              children: [
                IconButton(
                  onPressed: () =>
                      _toggleFavourite(
                        id,
                      ),
                  icon: Icon(
                    favourite
                        ? Icons.favorite
                        : Icons
                        .favorite_border,
                    color: favourite
                        ? Colors.red
                        : Colors.grey,
                  ),
                ),

                Container(
                  decoration:
                  BoxDecoration(
                    color:
                    primaryPurple,
                    borderRadius:
                    BorderRadius
                        .circular(
                      10,
                    ),
                  ),
                  child: IconButton(
                    onPressed: () =>
                        _showServiceDetails(
                          service,
                        ),
                    icon:
                    const Icon(
                      Icons.add,
                      color:
                      Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(35),
      decoration:
      BoxDecoration(
        color: lightPurple,
        borderRadius:
        BorderRadius.circular(
          20,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off,
            color:
            primaryPurple,
            size: 50,
          ),

          const SizedBox(
            height: 12,
          ),

          const Text(
            'No products found',
            style:
            TextStyle(
              fontSize: 18,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            'Try another search term.',
            textAlign:
            TextAlign.center,
            style: TextStyle(
              color:
              Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CART BUTTON
  // ============================================================

  Widget _buildCartButton() {
    return Stack(
      alignment:
      Alignment.center,
      children: [
        IconButton(
          onPressed:
          _openCart,
          icon: const Icon(
            Icons
                .shopping_bag_outlined,
            color:
            Colors.black87,
          ),
        ),

        if (_cartItemCount > 0)
          Positioned(
            right: 4,
            top: 5,
            child: Container(
              padding:
              const EdgeInsets
                  .all(4),
              decoration:
              const BoxDecoration(
                color: Colors.red,
                shape:
                BoxShape.circle,
              ),
              child: Text(
                _cartItemCount
                    .toString(),
                style:
                const TextStyle(
                  color:
                  Colors.white,
                  fontSize: 9,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // CART
  // ============================================================

  void _openCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
      Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (
              context,
              setModalState,
              ) {
            return Container(
              height:
              MediaQuery.of(context)
                  .size
                  .height *
                  0.80,
              padding:
              const EdgeInsets.all(
                20,
              ),
              decoration:
              const BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.vertical(
                  top: Radius.circular(
                    28,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 45,
                    height: 5,
                    decoration:
                    BoxDecoration(
                      color:
                      Colors.grey[300],
                      borderRadius:
                      BorderRadius
                          .circular(
                        10,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Row(
                    children: [
                      const Text(
                        'Your Cart',
                        style:
                        TextStyle(
                          fontSize: 24,
                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),

                      const Spacer(),

                      Text(
                        '$_cartItemCount items',
                        style:
                        TextStyle(
                          color:
                          Colors.grey[
                          600],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Expanded(
                    child: _cart.isEmpty
                        ? _buildEmptyCart()
                        : ListView
                        .separated(
                      itemCount:
                      _cart.length,
                      separatorBuilder:
                          (
                          context,
                          index,
                          ) =>
                      const Divider(),
                      itemBuilder:
                          (
                          context,
                          index,
                          ) {
                        final item =
                        _cart[
                        index];

                        final String?
                        imagePath =
                        item[
                        'image'];

                        return ListTile(
                          leading:
                          Container(
                            width: 50,
                            height: 50,
                            decoration:
                            BoxDecoration(
                              color:
                              lightPurple,
                              borderRadius:
                              BorderRadius.circular(
                                10,
                              ),
                              image: imagePath !=
                                  null
                                  ? DecorationImage(
                                image:
                                AssetImage(
                                  imagePath,
                                ),
                                fit: BoxFit
                                    .cover,
                              )
                                  : null,
                            ),
                            child: imagePath !=
                                null
                                ? null
                                : Icon(
                              item[
                              'icon'],
                              color:
                              primaryPurple,
                            ),
                          ),
                          title:
                          Text(
                            item[
                            'name'],
                            style:
                            const TextStyle(
                              fontWeight:
                              FontWeight
                                  .bold,
                            ),
                          ),
                          subtitle:
                          Text(
                            'R${(item['price'] as num).toStringAsFixed(2)} × ${item['quantity']}',
                          ),
                          trailing:
                          IconButton(
                            icon:
                            const Icon(
                              Icons
                                  .delete_outline,
                              color:
                              Colors.red,
                            ),
                            onPressed:
                                () {
                              _removeFromCart(
                                index,
                              );
                              setModalState(
                                    () {},
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  if (_cart.isNotEmpty)
                    Column(
                      children: [
                        const Divider(),

                        Row(
                          children: [
                            const Text(
                              'Total',
                              style:
                              TextStyle(
                                fontSize: 18,
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),

                            const Spacer(),

                            Text(
                              'R${_cartTotal.toStringAsFixed(2)}',
                              style:
                              const TextStyle(
                                fontSize: 20,
                                color:
                                primaryPurple,
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 15,
                        ),

                        SizedBox(
                          width:
                          double.infinity,
                          height: 52,
                          child:
                          ElevatedButton(
                            onPressed:
                                () {
                              Navigator.pop(
                                context,
                              );

                              _checkout();
                            },
                            style:
                            ElevatedButton
                                .styleFrom(
                              backgroundColor:
                              primaryPurple,
                              foregroundColor:
                              Colors.white,
                            ),
                            child:
                            const Text(
                              'PROCEED TO CHECKOUT',
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // EMPTY CART
  // ============================================================

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          Icon(
            Icons
                .shopping_bag_outlined,
            size: 70,
            color:
            Colors.grey[400],
          ),

          const SizedBox(
            height: 15,
          ),

          const Text(
            'Your cart is empty',
            style:
            TextStyle(
              fontSize: 20,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            'Add an item to get started.',
            style: TextStyle(
              color:
              Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHECKOUT
  // ============================================================

  Future<void> _checkout() async {
    if (_cart.isEmpty) {
      _showMessage(
        'Your cart is empty.',
      );
      return;
    }

    final bool? confirmed =
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
          const Text('Checkout'),
          content: Text(
            'Your total is R${_cartTotal.toStringAsFixed(2)}.\n\nProceed with checkout?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                    context,
                    false,
                  ),
              child:
              const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(
                    context,
                    true,
                  ),
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                primaryPurple,
                foregroundColor:
                Colors.white,
              ),
              child:
              const Text('CONTINUE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    _showMessage(
      'Checkout system ready. Payment integration can be connected here.',
      isError: false,
    );
  }

  // ============================================================
  // BOOKINGS
  // ============================================================

  Widget _buildBookings() {
    final User? user =
        _currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please log in to view your bookings.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
      const Color(0xFFF9F7FA),
      appBar: AppBar(
        title: const Text(
          'My Appointments',
          style:
          TextStyle(
            color: Colors.black,
            fontWeight:
            FontWeight.bold,
          ),
        ),
        backgroundColor:
        Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('appointments')
            .where(
          'userId',
          isEqualTo: user.uid,
        )
            .snapshots(),
        builder:
            (context, snapshot) {
          if (snapshot
              .connectionState ==
              ConnectionState
                  .waiting) {
            return const Center(
              child:
              CircularProgressIndicator(
                color:
                primaryPurple,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                const EdgeInsets
                    .all(25),
                child: Text(
                  'Unable to load appointments.\n\n${snapshot.error}',
                  textAlign:
                  TextAlign.center,
                ),
              ),
            );
          }

          final documents =
              snapshot.data?.docs ??
                  [];

          if (documents.isEmpty) {
            return _buildNoBookings();
          }

          return ListView.builder(
            padding:
            const EdgeInsets.all(
              20,
            ),
            itemCount:
            documents.length,
            itemBuilder:
                (context, index) {
              final data =
              documents[index]
                  .data()
              as Map<String,
                  dynamic>;

              return _buildBookingCard(
                data,
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // BOOKING CARD
  // ============================================================

  Widget _buildBookingCard(
      Map<String, dynamic> data,
      ) {
    final String serviceName =
        data['serviceName']
            ?.toString() ??
            'Beauty Service';

    final String date =
        data['date']?.toString() ??
            'Date not available';

    final String time =
        data['timeSlot']
            ?.toString() ??
            'Time not available';

    final String status =
        data['status']?.toString() ??
            'Pending';

    final num? price =
    data['price'] as num?;

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 14,
      ),
      padding:
      const EdgeInsets.all(
        18,
      ),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withValues(
              alpha: 0.06,
            ),
            blurRadius: 8,
            offset:
            const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                lightPurple,
                child: const Icon(
                  Icons.spa,
                  color:
                  primaryPurple,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Text(
                  serviceName,
                  style:
                  const TextStyle(
                    fontSize: 17,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),

              _statusBadge(
                status,
              ),
            ],
          ),

          const SizedBox(
            height: 15,
          ),

          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 18,
                color:
                primaryPurple,
              ),
              const SizedBox(
                width: 8,
              ),
              Expanded(
                child: Text(
                  date,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 8,
          ),

          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 18,
                color:
                primaryPurple,
              ),
              const SizedBox(
                width: 8,
              ),
              Text(time),
            ],
          ),

          if (price != null) ...[
            const SizedBox(
              height: 10,
            ),
            Text(
              'R${price.toStringAsFixed(2)}',
              style:
              const TextStyle(
                color:
                primaryPurple,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // NO BOOKINGS
  // ============================================================

  Widget _buildNoBookings() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(
          30,
        ),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment
              .center,
          children: [
            Icon(
              Icons.calendar_month,
              size: 70,
              color:
              Colors.grey[400],
            ),

            const SizedBox(
              height: 15,
            ),

            const Text(
              'No appointments yet',
              style:
              TextStyle(
                fontSize: 20,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              'Your upcoming appointments will appear here.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                Colors.grey[600],
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            ElevatedButton.icon(
              onPressed:
              _openBookingPage,
              icon: const Icon(
                Icons.calendar_month,
              ),
              label:
              const Text('BOOK NOW'),
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                primaryPurple,
                foregroundColor:
                Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge(
      String status,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration:
      BoxDecoration(
        color: lightPurple,
        borderRadius:
        BorderRadius.circular(
          12,
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style:
        const TextStyle(
          fontSize: 10,
          color:
          primaryPurple,
          fontWeight:
          FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Widget _buildProfile() {
    final User? user =
        _currentUser;

    return Scaffold(
      backgroundColor:
      const Color(0xFFF9F7FA),
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style:
          TextStyle(
            color: Colors.black,
            fontWeight:
            FontWeight.bold,
          ),
        ),
        backgroundColor:
        Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding:
        const EdgeInsets.all(
          20,
        ),
        children: [
          // PROFILE HEADER
          Container(
            padding:
            const EdgeInsets.all(
              25,
            ),
            decoration:
            BoxDecoration(
              gradient:
              const LinearGradient(
                colors: [
                  primaryPurple,
                  fieldPurple,
                ],
              ),
              borderRadius:
              BorderRadius.circular(
                24,
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor:
                  Colors.white,
                  child: Text(
                    _userName
                        .substring(
                      0,
                      1,
                    )
                        .toUpperCase(),
                    style:
                    const TextStyle(
                      fontSize: 32,
                      color:
                      primaryPurple,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Text(
                  _userName,
                  style:
                  const TextStyle(
                    color:
                    Colors.white,
                    fontSize: 22,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  user?.email ??
                      'No email',
                  style:
                  const TextStyle(
                    color:
                    Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 25,
          ),

          _profileOption(
            icon:
            Icons.person_outline,
            title:
            'Personal Information',
            onTap: () {
              _showMessage(
                'Profile editing can be connected here.',
                isError: false,
              );
            },
          ),

          _profileOption(
            icon:
            Icons.favorite_border,
            title:
            'My Favourites',
            onTap:
            _showFavourites,
          ),

          _profileOption(
            icon: Icons
                .calendar_month_outlined,
            title:
            'My Bookings',
            onTap: () {
              setState(() {
                _selectedIndex = 1;
              });
            },
          ),

          _profileOption(
            icon:
            Icons.shopping_bag_outlined,
            title:
            'My Orders',
            onTap: () {
              _showMessage(
                'Order history will appear here.',
                isError: false,
              );
            },
          ),

          _profileOption(
            icon:
            Icons.help_outline,
            title:
            'Help & Support',
            onTap: () {
              _showMessage(
                'Contact Kotton Kandy support.',
                isError: false,
              );
            },
          ),

          _profileOption(
            icon:
            Icons.settings_outlined,
            title:
            'Settings',
            onTap: () {
              _showMessage(
                'Settings will be available here.',
                isError: false,
              );
            },
          ),

          const SizedBox(
            height: 15,
          ),

          SizedBox(
            height: 52,
            child:
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(
                Icons.logout,
                color: Colors.red,
              ),
              label: const Text(
                'LOGOUT',
                style:
                TextStyle(
                  color:
                  Colors.red,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
              style:
              OutlinedButton
                  .styleFrom(
                side:
                const BorderSide(
                  color: Colors.red,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROFILE OPTION
  // ============================================================

  Widget _profileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 10,
      ),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor:
          lightPurple,
          child: Icon(
            icon,
            color:
            primaryPurple,
          ),
        ),
        title: Text(
          title,
          style:
          const TextStyle(
            fontWeight:
            FontWeight.w600,
          ),
        ),
        trailing:
        const Icon(
          Icons.chevron_right,
        ),
      ),
    );
  }

  // ============================================================
  // FAVOURITES
  // ============================================================

  void _showFavourites() {
    final favourites =
    _sampleServices
        .where(
          (service) =>
          _favourites
              .contains(
            service['id'],
          ),
    )
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
      Colors.transparent,
      builder: (context) {
        return Container(
          height:
          MediaQuery.of(context)
              .size
              .height *
              0.70,
          padding:
          const EdgeInsets.all(
            20,
          ),
          decoration:
          const BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.vertical(
              top: Radius.circular(
                28,
              ),
            ),
          ),
          child: Column(
            children: [
              const Text(
                'My Favourites',
                style:
                TextStyle(
                  fontSize: 22,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              Expanded(
                child:
                favourites.isEmpty
                    ? const Center(
                  child: Text(
                    'You have no favourite items yet.',
                  ),
                )
                    : ListView
                    .builder(
                  itemCount:
                  favourites
                      .length,
                  itemBuilder:
                      (
                      context,
                      index,
                      ) {
                    return Padding(
                      padding:
                      const EdgeInsets
                          .only(
                        bottom:
                        12,
                      ),
                      child:
                      _buildServiceCard(
                        favourites[
                        index],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  Widget _buildMessages() {
    return const ChatScreen(
      salonId:
      'kotton_kandy',
      salonName:
      'Kotton Kandy',
    );
  }

  // ============================================================
  // CURRENT PAGE
  // ============================================================

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();

      case 1:
        return _buildBookings();

      case 2:
        return _buildMessages();

      case 3:
        return _buildProfile();

      default:
        return _buildDashboard();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      body:
      _buildCurrentPage(),

      bottomNavigationBar:
      NavigationBar(
        selectedIndex:
        _selectedIndex,

        onDestinationSelected:
            (index) {
          setState(() {
            _selectedIndex =
                index;
          });
        },

        backgroundColor:
        Colors.white,

        indicatorColor:
        lightPurple,

        elevation: 8,

        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),
            selectedIcon:
            Icon(
              Icons.home,
              color:
              primaryPurple,
            ),
            label: 'Home',
          ),

          NavigationDestination(
            icon: Icon(
              Icons
                  .calendar_today_outlined,
            ),
            selectedIcon:
            Icon(
              Icons.calendar_today,
              color:
              primaryPurple,
            ),
            label: 'Bookings',
          ),

          NavigationDestination(
            icon: Icon(
              Icons
                  .chat_bubble_outline,
            ),
            selectedIcon:
            Icon(
              Icons.chat_bubble,
              color:
              primaryPurple,
            ),
            label: 'Messages',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),
            selectedIcon:
            Icon(
              Icons.person,
              color:
              primaryPurple,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}