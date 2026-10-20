import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'simulated_payment.dart';
import 'credit_helper.dart';
import 'kiosk_picker_dialog.dart';
import 'address_autocomplete.dart';
import 'booking_page.dart';
import 'refunds.dart';
import 'package:provider/provider.dart';
import 'notifications_screen.dart';
import 'notification_prefs_service.dart';
import 'promo_popup.dart';
import 'product_reviews.dart';
import 'appointment_verification.dart';
import 'salon_info.dart';

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

  // ---- Hero carousel ----
  final PageController _heroController = PageController();
  Timer? _heroTimer;
  int _heroIndex = 0;
  Map<String, dynamic>? _livePromo; // promo of the week (from Firestore)

  // ---- Product filter + list/grid view ----
  bool _gridView = false;
  String _sortBy = 'Featured'; // Featured | Price: low to high | Price: high to low | Name: A-Z
  double? _maxPrice; // null = no limit
  final Set<String> _favourites = {};

  // ============================================================
  // ADMIN-MANAGED PRODUCTS (live from Firestore)
  // ============================================================

  List<Map<String, dynamic>>? _remoteItems;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSub;
  // Home banner edited by the admin (settings/banner).
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _bannerSub;
  List<Map<String, dynamic>> _banners = [];

  // The admin can add 1 to 5 banners (settings/banner -> banners).
  static const int _maxBanners = 5;

  void _listenToBanner() {
    _bannerSub = _firestore
        .collection('settings')
        .doc('banner')
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _banners = _parseBanners(snap.data()));
    }, onError: (_) {});
  }

  /// Reads the banner list. Supports the new format (`banners` = a list of up
  /// to 5 banners) and the old format (one banner stored on the document itself).
  List<Map<String, dynamic>> _parseBanners(Map<String, dynamic>? data) {
    if (data == null) return [];
    final List<Map<String, dynamic>> source = [];
    final raw = data['banners'];
    if (raw is List) {
      for (final b in raw) {
        if (b is Map) source.add(Map<String, dynamic>.from(b));
      }
    } else {
      source.add(data); // old single-banner format
    }
    bool hasContent(Map<String, dynamic> b) => [
      'title',
      'subtitle',
      'buttonText',
      'imageUrl',
    ].any((k) => (b[k] ?? '').toString().trim().isNotEmpty);
    return source
        .where((b) => b['active'] != false && hasContent(b))
        .take(_maxBanners)
        .toList();
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'Hair':
        return Icons.content_cut;
      case 'Nails':
        return Icons.brush;
      case 'Press-ons':
        return Icons.back_hand;
      case 'Makeup':
        return Icons.face;
      case 'Lashes':
        return Icons.remove_red_eye;
      case 'Skincare':
        return Icons.spa;
      default:
        return Icons.shopping_bag;
    }
  }

  ImageProvider _img(String path) =>
      path.startsWith('http') ? NetworkImage(path) : AssetImage(path);

  /// Picks the live "promo of the week" (active, started, not expired).
  void _capturePromo(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final now = DateTime.now();
    Map<String, dynamic>? best;
    DateTime bestCreated = DateTime.fromMillisecondsSinceEpoch(0);
    for (final d in docs) {
      final m = d.data();
      if (m['kind'] != 'promo' || m['active'] != true) continue;
      final starts = (m['startsAt'] as Timestamp?)?.toDate();
      final ends = (m['endsAt'] as Timestamp?)?.toDate();
      if (starts != null && starts.isAfter(now)) continue;
      if (ends != null && ends.isBefore(now)) continue;
      final created = (m['createdAt'] as Timestamp?)?.toDate() ?? bestCreated;
      if (best == null || created.isAfter(bestCreated)) {
        best = m;
        bestCreated = created;
      }
    }
    if (mounted) setState(() => _livePromo = best);
  }

  void _listenToProducts() {
    _productsSub =
        _firestore.collection('products').snapshots().listen((snap) {
          // Keep the built-in list until products exist in Firestore.
          _capturePromo(snap.docs);
          final docs = snap.docs.where((d) => d.data()['kind'] != 'promo').toList();
          if (docs.isEmpty) return;
          final items = docs.map((d) {
            final data = d.data();
            final category = (data['category'] ?? 'Hair').toString();
            final url = (data['imageUrl'] ?? '').toString();
            final asset = (data['image'] ?? '').toString();
            final image = url.isNotEmpty ? url : (asset.isNotEmpty ? asset : null);
            final deleteAt = data['pendingDeletion'] == true
                ? (data['deleteAt'] as Timestamp?)?.toDate()
                : null;
            // Sale: the owner puts items on sale in the admin page. A sale set to run
            // "with the promo of the week" is only on while a promo is live.
            final double basePrice = ((data['price'] as num?) ?? 0).toDouble();
            final double salePct = ((data['salePercent'] as num?) ?? 0).toDouble();
            final bool saleOn = data['saleActive'] == true &&
                salePct > 0 &&
                salePct < 100 &&
                (data['saleMode'] != 'promo' || _livePromo != null);
            final double finalPrice =
            saleOn ? (basePrice * (100 - salePct)).round() / 100 : basePrice;
            return <String, dynamic>{
              'id': d.id,
              'name': data['name'] ?? '',
              'category': category,
              'description': data['description'] ?? '',
              'price': finalPrice,
              if (saleOn) 'originalPrice': basePrice,
              if (saleOn) 'salePercent': salePct,
              'duration': data['duration'] ?? 'Product',
              if (data['isProduct'] == true) 'isProduct': true,
              'icon': _iconFor(category),
              if (image != null) 'image': image,
              if (deleteAt != null) 'deleteAt': deleteAt,
            };
          }).toList();
          if (mounted) setState(() => _remoteItems = items);
          _repriceCart(items);
        }, onError: (_) {});
  }

  // ============================================================
  // CATEGORIES
  // ============================================================

  /// Only real products (no services), hiding ones that are already leaving.
  List<Map<String, dynamic>> get _productItems {
    final DateTime now = DateTime.now();
    return (_remoteItems ?? _sampleServices).where((item) {
      if (item['isProduct'] != true) return false;
      final DateTime? deleteAt = item['deleteAt'] as DateTime?;
      return deleteAt == null || deleteAt.isAfter(now);
    }).toList();
  }

  /// Categories come from the products the client can actually see.
  List<Map<String, dynamic>> get _categories {
    final List<String> names = [];
    for (final p in _productItems) {
      final String c = (p['category'] ?? '').toString().trim();
      if (c.isNotEmpty && !names.contains(c)) names.add(c);
    }
    return <Map<String, dynamic>>[
      {'name': 'All', 'icon': Icons.apps},
      for (final n in names) {'name': n, 'icon': _iconFor(n)},
    ];
  }

  /// The selected category, or 'All' if that category no longer has products.
  String get _activeCategory {
    return _categories.any((c) => c['name'] == _selectedCategory)
        ? _selectedCategory
        : 'All';
  }

  // ============================================================
  // SAMPLE PRODUCTS (shown until the admin adds products)
  // ============================================================

  final List<Map<String, dynamic>> _sampleServices = [
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
    _listenToProducts();
    _listenToBanner();
    _loadCart();
    _loadViewPrefs();
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_heroController.hasClients) return;
      final count = _heroSlides().length;
      final cur = _heroController.page?.round() ?? 0;
      _heroController.animateToPage(
        (cur + 1) % count,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) PromoPopup.showIfAvailable(context);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _heroTimer?.cancel();
    _heroController.dispose();
    _productsSub?.cancel();
    _bannerSub?.cancel();
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
    final String category = _activeCategory;

    return _productItems.where((product) {
      final String name = product['name'].toString().toLowerCase();
      final String cat = product['category'].toString().toLowerCase();

      final bool matchesSearch =
          search.isEmpty || name.contains(search) || cat.contains(search);

      final bool matchesCategory =
          category == 'All' || product['category'] == category;

      final bool matchesPrice =
          _maxPrice == null || (product['price'] as num).toDouble() <= _maxPrice!;

      return matchesSearch && matchesCategory && matchesPrice;
    }).toList()
      ..sort((a, b) {
        switch (_sortBy) {
          case 'Price: low to high':
            return (a['price'] as num).compareTo(b['price'] as num);
          case 'Price: high to low':
            return (b['price'] as num).compareTo(a['price'] as num);
          case 'Name: A-Z':
            return a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase());
          default:
            return 0; // Featured = the order the owner added them
        }
      });
  }

  int get _activeFilterCount =>
      (_sortBy != 'Featured' ? 1 : 0) + (_maxPrice != null ? 1 : 0);

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
    _saveCart();
    _showMessage('${service['name']} added to cart.', isError: false);
  }

  /// Cart lines saved on the phone can hold an old price. Refresh them from the live list
  /// so a sale that has ended is never charged, and a new sale is applied.
  void _repriceCart(List<Map<String, dynamic>> items) {
    bool changed = false;
    for (final c in _cart) {
      for (final i in items) {
        if (i['id'].toString() != c['id'].toString()) continue;
        final num fresh = i['price'] as num;
        if ((c['price'] as num?) != fresh) {
          c['price'] = fresh;
          changed = true;
        }
        break;
      }
    }
    if (changed && mounted) {
      setState(() {});
      _saveCart();
    }
  }

  int get _saleCount => (_remoteItems ?? const <Map<String, dynamic>>[])
      .where((i) => i['originalPrice'] != null)
      .length;

  double get _maxSalePercent =>
      (_remoteItems ?? const <Map<String, dynamic>>[]).fold<double>(0, (m, i) {
        if (i['originalPrice'] == null) return m;
        final double pct = (i['salePercent'] as num).toDouble();
        return pct > m ? pct : m;
      });

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
    _saveCart();
  }

  // ---- Cart is saved on the phone (per user) so it survives closing the app.
  // Only plain values are stored; the icon is rebuilt from the category.
  String get _cartKey => 'kk_cart_${_auth.currentUser?.uid ?? 'guest'}';

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_cart.isEmpty) {
        await prefs.remove(_cartKey);
        return;
      }
      final plain = _cart
          .map((i) => <String, dynamic>{
        'id': i['id']?.toString(),
        'name': (i['name'] ?? '').toString(),
        'category': (i['category'] ?? '').toString(),
        'description': (i['description'] ?? '').toString(),
        'price': (i['price'] as num?) ?? 0,
        'duration': (i['duration'] ?? '').toString(),
        if (i['isProduct'] == true) 'isProduct': true,
        if (i['image'] is String) 'image': i['image'],
        'quantity': (i['quantity'] as num?)?.toInt() ?? 1,
      })
          .toList();
      await prefs.setString(_cartKey, jsonEncode(plain));
    } catch (e) {
      debugPrint('Could not save cart: $e');
    }
  }

  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_cartKey);
      if (saved == null || saved.isEmpty) return;
      final list = (jsonDecode(saved) as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        for (final item in list) {
          final id = item['id']?.toString();
          if (_cart.any((c) => c['id'] == id)) continue; // added while loading
          _cart.add({
            ...item,
            'icon': _iconFor((item['category'] ?? '').toString()),
          });
        }
      });
      final remote = _remoteItems;
      if (remote != null) _repriceCart(remote);
    } catch (e) {
      debugPrint('Could not load cart: $e');
    }
  }

  Future<void> _loadViewPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final grid = prefs.getBool('kk_grid_view') ?? false;
      if (mounted) setState(() => _gridView = grid);
    } catch (_) {}
  }

  Future<void> _setGridView(bool grid) async {
    setState(() => _gridView = grid);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('kk_grid_view', grid);
    } catch (_) {}
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

  /// +25 loyalty points for a purchase. The Firestore rules check that the order
  /// is yours and brand new, and each order can only be claimed once.
  Future<void> _awardPurchasePoints(String orderId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final userRef = _firestore.collection('users').doc(user.uid);
      final claimId = 'order_$orderId';
      final batch = _firestore.batch();
      batch.set(userRef.collection('claims').doc(claimId), {
        'type': 'order',
        'refId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(userRef, {
        'points': FieldValue.increment(25),
        'lastClaimId': claimId,
      });
      await batch.commit();
    } catch (e) {
      debugPrint('Purchase points failed: $e');
      // Points are a bonus. Never block or fail a checkout because of them.
    }
  }

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

    try {
      await NotificationPrefsService().unregisterToken();
    } catch (_) {}

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
                      GestureDetector(
                        onTap: imagePath != null
                            ? () => showFullImage(context, imagePath,
                            title: service['name'].toString())
                            : null,
                        child: Container(
                          height: imagePath != null ? 200 : 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: lightPurple,
                            borderRadius: BorderRadius.circular(20),
                            image: imagePath != null
                                ? DecorationImage(
                              image: _img(imagePath),
                              fit: BoxFit.cover,
                            )
                                : null,
                          ),
                          child: imagePath != null
                              ? Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.zoom_out_map,
                                        size: 14, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text('Tap to enlarge',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          )
                              : Icon(
                            service['icon'] as IconData,
                            size: 55,
                            color: primaryPurple,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ReviewSummaryButton(
                        productId: service['id'].toString(),
                        productName: service['name'].toString(),
                        isProduct: service['isProduct'] == true,
                      ),
                      const SizedBox(height: 10),
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
                          if (service['isProduct'] != true) ...[
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
              const NotificationBell(),
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
                      hintText: 'Search products...',
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
                _buildHeroCarousel(),
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
                      final bool selected = _activeCategory == category['name'];

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
                  _activeCategory == 'All' ? 'Products' : _activeCategory,
                ),
                const SizedBox(height: 10),
                _buildFilterBar(),
                const SizedBox(height: 14),
                if (_filteredServices.isEmpty)
                  _buildEmptyState()
                else if (_gridView)
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.66,
                    children: _filteredServices.map(_buildServiceTile).toList(),
                  )
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
  // REVIEWS (visible to every signed-in client)
  // ============================================================

  void _openReviews(Map<String, dynamic> service) {
    showProductReviews(
      context,
      productId: service['id'].toString(),
      productName: service['name'].toString(),
      isProduct: service['isProduct'] == true,
    );
  }

  // ============================================================
  // HERO CAROUSEL: Book now / Promotion of the week / Earn points
  // ============================================================

  /// The admin's banners (1 to 5). If there are none, the built-in slides are shown.
  List<Widget> _heroSlides() {
    if (_banners.isNotEmpty) {
      return [for (final b in _banners.take(_maxBanners)) _heroBanner(b)];
    }
    return <Widget>[
      _heroBanner(null),
      if (_livePromo != null) _heroPromo(_livePromo!),
      _heroPoints(),
    ];
  }

  Widget _buildHeroCarousel() {
    final slides = _heroSlides();
    final int current = _heroIndex.clamp(0, slides.length - 1);
    return Column(
      children: [
        SizedBox(
          height: 215,
          child: PageView(
            controller: _heroController,
            onPageChanged: (i) => setState(() => _heroIndex = i),
            children: slides,
          ),
        ),
        const SizedBox(height: 10),
        if (slides.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              slides.length,
                  (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == current ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == current ? primaryPurple : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// What the banner button does: open the linked product (details sheet),
  /// open the linked service on the booking page, or go to the Bookings tab.
  void _openBannerLink(Map<String, dynamic>? b) {
    final String linkId = (b?['linkId'] ?? '').toString();
    if (linkId.isEmpty) {
      setState(() => _selectedIndex = 1);
      return;
    }
    final String type = (b?['linkType'] ?? '').toString();
    final List<Map<String, dynamic>> all =
        _remoteItems ?? _sampleServices;
    final int at = all.indexWhere((i) => i['id'].toString() == linkId);
    if (at < 0) {
      _showMessage('Sorry, this item is no longer available.');
      return;
    }
    final Map<String, dynamic> item = all[at];
    if (item['isProduct'] == true || type == 'product') {
      _showServiceDetails(item);
    } else {
      final String dur = (item['duration'] ?? '1 hr').toString();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingPage(
            preselectedService: {
              'id': item['id'],
              'name': item['name'],
              'category': item['category'],
              'description': item['description'],
              'price': item['price'],
              'durationMins': _minutesFrom(dur),
              'duration': dur,
              'icon': item['icon'],
            },
          ),
        ),
      );
    }
  }

  /// "1 hr 30 mins" -> 90
  int _minutesFrom(String s) {
    final h = RegExp(r'(\d+(?:\.\d+)?)\s*(?:h|hr|hrs|hour|hours)', caseSensitive: false).firstMatch(s);
    final m = RegExp(r'(\d+)\s*(?:m|min|mins|minute|minutes)', caseSensitive: false).firstMatch(s);
    final total = (h != null ? (double.parse(h.group(1)!) * 60).round() : 0) +
        (m != null ? int.parse(m.group(1)!) : 0);
    return total > 0 ? total : (int.tryParse(s.trim()) ?? 60);
  }

  Widget _heroBanner(Map<String, dynamic>? b) {
    String pick(String key, String fallback) {
      final v = b != null ? (b[key] ?? '').toString().trim() : '';
      return v.isNotEmpty ? v : fallback;
    }
    final String title = pick('title', 'YOUR BEAUTY,\nYOUR WAY.');
    final String subtitle = pick('subtitle', 'Book your next appointment with Kotton Kandy.');
    final bool linksProduct = (b?['linkType'] ?? '').toString() == 'product';
    final String buttonText = pick('buttonText', linksProduct ? 'SHOP NOW' : 'BOOK NOW');
    final String img = b != null ? (b['imageUrl'] ?? '').toString() : '';
    final bool hasImg = img.startsWith('http');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        color: primaryPurple,
        borderRadius: BorderRadius.circular(24),
        image: hasImg
            ? DecorationImage(
          image: NetworkImage(img),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.40), BlendMode.darken),
        )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold, height: 1.2),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _openBannerLink(b),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryPurple,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(buttonText),
                ),
              ],
            ),
          ),
          if (!hasImg) ...[
            const SizedBox(width: 10),
            const Icon(Icons.spa, color: Colors.white54, size: 80),
          ],
        ],
      ),
    );
  }

  Widget _heroPromo(Map<String, dynamic> promo) {
    final String title = (promo['title'] ?? 'Promotion of the week').toString();
    final String text = (promo['description'] ?? promo['message'] ?? '').toString();
    final String img = (promo['imageUrl'] ?? '').toString();
    final DateTime? ends = (promo['endsAt'] as Timestamp?)?.toDate();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: primaryPurple,
        borderRadius: BorderRadius.circular(24),
        image: img.startsWith('http')
            ? DecorationImage(
          image: NetworkImage(img),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.45), BlendMode.darken),
        )
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'PROMOTION OF THE WEEK',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
          if (ends != null || _saleCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (_saleCount > 0) 'Up to ${_maxSalePercent.toStringAsFixed(0)}% off selected items',
                if (ends != null) 'Valid until ${ends.day}/${ends.month}/${ends.year}',
              ].join('  ·  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroPoints() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        color: fieldPurple,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'EARN POINTS\nWHILE YOU SHOP\nOR BOOK',
                  style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold, height: 1.2),
                ),
                SizedBox(height: 8),
                Text(
                  '+25 points per order  ·  +50 per appointment\n500 points = R100 credit',
                  style: TextStyle(color: Colors.white, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.stars_rounded, color: Colors.white70, size: 80),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER BAR + LIST / GRID TOGGLE
  // ============================================================

  Widget _buildFilterBar() {
    final int n = _activeFilterCount;
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _openFilterSheet,
          icon: const Icon(Icons.tune, size: 18),
          label: Text(n == 0 ? 'Filter' : 'Filter ($n)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryPurple,
            side: BorderSide(color: n == 0 ? Colors.grey.shade300 : primaryPurple),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        if (n > 0)
          TextButton(
            onPressed: () => setState(() {
              _sortBy = 'Featured';
              _maxPrice = null;
            }),
            child: const Text('Clear', style: TextStyle(color: Colors.grey)),
          ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            color: lightPurple,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _viewToggle(Icons.view_agenda_outlined, 'List view', !_gridView, () => _setGridView(false)),
              _viewToggle(Icons.grid_view_rounded, 'Tile view', _gridView, () => _setGridView(true)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _viewToggle(IconData icon, String tip, bool on, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: on ? primaryPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 20, color: on ? Colors.white : primaryPurple),
        ),
      ),
    );
  }

  void _openFilterSheet() {
    final all = _productItems;
    double top = 0;
    for (final s in all) {
      final v = (s['price'] as num).toDouble();
      if (v > top) top = v;
    }
    top = ((top / 50).ceil() * 50).toDouble();
    if (top < 100) top = 100;

    String sort = _sortBy;
    double maxP = (_maxPrice ?? top).clamp(0, top).toDouble();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Container(
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
                  const Text('Filter & sort', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 18),
                  const Text('Sort by', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: ['Featured', 'Price: low to high', 'Price: high to low', 'Name: A-Z']
                        .map((t) => ChoiceChip(
                      label: Text(t),
                      selected: sort == t,
                      selectedColor: lightPurple,
                      onSelected: (_) => setM(() => sort = t),
                    ))
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Text('Maximum price', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(maxP >= top ? 'Any' : 'R${maxP.toStringAsFixed(0)}',
                          style: const TextStyle(color: primaryPurple, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: maxP,
                    min: 0,
                    max: top,
                    divisions: (top / 10).round(),
                    activeColor: primaryPurple,
                    onChanged: (v) => setM(() => maxP = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setM(() {
                            sort = 'Featured';
                            maxP = top;
                          }),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _sortBy = sort;
                              _maxPrice = maxP >= top ? null : maxP;
                            });
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPurple,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TILE CARD (grid view: big clear picture)
  // ============================================================

  Widget _buildServiceTile(Map<String, dynamic> service) {
    final String id = service['id'].toString();
    final String? imagePath = service['image'];
    return GestureDetector(
      onTap: () => _showServiceDetails(service),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: imagePath != null
                    ? () => showFullImage(context, imagePath,
                    title: service['name'].toString())
                    : () => _openReviews(service),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: lightPurple,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          image: imagePath != null
                              ? DecorationImage(image: _img(imagePath), fit: BoxFit.cover)
                              : null,
                        ),
                        child: imagePath != null
                            ? null
                            : Icon(service['icon'] as IconData, color: primaryPurple, size: 50),
                      ),
                    ),
                    if (service['originalPrice'] != null)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD32F2F),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'SALE -${(service['salePercent'] as num).toStringAsFixed(0)}%',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: GestureDetector(
                        onTap: () => _toggleFavourite(service),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _favourites.contains(id) ? Icons.favorite : Icons.favorite_border,
                            color: _favourites.contains(id) ? Colors.red : Colors.grey,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    if (service['deleteAt'] != null)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Leaving soon',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: GestureDetector(
                        onTap: () => _openReviews(service),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: Color(0xFFF5A623), size: 13),
                              SizedBox(width: 3),
                              Text('Reviews', style: TextStyle(color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service['name'].toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _priceText(service, 15)),
                      _cartAddButton(service),
                      const SizedBox(width: 4),
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

  // ============================================================
  // ADD-TO-CART BUTTON (same look in list view and grid view)
  // ============================================================

  Widget _priceText(Map<String, dynamic> service, double size, {bool end = false}) {
    final double price = (service['price'] as num).toDouble();
    final num? original = service['originalPrice'] as num?;
    final Text now = Text(
      'R${price.toStringAsFixed(2)}',
      style: TextStyle(
        color: original != null ? const Color(0xFFD32F2F) : primaryPurple,
        fontWeight: FontWeight.bold,
        fontSize: size,
      ),
    );
    if (original == null) return now;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          'R${original.toStringAsFixed(2)}',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: size - 4,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        now,
      ],
    );
  }

  Future<void> _toggleFavourite(Map<String, dynamic> service) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final String serviceId = (service['id'] ?? service['title']).toString();
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

    try {
      if (_favourites.contains(serviceId)) {
        await favRef.set({
          'name': service['title'] ?? service['name'],
          'price': service['price'],
          'description': service['description'] ?? '',
          'category': service['category'] ?? '',
          if (service['image'] is String && (service['image'] as String).isNotEmpty)
            'image': service['image'],
          if (service['isProduct'] == true) 'isProduct': true,
          'addedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await favRef.delete();
      }
    } catch (e) {
      debugPrint('Could not update favourite: $e');
    }
  }

  Widget _cartAddButton(Map<String, dynamic> service) {
    return Container(
      decoration: BoxDecoration(
        color: primaryPurple,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        onPressed: () => _addToCart(service),
        icon: const Icon(Icons.add, color: Colors.white),
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
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: imagePath != null
                  ? () => showFullImage(context, imagePath,
                  title: service['name'].toString())
                  : () => _openReviews(service),
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: lightPurple,
                  borderRadius: BorderRadius.circular(16),
                  image: imagePath != null
                      ? DecorationImage(
                    image: _img(imagePath),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: imagePath != null
                    ? Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.zoom_out_map,
                        size: 12, color: Colors.white),
                  ),
                )
                    : Icon(
                  service['icon'] as IconData,
                  color: primaryPurple,
                  size: 40,
                ),
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
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              service['isProduct'] == true
                                  ? Icons.inventory_2
                                  : Icons.access_time,
                              size: 14,
                              color: primaryPurple,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                service['duration'].toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            if (service['deleteAt'] != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Leaving soon',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _priceText(service, 16, end: true),
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
                  onPressed: () => _toggleFavourite(service),
                ),
                _cartAddButton(service),
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
            'No products found',
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
                color: Color(0xFFD32F2F),
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
                          leading: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: lightPurple,
                              borderRadius: BorderRadius.circular(12),
                              image: (item['image'] is String && (item['image'] as String).isNotEmpty)
                                  ? DecorationImage(
                                image: _img(item['image'] as String),
                                fit: BoxFit.cover,
                              )
                                  : null,
                            ),
                            child: (item['image'] is String && (item['image'] as String).isNotEmpty)
                                ? null
                                : Icon(
                              (item['icon'] as IconData?) ?? Icons.shopping_bag_outlined,
                              color: primaryPurple,
                            ),
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
          Text('Add a product to get started.', style: TextStyle(color: Colors.grey[600])),
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
    PickedAddress? pickedAddress; // set when the customer picks a Google suggestion

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
                      OutlinedButton.icon(
                        icon: const Icon(Icons.search, color: primaryPurple),
                        label: Text(
                          pickedAddress == null ? 'Search your address' : 'Change address',
                          style: const TextStyle(color: primaryPurple),
                        ),
                        onPressed: () async {
                          final PickedAddress? result = await showAddressSearch(context);
                          if (result != null) {
                            setModalState(() {
                              pickedAddress = result;
                              streetController.text =
                              result.street.isNotEmpty ? result.street : result.formatted;
                              cityController.text = result.city;
                              postalCodeController.text = result.postalCode;
                            });
                          }
                        },
                      ),
                      if (pickedAddress != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            pickedAddress!.formatted,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: streetController,
                        onChanged: (_) {
                          if (pickedAddress != null) setModalState(() => pickedAddress = null);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Street Address',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: cityController,
                        onChanged: (_) {
                          if (pickedAddress != null) setModalState(() => pickedAddress = null);
                        },
                        decoration: const InputDecoration(
                          labelText: 'City / Suburb',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: postalCodeController,
                        onChanged: (_) {
                          if (pickedAddress != null) setModalState(() => pickedAddress = null);
                        },
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
                            builder: (context) => KioskPickerDialog(
                              nearLatitude: pickedAddress?.latitude,
                              nearLongitude: pickedAddress?.longitude,
                            ),
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

    // Loyalty credit: ask if the client wants to use it on this order.
    final double creditUsed = await CreditHelper.askToUseCredit(context, total: grandTotal);
    if (!mounted) return;
    final double payable = grandTotal - creditUsed;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: primaryPurple),
      ),
    );

    bool spinnerOpen = true;

    try {
      final paymentService = PaymentService();
      final orderId = 'ORD_${DateTime.now().millisecondsSinceEpoch}';
      final amountInCents = (payable * 100).round();

      final initResult = await paymentService.initializePayment(
        email: user.email!,
        amountInCents: amountInCents,
        bookingId: orderId,
        serviceName: 'Marketplace Order (${_cart.length} items)',
      );

      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading spinner
      spinnerOpen = false;

      if (mounted) {
        final bool? isPaid = await payWithSimulatedStepThenPaystack(
          context,
          amountInCents: amountInCents,
          authorizationUrl: initResult.authorizationUrl,
          reference: initResult.reference,
        );

        if (isPaid == true && mounted) {
          spinnerOpen = true;
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
          spinnerOpen = false;

          if (verification.success && mounted) {
            final summary = _cart.map((i) => i['name'] ?? 'Product').join(', ');
            final addressDetails = selectedShipping['type'] == 'kiosk'
                ? '${chosenKiosk!.name} (${chosenKiosk!.address})'
                : '${streetController.text.trim()}, ${cityController.text.trim()}, ${postalCodeController.text.trim()}';

            final currentOrderId = DateTime.now().millisecondsSinceEpoch.toString();

            try {
              await _firestore.collection('orders').doc(currentOrderId).set({
                'orderId': currentOrderId,
                'userId': user.uid,
                'userEmail': user.email,
                'serviceName': summary.isEmpty ? 'Marketplace Order' : summary,
                // Only plain values are saved (cart items also hold an icon object,
                // which Firestore cannot store and which made the save fail).
                'items': _cart
                    .map((i) => <String, dynamic>{
                  'id': i['id']?.toString(),
                  'name': (i['name'] ?? 'Product').toString(),
                  'category': i['category']?.toString(),
                  'price': (i['price'] as num?) ?? 0,
                  'quantity': (i['quantity'] as num?)?.toInt() ?? 1,
                  if (i['image'] is String) 'image': i['image'],
                })
                    .toList(),
                'totalAmount': grandTotal,
                'price': grandTotal,
                'creditUsed': creditUsed,
                'amountPaid': payable,
                'shippingMethod': selectedShipping['title'] ?? 'Standard Delivery',
                'deliveryMethod': selectedShipping['title'] ?? 'Standard Delivery',
                'shippingAddress': addressDetails,
                'deliveryAddress': addressDetails,
                'deliveryType': selectedShipping['type'] == 'kiosk' ? 'locker' : 'door',
                if (selectedShipping['type'] == 'kiosk' && chosenKiosk != null)
                  'locker': chosenKiosk!.toMap(),
                if (selectedShipping['type'] != 'kiosk')
                  'deliveryAddressData': pickedAddress != null
                      ? pickedAddress!.toMap()
                      : {
                    'formatted': addressDetails,
                    'street': streetController.text.trim(),
                    'city': cityController.text.trim(),
                    'postalCode': postalCodeController.text.trim(),
                  },
                'status': 'confirmed',
                'paymentStatus': 'paid',
                'paymentReference': initResult.reference,
                'createdAt': FieldValue.serverTimestamp(),
              });
            } catch (e) {
              _showMessage(
                  'Your payment went through (ref ${initResult.reference}) but we could not save your order. Please contact us with this reference.');
              return;
            }

            await CreditHelper.spendCredit(amount: creditUsed, refId: currentOrderId);
            await _awardPurchasePoints(currentOrderId);

            if (!mounted) return;
            setState(() {
              _cart.clear();
            });
            await _saveCart(); // order is complete: only now is the saved cart emptied

            final NavigatorState navigator = Navigator.of(context);
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
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
                    Text('Total Paid: R${payable.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, foregroundColor: Colors.white),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      navigator.push(
                        MaterialPageRoute(builder: (_) => const OrdersScreen(initialTab: 1)),
                      );
                    },
                    child: const Text('VIEW MY ORDERS'),
                  ),
                ],
              ),
            );
          } else if (mounted) {
            _showMessage(verification.message ?? 'Payment verification failed.');
          }
        }
      }
    } catch (e) {
      // Only close the spinner if it is still open. Popping anything else
      // would close the marketplace page and leave a black screen.
      if (spinnerOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      debugPrint('Checkout error: $e');
      _showMessage('Something went wrong with your checkout. Please try again.');
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
              color: primaryPurple,
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
            icon: Icons.verified_user_outlined,
            title: "Appointment Verification",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppointmentVerificationScreen()),
            ),
          ),
          _buildProfileMenuItem(
            icon: Icons.location_on_outlined,
            title: "Find the Salon",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SalonLocationScreen()),
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
            icon: Icons.receipt_long_outlined,
            title: "Refunds & Rescheduling",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RefundsPage()),
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
            color: Colors.black.withValues(alpha: 0.02),
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