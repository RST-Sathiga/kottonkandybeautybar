import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'client_chat_system.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() =>
      _MarketplaceScreenState();
}

class _MarketplaceScreenState
    extends State<MarketplaceScreen> {
  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ============================================================
  // COLOURS
  // ============================================================

  static const Color primaryPurple =
  Color(0xFF6B3A82);

  static const Color fieldPurple =
  Color(0xFF9156A1);

  static const Color lightPurple =
  Color(0xFFF3EAF6);

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _searchController =
  TextEditingController();

  // ============================================================
  // VARIABLES
  // ============================================================

  int _selectedIndex = 0;

  String _selectedCategory = 'All';

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
  // CATEGORIES
  // ============================================================

  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'All',
      'icon': Icons.apps,
    },
    {
      'name': 'Hair',
      'icon': Icons.content_cut,
    },
    {
      'name': 'Nails',
      'icon': Icons.brush,
    },
    {
      'name': 'Makeup',
      'icon': Icons.face,
    },
    {
      'name': 'Lashes',
      'icon': Icons.remove_red_eye,
    },
    {
      'name': 'Skincare',
      'icon': Icons.spa,
    },
  ];

  // ============================================================
  // SAMPLE SERVICES
  //
  // These allow the marketplace to work immediately.
  // Firestore products can be added later.
  // ============================================================

  final List<Map<String, dynamic>> _sampleServices = [
    {
      'id': 'hair_braiding',
      'name': 'Hair Braiding',
      'category': 'Hair',
      'description':
      'Professional braiding and protective hairstyles.',
      'price': 350.00,
      'duration': '2 hrs',
      'icon': Icons.content_cut,
    },
    {
      'id': 'gel_nails',
      'name': 'Gel Nails',
      'category': 'Nails',
      'description':
      'Beautiful long-lasting gel nail application.',
      'price': 250.00,
      'duration': '1 hr 30 min',
      'icon': Icons.brush,
    },
    {
      'id': 'makeup',
      'name': 'Professional Makeup',
      'category': 'Makeup',
      'description':
      'Professional makeup for events and special occasions.',
      'price': 450.00,
      'duration': '1 hr 30 min',
      'icon': Icons.face,
    },
    {
      'id': 'lashes',
      'name': 'Lash Extensions',
      'category': 'Lashes',
      'description':
      'Enhance your look with beautiful lash extensions.',
      'price': 300.00,
      'duration': '1 hr',
      'icon': Icons.remove_red_eye,
    },
    {
      'id': 'facial',
      'name': 'Luxury Facial',
      'category': 'Skincare',
      'description':
      'Relaxing facial treatment for healthy glowing skin.',
      'price': 400.00,
      'duration': '1 hr',
      'icon': Icons.spa,
    },
    {
      'id': 'hair_wash',
      'name': 'Hair Wash & Treatment',
      'category': 'Hair',
      'description':
      'Deep cleansing and nourishing hair treatment.',
      'price': 220.00,
      'duration': '1 hr',
      'icon': Icons.water_drop,
    },
  ];

  // ============================================================
  // USER
  // ============================================================

  User? get _currentUser =>
      _auth.currentUser;

  String get _userName {
    final String? displayName =
        _currentUser?.displayName;

    if (displayName != null &&
        displayName.trim().isNotEmpty) {
      return displayName.split(' ').first;
    }

    final String? email =
        _currentUser?.email;

    if (email != null &&
        email.contains('@')) {
      return email.split('@').first;
    }

    return 'User';
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // FILTER SERVICES
  // ============================================================

  List<Map<String, dynamic>>
  get _filteredServices {
    final String search =
    _searchController.text
        .trim()
        .toLowerCase();

    return _sampleServices.where((service) {
      final String name =
      service['name']
          .toString()
          .toLowerCase();

      final String category =
      service['category']
          .toString()
          .toLowerCase();

      final bool matchesSearch =
          search.isEmpty ||
              name.contains(search) ||
              category.contains(search);

      final bool matchesCategory =
          _selectedCategory == 'All' ||
              service['category'] ==
                  _selectedCategory;

      return matchesSearch &&
          matchesCategory;
    }).toList();
  }

  // ============================================================
  // ADD TO CART
  // ============================================================

  void _addToCart(
      Map<String, dynamic> service,
      ) {
    final String id =
    service['id'].toString();

    final int existingIndex =
    _cart.indexWhere(
          (item) => item['id'] == id,
    );

    if (existingIndex >= 0) {
      _cart[existingIndex]['quantity'] =
          (_cart[existingIndex]['quantity']
          as int) +
              1;
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
      (item['price'] as num)
          .toDouble();

      final int quantity =
      item['quantity'] as int;

      total += price * quantity;
    }

    return total;
  }

  // ============================================================
  // CART ITEM COUNT
  // ============================================================

  int get _cartItemCount {
    int count = 0;

    for (final item in _cart) {
      count += item['quantity'] as int;
    }

    return count;
  }

  // ============================================================
  // TOGGLE FAVOURITE
  // ============================================================

  void _toggleFavourite(
      String id,
      ) {
    setState(() {
      if (_favourites.contains(id)) {
        _favourites.remove(id);
      } else {
        _favourites.add(id);
      }
    });
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
          behavior:
          SnackBarBehavior.floating,
          margin:
          const EdgeInsets.all(16),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(12),
          ),
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
          title:
          const Text('Logout'),
          content: const Text(
            'Are you sure you want to log out?',
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
              const Text('LOGOUT'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _auth.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
          (route) => false,
    );
  }

  // ============================================================
  // BOOK APPOINTMENT
  // ============================================================

  Future<void> _bookAppointment(
      Map<String, dynamic> service,
      ) async {
    final DateTime? date =
    await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 90),
      ),
      initialDate: DateTime.now(),
      builder:
          (context, child) {
        return Theme(
          data: Theme.of(context)
              .copyWith(
            colorScheme:
            const ColorScheme.light(
              primary:
              primaryPurple,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date == null) {
      return;
    }

    if (!mounted) return;

    final TimeOfDay? time =
    await showTimePicker(
      context: context,
      initialTime:
      const TimeOfDay(
        hour: 10,
        minute: 0,
      ),
    );

    if (time == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final User? user =
          _currentUser;

      if (user == null) {
        _showMessage(
          'Please log in to book an appointment.',
        );
        return;
      }

      // ========================================================
      // SAVE APPOINTMENT TO FIRESTORE
      // ========================================================

      await _firestore
          .collection('appointments')
          .add({
        'userId': user.uid,
        'userEmail':
        user.email ?? '',
        'serviceId':
        service['id'],
        'serviceName':
        service['name'],
        'category':
        service['category'],
        'price':
        service['price'],
        'date': Timestamp.fromDate(
          DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          ),
        ),
        'status': 'pending',
        'createdAt':
        FieldValue.serverTimestamp(),
      });

      _showMessage(
        'Appointment request submitted successfully.',
        isError: false,
      );
    } catch (e) {
      _showMessage(
        'Could not save appointment. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // SERVICE DETAILS
  // ============================================================

  void _showServiceDetails(
      Map<String, dynamic> service,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                      color:
                      Colors.grey[300],
                      borderRadius:
                      BorderRadius
                          .circular(10),
                    ),
                  ),
                ),

                const SizedBox(
                    height: 25),

                Container(
                  height: 100,
                  width:
                  double.infinity,
                  decoration:
                  BoxDecoration(
                    color: lightPurple,
                    borderRadius:
                    BorderRadius
                        .circular(20),
                  ),
                  child: Icon(
                    service['icon']
                    as IconData,
                    size: 55,
                    color:
                    primaryPurple,
                  ),
                ),

                const SizedBox(
                    height: 20),

                Text(
                  service['name']
                      .toString(),
                  style:
                  const TextStyle(
                    fontSize: 24,
                    fontWeight:
                    FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(
                    height: 8),

                Text(
                  service['description']
                      .toString(),
                  style:
                  TextStyle(
                    fontSize: 15,
                    color:
                    Colors.grey[700],
                  ),
                ),

                const SizedBox(
                    height: 18),

                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      color:
                      primaryPurple,
                    ),
                    const SizedBox(
                        width: 8),
                    Text(
                      service['duration']
                          .toString(),
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'R${(service['price'] as num).toStringAsFixed(2)}',
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

                const SizedBox(
                    height: 24),

                Row(
                  children: [
                    Expanded(
                      child:
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(
                              context);
                          _addToCart(
                              service);
                        },
                        style:
                        OutlinedButton
                            .styleFrom(
                          foregroundColor:
                          primaryPurple,
                          side:
                          const BorderSide(
                            color:
                            primaryPurple,
                          ),
                          padding:
                          const EdgeInsets
                              .symmetric(
                            vertical: 15,
                          ),
                        ),
                        child:
                        const Text(
                          'ADD TO CART',
                        ),
                      ),
                    ),

                    const SizedBox(
                        width: 12),

                    Expanded(
                      child:
                      ElevatedButton(
                        onPressed:
                        _isLoading
                            ? null
                            : () {
                          Navigator.pop(
                              context);
                          _bookAppointment(
                              service);
                        },
                        style:
                        ElevatedButton
                            .styleFrom(
                          backgroundColor:
                          primaryPurple,
                          foregroundColor:
                          Colors.white,
                          padding:
                          const EdgeInsets
                              .symmetric(
                            vertical: 15,
                          ),
                        ),
                        child:
                        const Text(
                          'BOOK NOW',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
          const Duration(
            milliseconds: 500,
          ),
        );

        setState(() {});
      },
      child: CustomScrollView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        slivers: [

          // ======================================================
          // TOP APP BAR
          // ======================================================

          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor:
            Colors.white,
            elevation: 0,
            titleSpacing: 20,
            title: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $_userName!',
                  style:
                  const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                Text(
                  'Find your next beauty experience',
                  style:
                  TextStyle(
                    color:
                    Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              _buildIconButton(
                icon: Icons.notifications_none,
                onTap: () {
                  _showMessage(
                    'No new notifications.',
                    isError: false,
                  );
                },
              ),
              _buildCartButton(),
              const SizedBox(
                  width: 10),
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

                  // =================================================
                  // SEARCH
                  // =================================================

                  Container(
                    decoration:
                    BoxDecoration(
                      color:
                      Colors.grey[100],
                      borderRadius:
                      BorderRadius
                          .circular(
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
                        'Search services...',
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
                                    () {});
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

                  const SizedBox(
                      height: 25),

                  // =================================================
                  // WELCOME BANNER
                  // =================================================

                  Container(
                    width:
                    double.infinity,
                    padding:
                    const EdgeInsets
                        .all(22),
                    decoration:
                    BoxDecoration(
                      gradient:
                      const LinearGradient(
                        colors: [
                          Color(
                              0xFF6B3A82),
                          Color(
                              0xFF9156A1),
                        ],
                      ),
                      borderRadius:
                      BorderRadius
                          .circular(
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
                                'YOUR BEAUTY,\nYOUR WAY.',
                                style:
                                TextStyle(
                                  color:
                                  Colors.white,
                                  fontSize:
                                  22,
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                ),
                              ),
                              const SizedBox(
                                  height: 8),
                              const Text(
                                'Book your next appointment with Kotton Kandy.',
                                style:
                                TextStyle(
                                  color:
                                  Colors.white70,
                                  fontSize:
                                  13,
                                ),
                              ),
                              const SizedBox(
                                  height: 15),
                              ElevatedButton(
                                onPressed:
                                    () {
                                  setState(
                                        () {
                                      _selectedIndex =
                                      1;
                                    },
                                  );
                                },
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
                                    BorderRadius.circular(
                                      15,
                                    ),
                                  ),
                                ),
                                child:
                                const Text(
                                  'BOOK NOW',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                            width: 10),
                        const Icon(
                          Icons.spa,
                          color:
                          Colors.white54,
                          size: 80,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                      height: 28),

                  // =================================================
                  // CATEGORIES
                  // =================================================

                  _buildSectionTitle(
                    'Categories',
                    onTap: () {
                      setState(() {
                        _selectedCategory =
                        'All';
                      });
                    },
                  ),

                  const SizedBox(
                      height: 14),

                  SizedBox(
                    height: 95,
                    child:
                    ListView.separated(
                      scrollDirection:
                      Axis.horizontal,
                      itemCount:
                      _categories
                          .length,
                      separatorBuilder:
                          (context, index) =>
                      const SizedBox(
                        width: 12,
                      ),
                      itemBuilder:
                          (context, index) {
                        final category =
                        _categories[
                        index];

                        final bool selected =
                            _selectedCategory ==
                                category[
                                'name'];

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory =
                              category[
                              'name'];
                            });
                          },
                          child: Container(
                            width: 72,
                            decoration:
                            BoxDecoration(
                              color: selected
                                  ? primaryPurple
                                  : lightPurple,
                              borderRadius:
                              BorderRadius
                                  .circular(
                                18,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                              children: [
                                Icon(
                                  category[
                                  'icon'],
                                  color: selected
                                      ? Colors.white
                                      : primaryPurple,
                                  size: 28,
                                ),
                                const SizedBox(
                                    height: 7),
                                Text(
                                  category[
                                  'name'],
                                  style:
                                  TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize:
                                    11,
                                    fontWeight:
                                    FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(
                      height: 28),

                  // =================================================
                  // SERVICES
                  // =================================================

                  _buildSectionTitle(
                    _selectedCategory ==
                        'All'
                        ? 'Popular Services'
                        : _selectedCategory,
                  ),

                  const SizedBox(
                      height: 14),

                  if (_filteredServices
                      .isEmpty)
                    _buildEmptyState()
                  else
                    ..._filteredServices
                        .map(
                          (service) =>
                          Padding(
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
          style:
          const TextStyle(
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
            child:
            const Text(
              'View All',
              style:
              TextStyle(
                color:
                primaryPurple,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // SERVICE CARD
  // ============================================================

  Widget _buildServiceCard(
      Map<String, dynamic> service,
      ) {
    final String id =
    service['id'].toString();

    final bool favourite =
    _favourites.contains(id);

    return GestureDetector(
      onTap: () =>
          _showServiceDetails(
            service,
          ),
      child: Container(
        padding:
        const EdgeInsets.all(14),
        decoration:
        BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(
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

            // ======================================================
            // IMAGE / ICON
            // ======================================================

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
              ),
              child: Icon(
                service['icon']
                as IconData,
                color:
                primaryPurple,
                size: 40,
              ),
            ),

            const SizedBox(
                width: 14),

            // ======================================================
            // DETAILS
            // ======================================================

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
                      height: 5),

                  Text(
                    service['description']
                        .toString(),
                    maxLines: 2,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style:
                    TextStyle(
                      fontSize: 12,
                      color:
                      Colors.grey[600],
                    ),
                  ),

                  const SizedBox(
                      height: 8),

                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color:
                        primaryPurple,
                      ),
                      const SizedBox(
                          width: 4),
                      Text(
                        service[
                        'duration']
                            .toString(),
                        style:
                        TextStyle(
                          fontSize: 11,
                          color:
                          Colors.grey[700],
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

            const SizedBox(
                width: 8),

            // ======================================================
            // FAVOURITE
            // ======================================================

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
                  child:
                  IconButton(
                    onPressed: () =>
                        _addToCart(
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
              height: 12),
          const Text(
            'No services found',
            style:
            TextStyle(
              fontSize: 18,
              fontWeight:
              FontWeight.bold,
            ),
          ),
          const SizedBox(
              height: 6),
          Text(
            'Try another search or category.',
            textAlign:
            TextAlign.center,
            style:
            TextStyle(
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
          onPressed: () {
            _openCart();
          },
          icon: const Icon(
            Icons.shopping_bag_outlined,
            color: Colors.black87,
          ),
        ),

        if (_cartItemCount > 0)
          Positioned(
            right: 4,
            top: 5,
            child: Container(
              padding:
              const EdgeInsets.all(4),
              decoration:
              const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                _cartItemCount
                    .toString(),
                style:
                const TextStyle(
                  color: Colors.white,
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
  // ICON BUTTON
  // ============================================================

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: Colors.black87,
      ),
    );
  }

  // ============================================================
  // CART SCREEN
  // ============================================================

  void _openCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
      Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder:
              (context, setModalState) {
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
                      height: 20),

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
                          Colors.grey[600],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                      height: 20),

                  Expanded(
                    child:
                    _cart.isEmpty
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

                        return ListTile(
                          leading:
                          CircleAvatar(
                            backgroundColor:
                            lightPurple,
                            child:
                            Icon(
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
                              FontWeight.bold,
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
                                  index);
                              setModalState(
                                      () {});
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
                                fontSize:
                                18,
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
                                fontSize:
                                20,
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
                            height: 15),

                        SizedBox(
                          width:
                          double.infinity,
                          height: 52,
                          child:
                          ElevatedButton(
                            onPressed:
                                () {
                              Navigator.pop(
                                  context);
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
            Icons.shopping_bag_outlined,
            size: 70,
            color: Colors.grey[400],
          ),
          const SizedBox(
              height: 15),
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
              height: 8),
          Text(
            'Add a beauty service to get started.',
            style:
            TextStyle(
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

    if (confirmed != true) {
      return;
    }

    _showMessage(
      'Checkout system ready. Payment integration can be connected here.',
      isError: false,
    );
  }

  // ============================================================
  // BOOKINGS PAGE
  // ============================================================

  Widget _buildBookings() {
    final User? user =
        _currentUser;

    if (user == null) {
      return const Center(
        child: Text(
          'Please log in.',
        ),
      );
    }

    return Scaffold(
      backgroundColor:
      const Color(0xFFF9F7FA),
      appBar: AppBar(
        title:
        const Text(
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
      body: StreamBuilder<
          QuerySnapshot>(
        stream: _firestore
            .collection(
            'appointments')
            .where(
          'userId',
          isEqualTo: user.uid,
        )
            .snapshots(),
        builder:
            (context, snapshot) {

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
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
                const EdgeInsets.all(
                  25,
                ),
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
            const EdgeInsets.all(20),
            itemCount:
            documents.length,
            itemBuilder:
                (context, index) {

              final data =
              documents[index].data()
              as Map<String,
                  dynamic>;

              final Timestamp?
              timestamp =
              data['date']
              as Timestamp?;

              final DateTime?
              appointmentDate =
              timestamp?.toDate();

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
                  color:
                  Colors.white,
                  borderRadius:
                  BorderRadius
                      .circular(
                    18,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(
                        alpha: 0.06,
                      ),
                      blurRadius: 8,
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
                          child:
                          const Icon(
                            Icons.spa,
                            color:
                            primaryPurple,
                          ),
                        ),
                        const SizedBox(
                            width: 12),
                        Expanded(
                          child: Text(
                            data['serviceName']
                                ?.toString() ??
                                'Beauty Service',
                            style:
                            const TextStyle(
                              fontSize: 17,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                        _statusBadge(
                          data['status']
                              ?.toString() ??
                              'pending',
                        ),
                      ],
                    ),

                    const SizedBox(
                        height: 15),

                    if (appointmentDate !=
                        null)
                      Row(
                        children: [
                          const Icon(
                            Icons
                                .calendar_today,
                            size: 18,
                            color:
                            primaryPurple,
                          ),
                          const SizedBox(
                              width: 8),
                          Text(
                            _formatDate(
                              appointmentDate,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(
                        height: 8),

                    if (data['price'] !=
                        null)
                      Text(
                        'R${(data['price'] as num).toStringAsFixed(2)}',
                        style:
                        const TextStyle(
                          color:
                          primaryPurple,
                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
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
        const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month,
              size: 70,
              color: Colors.grey[400],
            ),
            const SizedBox(
                height: 15),
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
                height: 8),
            Text(
              'Your upcoming appointments will appear here.',
              textAlign:
              TextAlign.center,
              style:
              TextStyle(
                color:
                Colors.grey[600],
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
  // PROFILE PAGE
  // ============================================================

  Widget _buildProfile() {
    final User? user =
        _currentUser;

    return Scaffold(
      backgroundColor:
      const Color(0xFFF9F7FA),
      appBar: AppBar(
        title:
        const Text(
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
        const EdgeInsets.all(20),
        children: [

          // ======================================================
          // PROFILE HEADER
          // ======================================================

          Container(
            padding:
            const EdgeInsets.all(25),
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
                    height: 12),

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
                    height: 5),

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
              height: 25),

          _profileOption(
            icon: Icons.person_outline,
            title: 'Personal Information',
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
            title: 'My Favourites',
            onTap: () {
              _showFavourites();
            },
          ),

          _profileOption(
            icon:
            Icons.shopping_bag_outlined,
            title: 'My Orders',
            onTap: () {
              _showMessage(
                'Order history will appear here.',
                isError: false,
              );
            },
          ),

          _profileOption(
            icon: Icons.help_outline,
            title: 'Help & Support',
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
            title: 'Settings',
            onTap: () {
              _showMessage(
                'Settings will be available here.',
                isError: false,
              );
            },
          ),

          const SizedBox(
              height: 15),

          SizedBox(
            height: 52,
            child:
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(
                Icons.logout,
                color: Colors.red,
              ),
              label:
              const Text(
                'LOGOUT',
                style:
                TextStyle(
                  color: Colors.red,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
              style:
              OutlinedButton.styleFrom(
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
          _favourites.contains(
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
          const EdgeInsets.all(20),
          decoration:
          const BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.vertical(
              top: Radius.circular(28),
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
                  height: 20),

              Expanded(
                child: favourites
                    .isEmpty
                    ? const Center(
                  child: Text(
                    'You have no favourite services yet.',
                  ),
                )
                    : ListView.builder(
                  itemCount:
                  favourites
                      .length,
                  itemBuilder:
                      (context,
                      index) {
                    return _buildServiceCard(
                      favourites[
                      index],
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
      salonId: 'kotton_kandy',
      salonName: 'Kotton Kandy',
    );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(
      DateTime date,
      ) {
    const List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    String hour =
    date.hour.toString();

    String minute =
    date.minute
        .toString()
        .padLeft(2, '0');

    return '${date.day} ${months[date.month - 1]} ${date.year} at $hour:$minute';
  }

  // ============================================================
  // BOTTOM NAVIGATION
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
      body: _buildCurrentPage(),

      // ========================================================
      // BOTTOM NAVIGATION
      // ========================================================

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
              Icons.calendar_today_outlined,
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
              Icons.chat_bubble_outline,
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