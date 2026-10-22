import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'payment_service.dart';
import 'paystack_checkout_screen.dart';
import 'simulated_payment.dart';
import 'legal_pages.dart';
import 'credit_helper.dart';
import 'orders.dart';
import 'service_reviews.dart';

class BookingPage extends StatefulWidget {
  final Map<String, dynamic>? preselectedService;

  /// When set, the page works in "reschedule mode": the client picks a new
  /// date and time for this existing appointment and pays the reschedule fee.
  /// Must contain the appointment's data plus its document id under 'id'.
  final Map<String, dynamic>? rescheduleAppointment;

  const BookingPage({
    super.key,
    this.preselectedService,
    this.rescheduleAppointment,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final PaymentService _paymentService = PaymentService();

  static const Color primaryPurple = Color(0xFF6B3A82);
  static const Color lightPurple = Color(0xFFF3EAF6);
  static const double _rescheduleFee = 100.0;

  bool get _isReschedule => widget.rescheduleAppointment != null;

  // ---- Favourite services (same users/{uid}/favorites collection as the shop) ----
  final Set<String> _favourites = {};

  Future<void> _loadFavourites() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .get();
      if (mounted) {
        setState(() {
          _favourites
            ..clear()
            ..addAll(snap.docs.map((d) => d.id));
        });
      }
    } catch (e) {
      debugPrint('Could not load favourites: $e');
    }
  }

  Future<void> _toggleFavourite(Map<String, dynamic> service) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showMessage('Please log in to save favourites.');
      return;
    }
    final String id = service['id'].toString();
    final favRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(id);

    final bool adding = !_favourites.contains(id);
    setState(() {
      if (adding) {
        _favourites.add(id);
      } else {
        _favourites.remove(id);
      }
    });

    try {
      if (adding) {
        final String? img = _serviceImage(service);
        await favRef.set({
          'name': service['name'],
          'price': service['price'],
          'description': service['description'] ?? '',
          'category': service['category'] ?? '',
          if (img != null) 'image': img,
          'addedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await favRef.delete();
      }
    } catch (e) {
      debugPrint('Could not update favourite: $e');
      // Undo the heart if saving failed.
      if (mounted) {
        setState(() {
          if (adding) {
            _favourites.remove(id);
          } else {
            _favourites.add(id);
          }
        });
        _showMessage('Could not update your favourites. Please try again.');
      }
    }
  }

  String _selectedCategory = 'Press-ons';
  Map<String, dynamic>? _selectedService;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  bool _isLoading = false;
  bool _acceptedPolicy = false;
  File? _referenceImage;
  List<String> _availableTimeSlots = [];

  final List<String> _categories = [
    'Press-ons',
    'Lashes',
    'Hair',
    'Makeup',
  ];

  final List<Map<String, dynamic>> _salonServices = [
    {
      'id': 'press_on_plain',
      'name': 'Press-on Plain',
      'category': 'Press-ons',
      'description': 'Clean, simple, solid-color press-on set application.',
      'price': 250.00,
      'durationMins': 45,
      'duration': '45 mins',
      'icon': Icons.back_hand,
    },
    {
      'id': 'press_on_glam',
      'name': 'Press-on Glam',
      'category': 'Press-ons',
      'description': 'Glamorous press-on set with intricate design elements.',
      'price': 350.00,
      'durationMins': 60,
      'duration': '1 hour',
      'icon': Icons.brush,
    },
    {
      'id': 'press_on_installation',
      'name': 'Press-on Installation',
      'category': 'Press-ons',
      'description': 'Professional sizing, prep, and long-lasting application.',
      'price': 100.00,
      'durationMins': 30,
      'duration': '30 mins',
      'icon': Icons.pan_tool_alt,
    },
    {
      'id': 'cluster_lashes',
      'name': 'Cluster Lashes',
      'category': 'Lashes',
      'description': 'Full, beautiful cluster lash application.',
      'price': 200.00,
      'durationMins': 45,
      'duration': '45 mins',
      'icon': Icons.visibility,
    },
    {
      'id': 'classic_lashes',
      'name': 'Classic Lashes',
      'category': 'Lashes',
      'description': 'Natural-looking individual lash extensions.',
      'price': 250.00,
      'durationMins': 90,
      'duration': '1 hour 30 mins',
      'icon': Icons.visibility_outlined,
    },
    {
      'id': 'volume_lashes',
      'name': 'Volume Lashes',
      'category': 'Lashes',
      'description': 'Full and fluffy volume lash extensions.',
      'price': 300.00,
      'durationMins': 120,
      'duration': '2 hours',
      'icon': Icons.remove_red_eye,
    },
    {
      'id': 'afro_crotchet',
      'name': 'Afro Crotchet',
      'category': 'Hair',
      'description': 'Neat and lightweight Afro crotchet installation.',
      'price': 350.00,
      'durationMins': 120,
      'duration': '2 hours',
      'icon': Icons.face_retouching_natural,
    },
    {
      'id': 'box_braids',
      'name': 'Knotless / Box Braids',
      'category': 'Hair',
      'description': 'Full head protective braiding.',
      'price': 600.00,
      'durationMins': 240,
      'duration': '4 hours',
      'icon': Icons.spa,
    },
    {
      'id': 'wig_installation',
      'name': 'Wig Installation',
      'category': 'Hair',
      'description': 'Professional wig fitting, melting, and styling.',
      'price': 400.00,
      'durationMins': 90,
      'duration': '1 hour 30 mins',
      'icon': Icons.face,
    },
    {
      'id': 'soft_glam',
      'name': 'Soft Glam',
      'category': 'Makeup',
      'description': 'Seamless, radiant neutral glam makeup.',
      'price': 400.00,
      'durationMins': 60,
      'duration': '1 hour',
      'icon': Icons.auto_awesome,
    },
    {
      'id': 'full_glam',
      'name': 'Full Glam',
      'category': 'Makeup',
      'description': 'Full coverage, dramatic eye look, cut crease, and lashes.',
      'price': 500.00,
      'durationMins': 90,
      'duration': '1 hour 30 mins',
      'icon': Icons.auto_fix_high,
    },
  ];

  // ---- Services added by the admin (products collection, isProduct == false) ----
  List<Map<String, dynamic>> _remoteServices = [];
  bool _hasCatalog = false; // the admin has added items, so the built-in list is not used
  bool _catalogLoaded = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _servicesSub;

  static int _parseMins(String s) {
    final h = RegExp(r'(\d+(?:\.\d+)?)\s*(?:h|hr|hrs|hour|hours)', caseSensitive: false).firstMatch(s);
    final m = RegExp(r'(\d+)\s*(?:m|min|mins|minute|minutes)', caseSensitive: false).firstMatch(s);
    final t = (h != null ? (double.parse(h.group(1)!) * 60).round() : 0) +
        (m != null ? int.parse(m.group(1)!) : 0);
    return t > 0 ? t : (int.tryParse(s.trim()) ?? 60);
  }

  void _listenToServices() {
    _servicesSub = _firestore.collection('products').snapshots().listen((snap) {
      final list = <Map<String, dynamic>>[];
      int catalog = 0;
      // Is a promo of the week live? Sales set to run "with the promo" depend on it.
      final DateTime nowT = DateTime.now();
      final bool promoLive = snap.docs.any((d) {
        final m = d.data();
        if (m['kind'] != 'promo' || m['active'] != true) return false;
        final s = (m['startsAt'] as Timestamp?)?.toDate();
        final e = (m['endsAt'] as Timestamp?)?.toDate();
        if (s != null && s.isAfter(nowT)) return false;
        if (e != null && e.isBefore(nowT)) return false;
        return true;
      });
      for (final d in snap.docs) {
        final data = d.data();
        if (data['kind'] == 'promo') continue;
        catalog++;
        if (data['isProduct'] == true) continue;
        // Being deleted: stays visible (with a "Leaving soon" tag) until the timer runs out.
        final DateTime? deleteAt = data['pendingDeletion'] == true
            ? (data['deleteAt'] as Timestamp?)?.toDate()
            : null;
        if (deleteAt != null && !deleteAt.isAfter(DateTime.now())) continue;
        final name = (data['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final dur = (data['duration'] ?? '1 hr').toString();
        final double basePrice = ((data['price'] as num?) ?? 0).toDouble();
        final double salePct = ((data['salePercent'] as num?) ?? 0).toDouble();
        final bool saleOn = data['saleActive'] == true &&
            salePct > 0 &&
            salePct < 100 &&
            (data['saleMode'] != 'promo' || promoLive);
        list.add({
          'id': d.id,
          'name': name,
          'category': (data['category'] ?? 'Hair').toString(),
          'description': (data['description'] ?? '').toString(),
          'price': saleOn ? (basePrice * (100 - salePct)).round() / 100 : basePrice,
          if (saleOn) 'originalPrice': basePrice,
          if (saleOn) 'salePercent': salePct,
          'durationMins': (data['durationMins'] as num?)?.toInt() ?? _parseMins(dur),
          'duration': dur,
          'imageUrl': (data['imageUrl'] ?? '').toString(),
          'image': (data['image'] ?? '').toString(),
          'icon': Icons.auto_awesome,
          if (deleteAt != null) 'deleteAt': deleteAt,
        });
      }
      if (mounted) {
        setState(() {
          _remoteServices = list;
          _hasCatalog = catalog > 0;
          _catalogLoaded = true;
        });
      }
    }, onError: (_) {
      if (mounted) setState(() => _catalogLoaded = true);
    });
  }

  /// Built-in services plus the ones the admin added (admin copies win on a name clash).
  List<Map<String, dynamic>> get _allServices {
    if (!_catalogLoaded) return [];
    final now = DateTime.now();
    final remote = _remoteServices.where((s) {
      final d = s['deleteAt'] as DateTime?;
      return d == null || d.isAfter(now); // timer ran out: gone, even before the admin page cleans up
    }).toList();
    // Once the admin manages the list, the built-in copies are never mixed in
    // (otherwise a deleted service would keep showing from the built-in list).
    if (_hasCatalog) return remote;
    final names = remote.map((s) => s['name'].toString().toLowerCase()).toSet();
    return [
      ..._salonServices.where((s) => !names.contains(s['name'].toString().toLowerCase())),
      ...remote,
    ];
  }

  List<String> get _allCategories {
    final cats = [..._categories];
    for (final s in _remoteServices) {
      final c = s['category'].toString();
      if (!cats.contains(c)) cats.add(c);
    }
    return cats;
  }

  // ---- Admin-controlled availability (settings/availability) ----
  List<int> _openWeekdays = [0, 1, 2, 3, 4, 5, 6]; // 0 = Sunday
  Set<String> _blockedDates = {};
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _availSub;

  void _listenToAvailability() {
    _availSub = _firestore
        .collection('settings')
        .doc('availability')
        .snapshots()
        .listen((snap) {
      final d = snap.data();
      if (d == null) return;
      final days = (d['openWeekdays'] as List?)
          ?.map((e) => (e as num).toInt())
          .toList();
      final blocked = (d['blockedDates'] as List?)
          ?.map((e) => e.toString())
          .toSet();
      if (!mounted) return;
      setState(() {
        if (days != null) _openWeekdays = days;
        _blockedDates = blocked ?? <String>{};
        // Drop a previously chosen date that has just become unavailable.
        if (_selectedDate != null && !_isDateAvailable(_selectedDate!)) {
          _selectedDate = null;
          _selectedTimeSlot = null;
        }
      });
    }, onError: (_) {});
  }

  bool _isDateAvailable(DateTime date) {
    if (!_openWeekdays.contains(date.weekday % 7)) return false;
    final key =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return !_blockedDates.contains(key);
  }

  DateTime _firstAvailableDate() {
    var d = DateTime.now();
    for (int i = 0; i < 61; i++) {
      if (_isDateAvailable(d)) return d;
      d = d.add(const Duration(days: 1));
    }
    return DateTime.now();
  }

  /// The picture of a service (admin photo or bundled asset), or null if it has none.
  String? _serviceImage(Map<String, dynamic> service) {
    final url = (service['imageUrl'] ?? '').toString();
    if (url.isNotEmpty) return url;
    final asset = (service['image'] ?? '').toString();
    return asset.isNotEmpty ? asset : null;
  }

  /// Price at the bottom right of a service card (old price crossed out when on sale).
  Widget _priceBox(Map<String, dynamic> service) {
    final double price = (service['price'] as num).toDouble();
    final num? original = service['originalPrice'] as num?;
    if (original == null) {
      return Text(
        'R${price.toStringAsFixed(2)}',
        style: const TextStyle(color: primaryPurple, fontWeight: FontWeight.bold, fontSize: 16),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'R${original.toStringAsFixed(2)}',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        Text(
          'R${price.toStringAsFixed(2)}',
          style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  /// Turns any error into something a customer can understand. Technical details
  /// (Firebase, permissions, network) are only written to the debug log.
  String _friendlyError(Object e) {
    final String text = e.toString().replaceFirst('Exception: ', '');
    final String lower = text.toLowerCase();
    final bool technical = text.startsWith('[') ||
        lower.contains('firebase') ||
        lower.contains('firestore') ||
        lower.contains('permission') ||
        lower.contains('socketexception') ||
        lower.contains('exception') ||
        lower.contains('null');
    if (technical) {
      debugPrint('Booking error: $e');
      return 'Something went wrong. Please try again.';
    }
    return text;
  }

  Widget _serviceIconBox(Map<String, dynamic> service) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: lightPurple,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        (service['icon'] as IconData?) ?? Icons.auto_awesome,
        color: primaryPurple,
        size: 30,
      ),
    );
  }

  /// Square picture for a service. Tap it to see the whole picture full screen.
  Widget _serviceThumb(Map<String, dynamic> service) {
    final String? img = _serviceImage(service);
    if (img == null) return _serviceIconBox(service);
    final ImageProvider provider =
    img.startsWith('http') ? NetworkImage(img) : AssetImage(img);
    return GestureDetector(
      onTap: () => showFullImage(context, img, title: service['name'].toString()),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image(
                  image: provider,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _serviceIconBox(service),
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : Container(
                    color: lightPurple,
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: primaryPurple),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.zoom_out_map, size: 12, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _availSub?.cancel();
    _servicesSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _listenToAvailability();
    _listenToServices();
    _loadFavourites();
    if (widget.preselectedService != null) {
      _selectedService = widget.preselectedService;
      _selectedCategory = widget.preselectedService!['category'] ?? 'Press-ons';
    }
    if (widget.rescheduleAppointment != null) {
      // Same service and duration as the original booking.
      final a = widget.rescheduleAppointment!;
      _selectedService = {
        'id': a['serviceId'],
        'name': a['serviceName'] ?? 'Appointment',
        'category': a['category'],
        'price': (a['price'] as num?) ?? 0,
        'durationMins': a['durationMins'] ?? 60,
        'duration': a['duration'] ?? '',
      };
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  String _getDateString(DateTime date) {
    return date.toIso8601String().split('T')[0];
  }

  int _amountInCents(double amount) {
    return (amount * 100).round();
  }

  Future<void> _generateAvailableTimeSlots() async {
    if (_selectedDate == null || _selectedService == null) {
      setState(() => _availableTimeSlots = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bool isWeekend = _selectedDate!.weekday == DateTime.saturday ||
          _selectedDate!.weekday == DateTime.sunday;

      List<DateTime> potentialStarts = [];

      if (isWeekend) {
        DateTime current = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          8,
          0,
        );
        final DateTime endOfDay = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day + 1,
          0,
          0,
        );

        while (current.isBefore(endOfDay)) {
          potentialStarts.add(current);
          current = current.add(const Duration(hours: 1, minutes: 30));
        }
      } else {
        potentialStarts.add(DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          19,
          0,
        ));
        potentialStarts.add(DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          21,
          0,
        ));
      }

      final String dateStr = _getDateString(_selectedDate!);
      final QuerySnapshot existingBookings = await _firestore
          .collection('appointments')
          .where('date', isEqualTo: dateStr)
          .where('status', whereIn: ['pending', 'confirmed', 'paid', 'Confirmed', 'Paid'])
          .get();

      List<Map<String, DateTime>> bookedRanges = [];

      for (var doc in existingBookings.docs) {
        // The appointment being rescheduled must not block its own new slot.
        if (doc.id == widget.rescheduleAppointment?['id']) continue;
        final data = doc.data() as Map<String, dynamic>;
        final String timeSlot = data['timeSlot'] ?? '';
        final int durationMins = data['durationMins'] ?? 60;

        if (timeSlot.isNotEmpty) {
          final DateTime? startTime = _parseTimeString(_selectedDate!, timeSlot);
          if (startTime != null) {
            final DateTime endTime = startTime.add(Duration(minutes: durationMins));
            bookedRanges.add({'start': startTime, 'end': endTime});
          }
        }
      }

      final int selectedDurationMins = _selectedService!['durationMins'] ?? 60;
      List<String> validSlots = [];

      for (var start in potentialStarts) {
        final DateTime proposedEnd = start.add(Duration(minutes: selectedDurationMins));
        bool isOverlapping = false;

        for (var booked in bookedRanges) {
          if (start.isBefore(booked['end']!) && proposedEnd.isAfter(booked['start']!)) {
            isOverlapping = true;
            break;
          }
        }

        if (!isOverlapping) {
          validSlots.add(_formatTimeOfDay(start));
        }
      }

      // Moving to the exact same date and time is not a reschedule.
      if (_isReschedule && dateStr == widget.rescheduleAppointment!['date']) {
        validSlots.remove(widget.rescheduleAppointment!['timeSlot']);
      }

      if (mounted) {
        setState(() {
          _availableTimeSlots = validSlots;
        });
      }
    } catch (e) {
      debugPrint('Failed to load time slots: $e');
      _showMessage('Could not load the available times. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  DateTime? _parseTimeString(DateTime baseDate, String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      if (parts[1].toUpperCase() == 'PM' && hour < 12) hour += 12;
      if (parts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
      return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  String _formatTimeOfDay(DateTime dt) {
    int hour = dt.hour;
    final String period = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) hour = 12;
    if (hour > 12) hour -= 12;
    final String hourStr = hour.toString().padLeft(2, '0');
    final String minStr = dt.minute.toString().padLeft(2, '0');
    return '$hourStr:$minStr $period';
  }

  Future<void> _pickReferenceImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      imageQuality: 60,
    );
    if (image != null) {
      setState(() {
        _referenceImage = File(image.path);
      });
    }
  }

  Future<String?> _uploadReferenceImage(String bookingId) async {
    if (_referenceImage == null) return null;
    try {
      final Reference ref = _storage.ref().child('reference_photos/$bookingId.jpg');
      final UploadTask task = ref.putFile(_referenceImage!);
      final TaskSnapshot snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  /// Backup when Firebase Storage is not available: the (small, compressed) photo is
  /// saved inside the booking itself so the admin can still see it.
  Future<String?> _referenceImageAsBase64() async {
    if (_referenceImage == null) return null;
    try {
      final bytes = await _referenceImage!.readAsBytes();
      if (bytes.length > 700 * 1024) return null; // Firestore documents are limited to 1 MB
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Error reading image: $e');
      return null;
    }
  }

  Future<void> _submitBooking() async {
    if (_selectedService == null) {
      _showMessage('Please select a service.');
      return;
    }

    if (_selectedDate == null) {
      _showMessage('Please select an appointment date.');
      return;
    }

    if (_selectedTimeSlot == null) {
      _showMessage('Please select a time slot.');
      return;
    }

    if (!_isDateAvailable(_selectedDate!)) {
      _showMessage('Sorry, that date is no longer available. Please pick another.');
      setState(() {
        _selectedDate = null;
        _selectedTimeSlot = null;
      });
      return;
    }

    if (!_acceptedPolicy) {
      _showMessage('Please read and agree to the booking policy before paying.');
      return;
    }

    final User? user = _auth.currentUser;
    if (user == null || user.email == null || user.email!.isEmpty) {
      _showMessage('Please log in with a valid email account before booking.');
      return;
    }

    setState(() => _isLoading = true);

    String? bookingId;

    try {
      final double price = (_selectedService!['price'] as num).toDouble();

      // Loyalty credit: ask if the client wants to use it on this booking.
      final double creditUsed = await CreditHelper.askToUseCredit(context, total: price);
      if (!mounted) return;
      final int amountInCents = _amountInCents(price - creditUsed);

      final DocumentReference bookingRef = _firestore.collection('appointments').doc();
      bookingId = bookingRef.id;

      final String? imageUrl = await _uploadReferenceImage(bookingId);
      final String? imageData = (_referenceImage != null && imageUrl == null)
          ? await _referenceImageAsBase64()
          : null;
      final String formattedDate = _getDateString(_selectedDate!);

      await bookingRef.set({
        'id': bookingId,
        'bookingId': bookingId,
        'userId': user.uid,
        'userEmail': user.email,
        'serviceId': _selectedService!['id'],
        'serviceName': _selectedService!['name'],
        'category': _selectedService!['category'],
        'price': price,
        'creditUsed': creditUsed,
        'amountPaid': price - creditUsed,
        'durationMins': _selectedService!['durationMins'],
        'duration': _selectedService!['duration'],
        'date': formattedDate,
        'timeSlot': _selectedTimeSlot,
        'referencePhoto': imageUrl,
        if (imageData != null) 'referencePhotoData': imageData,
        'status': 'pending',
        'paymentStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final initResult = await _paymentService.initializePayment(
        email: user.email!,
        amountInCents: amountInCents,
        bookingId: bookingId,
        serviceName: _selectedService!['name'] as String,
      );

      await bookingRef.update({
        'paymentReference': initResult.reference,
        'paymentStatus': 'initialized',
      });

      if (!mounted) return;
      final bool? isPaid = await payWithSimulatedStepThenPaystack(
        context,
        amountInCents: amountInCents,
        authorizationUrl: initResult.authorizationUrl,
        reference: initResult.reference,
      );

      if (isPaid != true) {
        throw Exception('Payment was cancelled or failed.');
      }

      final PaymentVerification verification = await _paymentService.verifyPayment(
        reference: initResult.reference,
      );

      if (!verification.success || verification.status != 'success') {
        await bookingRef.update({'status': 'failed', 'paymentStatus': verification.status});
        throw Exception('Payment verification failed.');
      }

      await bookingRef.update({
        'status': 'confirmed',
        'paymentStatus': 'paid',
        'paymentReference': verification.reference,
        'paidAt': FieldValue.serverTimestamp(),
      });

      await CreditHelper.spendCredit(amount: creditUsed, refId: bookingRef.id);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OrdersScreen()),
      );
    } catch (e) {
      if (bookingId != null) {
        await _firestore.collection('appointments').doc(bookingId).update({'status': 'failed'});
      }
      _showMessage(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitReschedule() async {
    if (_selectedDate == null) {
      _showMessage('Please select a new date.');
      return;
    }
    if (_selectedTimeSlot == null) {
      _showMessage('Please select a new time slot.');
      return;
    }
    if (!_isDateAvailable(_selectedDate!)) {
      _showMessage('Sorry, that date is no longer available. Please pick another.');
      setState(() {
        _selectedDate = null;
        _selectedTimeSlot = null;
      });
      return;
    }

    final User? user = _auth.currentUser;
    if (user == null || user.email == null || user.email!.isEmpty) {
      _showMessage('Please log in with a valid email account first.');
      return;
    }

    final a = widget.rescheduleAppointment!;
    final String appointmentId = a['id'] as String;

    setState(() => _isLoading = true);

    try {
      final initResult = await _paymentService.initializePayment(
        email: user.email!,
        amountInCents: _amountInCents(_rescheduleFee),
        bookingId: appointmentId,
        serviceName: 'Reschedule fee - ${a['serviceName'] ?? 'Appointment'}',
      );

      if (!mounted) return;
      final bool? isPaid = await payWithSimulatedStepThenPaystack(
        context,
        amountInCents: _amountInCents(_rescheduleFee),
        authorizationUrl: initResult.authorizationUrl,
        reference: initResult.reference,
      );

      if (isPaid != true) {
        throw Exception('Payment was cancelled. Your appointment was not changed.');
      }

      final PaymentVerification verification = await _paymentService.verifyPayment(
        reference: initResult.reference,
      );

      if (!verification.success || verification.status != 'success') {
        throw Exception('Payment could not be verified. Your appointment was not changed.');
      }

      // Move the SAME appointment to the new slot. The original payment,
      // status and paymentReference are left untouched.
      try {
        await _firestore.collection('appointments').doc(appointmentId).update({
          'previousDate': a['date'],
          'previousTimeSlot': a['timeSlot'],
          'date': _getDateString(_selectedDate!),
          'timeSlot': _selectedTimeSlot,
          'rescheduled': true,
          'rescheduleCount': FieldValue.increment(1),
          'rescheduleFee': _rescheduleFee,
          'reschedulePaymentReference': verification.reference,
          'rescheduledAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        throw Exception(
            'Your R100 payment went through, but we could not update the appointment. '
                'Please contact us and quote reference ${verification.reference}.');
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              'Rescheduled to ${_getDateString(_selectedDate!)} at $_selectedTimeSlot.'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showMessage(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ------------------------------------------------------------
  // Booking policy shown BEFORE the pay button. The client must tick the box.
  // ------------------------------------------------------------
  Widget _policyPoint(IconData icon, String title, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: primaryPurple),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                children: [
                  TextSpan(text: '$title ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingPolicyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightPurple,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.gavel_outlined, color: primaryPurple, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Please read before you book',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _policyPoint(
            Icons.event_repeat,
            'Rescheduling:',
            'an additional fee of R${_rescheduleFee.toStringAsFixed(2)} is payable each time you '
                'reschedule. This fee is non-refundable.',
          ),
          _policyPoint(
            Icons.cancel_outlined,
            'Cancelling:',
            'if you cancel your booking, you forfeit 50% of the total amount you paid. '
                'The other 50% is refunded to your original payment method.',
          ),
          _policyPoint(
            Icons.shield_outlined,
            'If the salon cancels:',
            'you receive a full refund.',
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: _acceptedPolicy,
                  activeColor: primaryPurple,
                  onChanged: (v) => setState(() => _acceptedPolicy = v ?? false),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'I have read and agree to the booking policy.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
                foregroundColor: primaryPurple,
              ),
              child: const Text('Read the full Terms of Service'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rescheduleSummary() {
    final a = widget.rescheduleAppointment!;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightPurple,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${a['serviceName'] ?? 'Appointment'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Current booking: ${a['date']} at ${a['timeSlot']}'),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline, color: primaryPurple, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'A rescheduling fee of R100.00 applies. This fee is payable now and is '
                      'non-refundable. Your original payment remains on this appointment.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredServices = _allServices
        .where((service) => service['category'] == _selectedCategory)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FA),
      appBar: AppBar(
        title: Text(_isReschedule ? 'Reschedule Appointment' : 'Book an Appointment',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryPurple))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isReschedule)
              _rescheduleSummary()
            else ...[
              const Text('1. Select Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 45,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _allCategories.length,
                  itemBuilder: (context, index) {
                    final category = _allCategories[index];
                    final isSelected = category == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        selectedColor: primaryPurple,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = category;
                            _selectedService = null;
                            _selectedTimeSlot = null;
                            _availableTimeSlots.clear();
                          });
                        },
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 25),

              const Text('2. Select Service', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (!_catalogLoaded)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(color: primaryPurple)),
                ),
              ...filteredServices.map((service) {
                final isSelected = _selectedService?['id'] == service['id'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? lightPurple : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? primaryPurple : Colors.transparent, width: 2),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            onTap: () {
                              setState(() {
                                _selectedService = service;
                                _selectedTimeSlot = null;
                              });
                              if (_selectedDate != null) {
                                _generateAvailableTimeSlots();
                              }
                            },
                            leading: _serviceThumb(service),
                            title: Text(service['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${service['description']}\nDuration: ${service['duration']}'),
                            isThreeLine: true,
                            contentPadding: const EdgeInsets.only(left: 16, right: 52),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 104, right: 16, bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      ServiceRatingChip(
                                        serviceId: service['id'] as String,
                                        serviceName: service['name'] as String,
                                        compact: true,
                                      ),
                                      if (service['deleteAt'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Leaving soon',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.orange.shade800,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _priceBox(service),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => _toggleFavourite(service),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.10),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              _favourites.contains(service['id'].toString())
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: _favourites.contains(service['id'].toString())
                                  ? Colors.red
                                  : Colors.grey,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 20),

            ],
            Text(_isReschedule ? '1. Select New Date' : '3. Select Date',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: (_selectedDate != null && _isDateAvailable(_selectedDate!))
                      ? _selectedDate!
                      : _firstAvailableDate(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                  selectableDayPredicate: _isDateAvailable,
                  helpText: 'Select an available date',
                );
                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                    _selectedTimeSlot = null;
                  });
                  if (_selectedService != null) {
                    _generateAvailableTimeSlots();
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: primaryPurple),
                    const SizedBox(width: 15),
                    Text(
                      _selectedDate == null ? 'Tap to choose appointment date' : _getDateString(_selectedDate!),
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedDate == null ? Colors.grey : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            Text(_isReschedule ? '2. Select New Time Slot' : '4. Select Time Slot',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _selectedDate == null
                  ? 'Select a date first.'
                  : (_selectedDate!.weekday == DateTime.saturday || _selectedDate!.weekday == DateTime.sunday)
                  ? 'Weekend slots (08:00 - 00:00)'
                  : 'Weekday slots (19:00 & 21:00)',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (_selectedService == null || _selectedDate == null)
              const Text('Please select a service and date to view time slots.', style: TextStyle(color: Colors.grey))
            else if (_availableTimeSlots.isEmpty)
              const Text('No available time slots for this date/duration.', style: TextStyle(color: Colors.red))
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _availableTimeSlots.map((slot) {
                  final isSelected = _selectedTimeSlot == slot;
                  return ChoiceChip(
                    label: Text(slot),
                    selected: isSelected,
                    selectedColor: primaryPurple,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (selected) {
                      setState(() => _selectedTimeSlot = slot);
                    },
                  );
                }).toList(),
              ),

            const SizedBox(height: 25),

            if (!_isReschedule) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '5. Reference Photo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Optional',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Upload an inspo photo of the hair or nail set you want.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),

              _referenceImage != null
                  ? Stack(
                children: [
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                        image: FileImage(_referenceImage!),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.2),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _referenceImage = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: InkWell(
                      onTap: _pickReferenceImage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, size: 14, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Change',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
                  : GestureDetector(
                onTap: _pickReferenceImage,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryPurple.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: lightPurple,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_a_photo_outlined,
                          color: primaryPurple,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap to attach style reference photo',
                        style: TextStyle(
                          color: primaryPurple,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (!_isReschedule) ...[
              _bookingPolicyCard(),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : (_isReschedule ? _submitReschedule : _submitBooking),
                icon: const Icon(Icons.payment),
                label: Text(
                  _isReschedule
                      ? 'PAY R${_rescheduleFee.toStringAsFixed(2)} & RESCHEDULE'
                      : _selectedService == null
                      ? 'SELECT A SERVICE'
                      : 'PAY R${(_selectedService!['price'] as num).toStringAsFixed(2)} & BOOK',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------
// Full-screen picture viewer (used by the Bookings page and the Home page).
// Pinch to zoom, drag to move around, tap the X or swipe back to close.
// `path` can be a web link (http...) or a bundled asset path.
// ----------------------------------------------------------------
Future<void> showFullImage(BuildContext context, String path, {String? title}) {
  final ImageProvider provider =
  path.startsWith('http') ? NetworkImage(path) : AssetImage(path);
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _FullImagePage(provider: provider, title: title),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _FullImagePage extends StatelessWidget {
  final ImageProvider provider;
  final String? title;

  const _FullImagePage({required this.provider, this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: title == null
            ? null
            : Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Image(
              image: provider,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}