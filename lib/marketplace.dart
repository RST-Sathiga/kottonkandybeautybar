import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'client_chat_system.dart';
import 'user_info.dart';
import 'orders.dart';
import 'loyalty.dart';
import 'support.dart';
import 'settings.dart';
import 'favorites_page.dart';
import 'main.dart';
import 'payment_service.dart';
import 'paystack_checkout_screen.dart';
import 'kiosk_picker_dialog.dart';
import 'booking_page.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  // ============================================================
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

  final TextEditingController _searchController = TextEditingController();

  // ============================================================
  // VARIABLES
  // ============================================================

  int _selectedIndex = 0;
  String _selectedCategory = 'All';
  bool _isLoading = false;

  // ============================================================
  // CART & FAVOURITES
  // ============================================================

  final List<Map<String, dynamic>> _cart = [];
  final Set<String> _favourites = {};

  // ============================================================
  // CATEGORIES
  // ============================================================

  final List<Map<String, dynamic>> _categories = [
    {'name': 'All', 'icon': Icons.apps},
    {'name': 'Hair', 'icon': Icons.content_cut},
    {'name': 'Nails', 'icon': Icons.brush},
    {'name': 'Makeup', 'icon': Icons.face},
    {'name': 'Lashes', 'icon': Icons.remove_red_eye},
    {'name': 'Skincare', 'icon': Icons.spa},
  ];

  // ============================================================
  // SAMPLE SERVICES
  // ============================================================

  final List<Map<String, dynamic>> _sampleServices = [
    {
      'id': 'hair_braiding',
      'name': 'Hair Braiding',
      'category': 'Hair',
      'description': 'Professional braiding and protective hairstyles.',
      'price': 350.00,
      'duration': '2 hrs',
      'icon': Icons.content_cut,
    },
    {
      'id': 'gel_nails',
      'name': 'Gel Nails',
      'category': 'Nails',
      'description': 'Beautiful long-lasting gel nail application.',
      'price': 250.00,
      'duration': '1 hr 30 min',
      'icon': Icons.brush,
    },
    {
      'id': 'makeup',
      'name': 'Professional Makeup',
      'category': 'Makeup',
      'description': 'Professional makeup for events and special occasions.',
      'price': 450.00,
      'duration': '1 hr 30 min',
      'icon': Icons.face,
    },
    {
      'id': 'lashes',
      'name': 'Lash Extensions',
      'category': 'Lashes',
      'description': 'Enhance your look with beautiful lash extensions.',
      'price': 300.00,
      'duration': '1 hr',
      'icon': Icons.remove_red_eye,
    },
    {
      'id': 'facial',
      'name': 'Luxury Facial',
      'category': 'Skincare',
      'description': 'Relaxing facial treatment for healthy glowing skin.',
      'price': 400.00,
      'duration': '1 hr',
      'icon': Icons.spa,
    },
    {
      'id': 'hair_wash',
      'name': 'Hair Wash & Treatment',
      'category': 'Hair',
      'description': 'Deep cleansing and nourishing hair treatment.',
      'price': 220.00,
      'duration': '1 hr',
      'icon': Icons.water_drop,
    },
    {
      'id': 'aki_shampoo',
      'name': 'Aki Asili Clarifying Shampoo',
      'category': 'Hair',
      'description': 'Deep cleansing shampoo formulated to eliminate build-up.',
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
      'description': 'Lightweight hold spray to lock in styles and reduce frizz.',
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
      'description': 'Nourishing formula that seals in moisture and adds shine.',
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
      'description': 'Restorative treatment to strengthen and repair damaged hair.',
      'price': 180.00,
      'duration': 'Product',
      'isProduct': true,
      'icon': Icons.sanitizer,
      'image': 'assets/images/protien_conditioner.jpeg',
    },
    {
      'id': 'french_tip_nails',
      'name': 'Classic French Tip Press-Ons',
      'category': 'Nails',
      'description': 'Elegant and timeless French tip press-on nails with adhesive.',
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
      'description': 'Sophisticated matte nude finish for everyday wear.',
      'price': 130.00,
      'duration': 'Product',
      'isProduct': true,
      'icon': Icons.back_hand,
      'image': 'assets/images/matte_nails.jpeg',
    },
  ];

  // ============================================================
  // LIFECYCLE & USER GETTERS
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadUserFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  Future<void> _loadUserFavorites() async {
    final user = _auth.currentUser;
    if (user != null) {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .get();

      if (mounted) {
        setState(() {
          _favourites.clear();
          _favourites.addAll(snapshot.docs.map((doc) => doc.id));
        });
      }
    }
  }

  // ============================================================
  // FILTER SERVICES
  // ============================================================

  List<Map<String, dynamic>> get _filteredServices {
    final String search = _searchController.text.trim().toLowerCase();

    return _sampleServices.where((service) {
      final String name = service['name'].toString().toLowerCase();
      final String category = service['category'].toString().toLowerCase();

      final bool matchesSearch = search.isEmpty ||
          name.contains(search) ||
          category.contains(search);

      final bool matchesCategory =
          _selectedCategory == 'All' || service['category'] == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  // ============================================================
  // CART LOGIC
  // ============================================================

  void _addToCart(Map<String, dynamic> service) {
    final String id = service['id'].toString();

    final int existingIndex = _cart.indexWhere((item) => item['id'] == id);

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
    _showMessage('${service['name']} added to cart.', isError: false);
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  double get _cartTotal {
    double total = 0;
    for (final item in _cart) {
      final double price = (item['price'] as num).toDouble();
      final int quantity = item['quantity'] as int;
      total += price * quantity;
    }
    return total;
  }

  int get _cartItemCount {
    int count = 0;
    for (final item in _cart) {
      count += item['quantity'] as int;
    }
    return count;
  }

  // ============================================================
  // SHOW MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
          isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
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

    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  // ============================================================
  // BOOK APPOINTMENT
  // ============================================================

  Future<void> _bookAppointment(Map<String, dynamic> service) async {
    final DateTime? date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: primaryPurple),
          ),
          child: child!,
        );
      },
    );

    if (date == null || !mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );

    if (time == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = _currentUser;
      if (user == null) {
        _showMessage('Please log in to book an appointment.');
        return;
      }

      await _firestore.collection('appointments').add({
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'serviceId': service['id'],
        'serviceName': service['name'],
        'category': service['category'],
        'price': service['price'],
        'date': Timestamp.fromDate(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        ),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showMessage(
        'Appointment request submitted successfully.',
        isError: false,
      );
    } catch (e) {
      _showMessage('Could not save appointment. Please try again.');
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

  void _showServiceDetails(Map<String, dynamic> service) {
    final bool isNails =
        service['category'] == 'Nails' && service['isProduct'] == true;
    final String? imagePath = service['image'];
    bool includeInstallation = false;
    final double basePrice = (service['price'] as num).toDouble();
    const double installationFee = 50.00;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double currentTotal = basePrice +
                (includeInstallation && isNails ? installationFee : 0);

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 45,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      Container(
                        height: imagePath != null ? 180 : 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: lightPurple,
                          borderRadius: BorderRadius.circular(20),
                          image: imagePath != null
                              ? DecorationImage(
                            image: AssetImage(imagePath),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: imagePath != null
                            ? null
                            : Icon(
                          service['icon'] as IconData,
                          size: 55,
                          color: primaryPurple,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        service['name'].toString(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        service['description'].toString(),
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Icon(
                            service['isProduct'] == true
                                ? Icons.inventory_2
                                : Icons.access_time,
                            color: primaryPurple,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            service['duration'].toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'R${currentTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primaryPurple,
                            ),
                          ),
                        ],
                      ),
                      if (isNails) ...[
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          title: const Text(
                            'Include Salon Installation (+R50.00)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Have our professionals install your press-ons at the salon.',
                          ),
                          value: includeInstallation,
                          activeColor: primaryPurple,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (value) {
                            setModalState(() {
                              includeInstallation = value ?? false;
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                final Map<String, dynamic> modifiedService = {
                                  ...service,
                                  'price': currentTotal,
                                  'name': includeInstallation && isNails
                                      ? '${service['name']} (+ Installation)'
                                      : service['name'],
                                };
                                _addToCart(modifiedService);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryPurple,
                                side: const BorderSide(color: primaryPurple),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                              ),
                              child: const Text('ADD TO CART'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                Navigator.pop(context);
                                final Map<String, dynamic> modifiedService = {
                                  ...service,
                                  'price': currentTotal,
                                  'name': includeInstallation && isNails
                                      ? '${service['name']} (+ Installation)'
                                      : service['name'],
                                };
                                _bookAppointment(modifiedService);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                              ),
                              child: const Text('BOOK NOW'),
                            ),
                          ),
                        ],
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
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() {});
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: Colors.white,
            elevation: 0,
            titleSpacing: 20,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $_userName!',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Find your next beauty experience',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              _buildIconButton(
                icon: Icons.notifications_none,
                onTap: () {
                  _showMessage('No new notifications.', isError: false);
                },
              ),
              _buildCartButton(),
              const SizedBox(width: 10),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search services...',
                      prefixIcon: const Icon(Icons.search, color: primaryPurple),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6B3A82), Color(0xFF9156A1)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'YOUR BEAUTY,\nYOUR WAY.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Book your next appointment with Kotton Kandy.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 15),
                            ElevatedButton(
                              onPressed: () => setState(() => _selectedIndex = 1),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: primaryPurple,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text('BOOK NOW'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.spa, color: Colors.white54, size: 80),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _buildSectionTitle(
                  'Categories',
                  onTap: () => setState(() => _selectedCategory = 'All'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 95,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final bool selected = _selectedCategory == category['name'];

                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = category['name']),
                        child: Container(
                          width: 72,
                          decoration: BoxDecoration(
                            color: selected ? primaryPurple : lightPurple,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                category['icon'],
                                color: selected ? Colors.white : primaryPurple,
                                size: 28,
                              ),
                              const SizedBox(height: 7),
                              Text(
                                category['name'],
                                style: TextStyle(
                                  color: selected ? Colors.white : Colors.black87,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
                _buildSectionTitle(
                  _selectedCategory == 'All' ? 'Popular Services' : _selectedCategory,
                ),
                const SizedBox(height: 14),
                if (_filteredServices.isEmpty)
                  _buildEmptyState()
                else
                  ..._filteredServices.map(
                        (service) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildServiceCard(service),
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(String title, {VoidCallback? onTap}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const Spacer(),
        if (onTap != null)
          TextButton(
            onPressed: onTap,
            child: const Text(
              'View All',
              style: TextStyle(color: primaryPurple),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // SERVICE CARD
  // ============================================================

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final String id = service['id'].toString();
    final bool favourite = _favourites.contains(id);
    final String? imagePath = service['image'];

    return GestureDetector(
      onTap: () => _showServiceDetails(service),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: lightPurple,
                borderRadius: BorderRadius.circular(16),
                image: imagePath != null
                    ? DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.cover,
                )
                    : null,
              ),
              child: imagePath != null
                  ? null
                  : Icon(
                service['icon'] as IconData,
                color: primaryPurple,
                size: 40,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service['name'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    service['description'].toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        service['isProduct'] == true
                            ? Icons.inventory_2
                            : Icons.access_time,
                        size: 14,
                        color: primaryPurple,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        service['duration'].toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'R${(service['price'] as num).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: primaryPurple,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                IconButton(
                  icon: Icon(
                    favourite ? Icons.favorite : Icons.favorite_border,
                    color: favourite ? Colors.red : Colors.grey,
                  ),
                  onPressed: () async {
                    final user = _auth.currentUser;
                    if (user == null) return;

                    final serviceId = service['id'] ?? service['title'];
                    final favRef = _firestore
                        .collection('users')
                        .doc(user.uid)
                        .collection('favorites')
                        .doc(serviceId);

                    setState(() {
                      if (_favourites.contains(serviceId)) {
                        _favourites.remove(serviceId);
                      } else {
                        _favourites.add(serviceId);
                      }
                    });

                    if (_favourites.contains(serviceId)) {
                      await favRef.set({
                        'name': service['title'] ?? service['name'],
                        'price': service['price'],
                        'description': service['description'] ?? '',
                        'addedAt': FieldValue.serverTimestamp(),
                      });
                    } else {
                      await favRef.delete();
                    }
                  },
                ),
                Container(
                  decoration: BoxDecoration(
                    color: primaryPurple,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    onPressed: () => _addToCart(service),
                    icon: const Icon(Icons.add, color: Colors.white),
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
  // EMPTY STATE & BUTTONS
  // ============================================================

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: lightPurple,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off, color: primaryPurple, size: 50),
          const SizedBox(height: 12),
          const Text(
            'No services found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Try another search or category.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildCartButton() {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          onPressed: () => _openCart(),
          icon: const Icon(Icons.shopping_bag_outlined, color: Colors.black87),
        ),
        if (_cartItemCount > 0)
          Positioned(
            right: 4,
            top: 5,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                _cartItemCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.black87),
    );
  }

  // ============================================================
  // CART SCREEN
  // ============================================================

  void _openCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.80,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text(
                        'Your Cart',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text('$_cartItemCount items', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _cart.isEmpty
                        ? _buildEmptyCart()
                        : ListView.separated(
                      itemCount: _cart.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = _cart[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: lightPurple,
                            child: Icon(item['icon'], color: primaryPurple),
                          ),
                          title: Text(
                            item['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'R${(item['price'] as num).toStringAsFixed(2)} × ${item['quantity']}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              _removeFromCart(index);
                              setModalState(() {});
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
                            const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text(
                              'R${_cartTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                color: primaryPurple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _checkout();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'PROCEED TO CHECKOUT',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 70, color: Colors.grey[400]),
          const SizedBox(height: 15),
          const Text('Your cart is empty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Add a beauty service to get started.', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  // ============================================================
  // CHECKOUT WITH COURIER SELECTION & PAYSTACK INTEGRATION
  // ============================================================

  Future<void> _checkout() async {
    if (_cart.isEmpty) {
      _showMessage('Your cart is empty.');
      return;
    }

    final user = _currentUser;
    if (user == null || user.email == null || user.email!.isEmpty) {
      _showMessage('Please log in to complete checkout.');
      return;
    }

    final List<Map<String, dynamic>> shippingOptions = [
      {
        'id': 'door_express',
        'title': 'The Courier Guy - Overnight Express',
        'price': 125.0,
        'days': '1 - 2 Business Days',
        'type': 'door',
      },
      {
        'id': 'door_economy',
        'title': 'The Courier Guy - Economy Road',
        'price': 85.0,
        'days': '2 - 4 Business Days',
        'type': 'door',
      },
      {
        'id': 'kiosk_locker',
        'title': 'Pudo Kiosk / Locker Collection',
        'price': 60.0,
        'days': '1 - 3 Business Days',
        'type': 'kiosk',
      },
    ];

    Map<String, dynamic> selectedShipping = shippingOptions[0];
    final TextEditingController streetController = TextEditingController();
    final TextEditingController cityController = TextEditingController();
    final TextEditingController postalCodeController = TextEditingController();
    KioskLocation? chosenKiosk;

    // STEP 1: DELIVERY SELECTION DIALOG
    final bool? deliveryConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double grandTotal = _cartTotal + (selectedShipping['price'] as double);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Delivery & Shipping Method'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Courier Rate:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...shippingOptions.map((option) {
                      return RadioListTile<Map<String, dynamic>>(
                        value: option,
                        groupValue: selectedShipping,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          option['title'] as String,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('R${(option['price'] as double).toStringAsFixed(2)} · ${option['days']}'),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedShipping = val);
                        },
                      );
                    }),
                    const Divider(),
                    if (selectedShipping['type'] == 'door') ...[
                      const Text('Delivery Address:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: streetController,
                        decoration: const InputDecoration(
                          labelText: 'Street Address',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: cityController,
                        decoration: const InputDecoration(
                          labelText: 'City / Suburb',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: postalCodeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Postal Code',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ] else ...[
                      const Text('Select Kiosk Location:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.map, color: primaryPurple),
                        label: Text(
                          chosenKiosk == null ? 'Choose Nearby Kiosk' : chosenKiosk!.name,
                          style: const TextStyle(color: primaryPurple),
                        ),
                        onPressed: () async {
                          final KioskLocation? result = await showDialog<KioskLocation>(
                            context: context,
                            builder: (context) => const KioskPickerDialog(),
                          );
                          if (result != null) {
                            setModalState(() {
                              chosenKiosk = result;
                            });
                          }
                        },
                      ),
                      if (chosenKiosk != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '${chosenKiosk!.address} (${chosenKiosk!.distanceInKm?.toStringAsFixed(1)} km away)',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                    ],
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Items Subtotal:'),
                        Text('R${_cartTotal.toStringAsFixed(2)}'),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Courier Fee:'),
                        Text('R${(selectedShipping['price'] as double).toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          'R${grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: primaryPurple, fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedShipping['type'] == 'door' &&
                        (streetController.text.trim().isEmpty || cityController.text.trim().isEmpty)) {
                      _showMessage('Please enter your street address and city.');
                      return;
                    }
                    if (selectedShipping['type'] == 'kiosk' && chosenKiosk == null) {
                      _showMessage('Please pick a kiosk location.');
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('PROCEED TO PAYMENT'),
                ),
              ],
            );
          },
        );
      },
    );

    if (deliveryConfirmed != true || !mounted) return;

    // STEP 2: LAUNCH PAYSTACK
    final double grandTotal = _cartTotal + (selectedShipping['price'] as double);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: primaryPurple),
      ),
    );

    try {
      final paymentService = PaymentService();
      final orderId = 'ORD_${DateTime.now().millisecondsSinceEpoch}';
      final amountInCents = (grandTotal * 100).toInt();

      final initResult = await paymentService.initializePayment(
        email: user.email!,
        amountInCents: amountInCents,
        bookingId: orderId,
        serviceName: 'Marketplace Order (${_cart.length} items)',
      );

      if (mounted) Navigator.pop(context); // Dismiss loading spinner

      if (mounted) {
        final bool? isPaid = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => PaystackCheckoutScreen(
              authorizationUrl: initResult.authorizationUrl,
              reference: initResult.reference,
            ),
          ),
        );

        if (isPaid == true && mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(color: primaryPurple),
            ),
          );

          final verification = await paymentService.verifyPayment(
            reference: initResult.reference,
          );

          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }

          if (verification.success && mounted) {
            final summary = _cart.map((i) => i['name'] ?? 'Product').join(', ');
            final addressDetails = selectedShipping['type'] == 'kiosk'
                ? '${chosenKiosk!.name} (${chosenKiosk!.address})'
                : '${streetController.text.trim()}, ${cityController.text.trim()}, ${postalCodeController.text.trim()}';

            final currentOrderId = DateTime.now().millisecondsSinceEpoch.toString();

            await _firestore.collection('orders').doc(currentOrderId).set({
              'orderId': currentOrderId,
              'userId': user.uid,
              'userEmail': user.email,
              'serviceName': summary.isEmpty ? 'Marketplace Order' : summary,
              'items': List.from(_cart),
              'totalAmount': grandTotal,
              'price': grandTotal,
              'shippingMethod': selectedShipping['title'] ?? 'Standard Delivery',
              'deliveryMethod': selectedShipping['title'] ?? 'Standard Delivery',
              'shippingAddress': addressDetails,
              'deliveryAddress': addressDetails,
              'status': 'confirmed',
              'paymentStatus': 'paid',
              'paymentReference': initResult.reference,
              'createdAt': FieldValue.serverTimestamp(),
            });

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;

              setState(() {
                _cart.clear();
              });

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Order Confirmed!'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Receipt Ref: ${initResult.reference}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text('Method: ${selectedShipping['title']}'),
                      Text('Est. Delivery: ${selectedShipping['days']}'),
                      Text('Total Paid: R${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  actions: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const OrdersScreen()),
                        );
                      },
                      child: const Text('VIEW MY ORDERS'),
                    ),
                  ],
                ),
              );
            });
          } else if (mounted) {
            _showMessage(verification.message ?? 'Payment verification failed.');
          }
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage('Error processing checkout: $e');
    }
  }

  // ============================================================
  // PROFILE TAB
  // ============================================================

  Widget _buildProfileTab() {
    final user = _currentUser;
    final String userName = user?.displayName ?? _userName;
    final String userEmail = user?.email ?? '';
    final String initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text(
          "My Profile",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B3F98), Color(0xFF8E44AD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  backgroundImage: (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                      ? Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7B3F98),
                    ),
                  )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userEmail,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildProfileMenuItem(
            icon: Icons.person_outline,
            title: "Personal Information",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserInfoScreen()),
            ),
          ),
          _buildProfileMenuItem(
            icon: Icons.favorite_outline,
            title: "My Favourites",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesPage()),
            ),
          ),
          _buildProfileMenuItem(
            icon: Icons.card_giftcard,
            title: "Loyalty Card",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoyaltyScreen()),
            ),
          ),
          _buildProfileMenuItem(
            icon: Icons.shopping_bag_outlined,
            title: "My Activities",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrdersScreen()),
            ),
          ),
          _buildProfileMenuItem(
            icon: Icons.help_outline,
            title: "Help & Support",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportScreen()),
            ),
          ),
          _buildProfileMenuItem(
            icon: Icons.settings_outlined,
            title: "Settings",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE53935)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.logout, color: Color(0xFFE53935), size: 18),
            label: const Text(
              "LOGOUT",
              style: TextStyle(
                color: Color(0xFFE53935),
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            onPressed: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF7B3F98), size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.black54, size: 20),
        onTap: onTap,
      ),
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
  // NAVIGATION ROUTER
  // ============================================================

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return const BookingPage();
      case 2:
        return _buildMessages();
      case 3:
        return _buildProfileTab();
      default:
        return _buildDashboard();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildCurrentPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.white,
        indicatorColor: lightPurple,
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: primaryPurple),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today, color: primaryPurple),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble, color: primaryPurple),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: primaryPurple),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}