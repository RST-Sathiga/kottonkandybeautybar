import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'payment_service.dart';
import 'paystack_checkout_screen.dart';
import 'orders.dart';

class BookingPage extends StatefulWidget {
  final Map<String, dynamic>? preselectedService;

  const BookingPage({
    super.key,
    this.preselectedService,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // PAYMENT SERVICE
  // ============================================================

  final PaymentService _paymentService = PaymentService();

  // ============================================================
  // COLOURS
  // ============================================================

  static const Color primaryPurple = Color(0xFF6B3A82);
  static const Color lightPurple = Color(0xFFF3EAF6);

  // ============================================================
  // STATE VARIABLES
  // ============================================================

  String _selectedCategory = 'Press-ons';
  Map<String, dynamic>? _selectedService;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  bool _isLoading = false;

  // ============================================================
  // CATEGORIES
  // ============================================================

  final List<String> _categories = [
    'Press-ons',
    'Lashes',
    'Hair',
    'Makeup',
  ];

  // ============================================================
  // SALON SERVICES
  // ============================================================

  final List<Map<String, dynamic>> _salonServices = [
    // PRESS-ONS
    {
      'id': 'press_on_plain',
      'name': 'Press-on Plain',
      'category': 'Press-ons',
      'description': 'Clean, simple, solid-color press-on set application.',
      'price': 250.00,
      'duration': '45 mins',
      'icon': Icons.back_hand,
    },
    {
      'id': 'press_on_glam',
      'name': 'Press-on Glam',
      'category': 'Press-ons',
      'description': 'Glamorous press-on set with intricate design elements.',
      'price': 350.00,
      'duration': '1 hour',
      'icon': Icons.brush,
    },
    {
      'id': 'press_on_installation',
      'name': 'Press-on Installation',
      'category': 'Press-ons',
      'description': 'Professional sizing, prep, and long-lasting application.',
      'price': 100.00,
      'duration': '30 mins',
      'icon': Icons.pan_tool_alt,
    },

    // LASHES
    {
      'id': 'cluster_lashes',
      'name': 'Cluster Lashes',
      'category': 'Lashes',
      'description': 'Full, beautiful cluster lash application.',
      'price': 200.00,
      'duration': '45 mins',
      'icon': Icons.visibility,
    },
    {
      'id': 'classic_lashes',
      'name': 'Classic Lashes',
      'category': 'Lashes',
      'description': 'Natural-looking individual lash extensions.',
      'price': 250.00,
      'duration': '1 hour 30 mins',
      'icon': Icons.visibility_outlined,
    },
    {
      'id': 'volume_lashes',
      'name': 'Volume Lashes',
      'category': 'Lashes',
      'description': 'Full and fluffy volume lash extensions.',
      'price': 300.00,
      'duration': '2 hours',
      'icon': Icons.remove_red_eye,
    },
    {
      'id': 'hybrid_lashes',
      'name': 'Hybrid Lashes',
      'category': 'Lashes',
      'description': 'Combination of classic and volume techniques.',
      'price': 350.00,
      'duration': '1 hour 45 mins',
      'icon': Icons.remove_red_eye_outlined,
    },
    {
      'id': 'eyelash_removal',
      'name': 'Eyelash Removal',
      'category': 'Lashes',
      'description': 'Safe and gentle removal of existing lash extensions.',
      'price': 50.00,
      'duration': '30 mins',
      'icon': Icons.disabled_visible,
    },

    // HAIR
    {
      'id': 'afro_crotchet',
      'name': 'Afro Crotchet',
      'category': 'Hair',
      'description': 'Neat and lightweight Afro crotchet installation.',
      'price': 350.00,
      'duration': '2 hours',
      'icon': Icons.face_retouching_natural,
    },
    {
      'id': 'wig_lines',
      'name': 'Wig Lines',
      'category': 'Hair',
      'description': 'Flat, secure cornrow base for comfortable wig wear.',
      'price': 150.00,
      'duration': '45 mins',
      'icon': Icons.spa,
    },
    {
      'id': 'wig_installation',
      'name': 'Wig Installation',
      'category': 'Hair',
      'description': 'Professional wig fitting, melting, and styling.',
      'price': 400.00,
      'duration': '1 hour 30 mins',
      'icon': Icons.face,
    },
    {
      'id': 'keratin_wig_care',
      'name': 'Keratin Wig Care',
      'category': 'Hair',
      'description': 'Restorative keratin wash, deep condition, and revival.',
      'price': 250.00,
      'duration': '1 hour',
      'icon': Icons.clean_hands,
    },

    // MAKEUP
    {
      'id': 'eye_brow_care',
      'name': 'Eye Brow Care',
      'category': 'Makeup',
      'description': 'Precision eyebrow shaping, trimming, and grooming.',
      'price': 200.00,
      'duration': '30 mins',
      'icon': Icons.edit,
    },
    {
      'id': 'soft_glam',
      'name': 'Soft Glam',
      'category': 'Makeup',
      'description': 'Seamless, radiant neutral glam makeup.',
      'price': 400.00,
      'duration': '1 hour',
      'icon': Icons.auto_awesome,
    },
    {
      'id': 'full_glam',
      'name': 'Full Glam',
      'category': 'Makeup',
      'description': 'Full coverage, dramatic eye look, cut crease, and lashes.',
      'price': 500.00,
      'duration': '1 hour 30 mins',
      'icon': Icons.auto_fix_high,
    },
  ];

  // ============================================================
  // AVAILABLE TIME SLOTS
  // ============================================================

  final List<String> _timeSlots = [
    '09:00 AM',
    '10:30 AM',
    '12:00 PM',
    '01:30 PM',
    '03:00 PM',
    '04:30 PM',
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    if (widget.preselectedService != null) {
      _selectedService = widget.preselectedService;
      _selectedCategory =
          widget.preselectedService!['category'] ?? 'Press-ons';
    }
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
          backgroundColor:
          isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ============================================================
  // DATE STRING
  // ============================================================

  String _getDateString(DateTime date) {
    return date.toIso8601String().split('T')[0];
  }

  // ============================================================
  // CONVERT RAND TO CENTS
  // ============================================================

  int _amountInCents(double amount) {
    return (amount * 100).round();
  }

  // ============================================================
  // CHECK IF TIME SLOT IS AVAILABLE
  // ============================================================

  Future<bool> _isSlotAvailable() async {
    if (_selectedDate == null || _selectedTimeSlot == null) {
      return false;
    }

    final String date = _getDateString(_selectedDate!);

    final QuerySnapshot snapshot = await _firestore
        .collection('appointments')
        .where('date', isEqualTo: date)
        .where('timeSlot', isEqualTo: _selectedTimeSlot)
        .where('status', whereIn: ['Pending Payment', 'Confirmed', 'Paid', 'pending', 'confirmed', 'paid'])
        .limit(1)
        .get();

    return snapshot.docs.isEmpty;
  }

  // ============================================================
  // START PAYMENT + BOOKING
  // ============================================================

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

    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('You must be logged in to book an appointment.');
      return;
    }

    if (user.email == null || user.email!.isEmpty) {
      _showMessage('Your account needs an email address before payment.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String? bookingId;

    try {
      // 1. CHECK SLOT AVAILABILITY
      final bool available = await _isSlotAvailable();
      if (!available) {
        throw Exception(
          'This time slot is already booked. Please choose another time.',
        );
      }

      // 2. GET PRICE IN CENTS
      final double price = (_selectedService!['price'] as num).toDouble();
      final int amountInCents = _amountInCents(price);

      // 3. CREATE PENDING BOOKING
      final DocumentReference bookingRef =
      _firestore.collection('appointments').doc();
      bookingId = bookingRef.id;

      final String formattedDate = _getDateString(_selectedDate!);

      await bookingRef.set({
        'id': bookingId,
        'bookingId': bookingId,
        'userId': user.uid,
        'userEmail': user.email ?? 'Unknown',
        'serviceId': _selectedService!['id'],
        'serviceName': _selectedService!['name'],
        'category': _selectedService!['category'],
        'price': price,
        'amountInCents': amountInCents,
        'duration': _selectedService!['duration'],
        'date': formattedDate,
        'timeSlot': _selectedTimeSlot,
        'time': _selectedTimeSlot, // Dual key for backwards compatibility
        'status': 'pending', // Lowercase to match OrdersScreen query
        'paymentStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. INITIALIZE PAYSTACK TRANSACTION VIA BACKEND
      final initResult = await _paymentService.initializePayment(
        email: user.email!,
        amountInCents: amountInCents,
        bookingId: bookingId,
        serviceName: _selectedService!['name'] as String,
      );

      await bookingRef.update({
        'paymentReference': initResult.reference,
        'paymentStatus': 'initialized',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 5. OPEN PAYSTACK CHECKOUT WEBVIEW
      if (!mounted) return;
      final bool? isPaid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => PaystackCheckoutScreen(
            authorizationUrl: initResult.authorizationUrl,
            reference: initResult.reference,
          ),
        ),
      );

      // 6. VERIFY PAYMENT STATUS
      if (isPaid != true) {
        throw Exception('Payment was cancelled or failed.');
      }

      final PaymentVerification verification =
      await _paymentService.verifyPayment(
        reference: initResult.reference,
      );

      if (!verification.success || verification.status != 'success') {
        await bookingRef.update({
          'status': 'failed',
          'paymentStatus': verification.status,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        throw Exception('Payment verification was not successful.');
      }

      // 7. CONFIRM BOOKING
      await bookingRef.update({
        'status': 'confirmed',
        'paymentStatus': 'paid',
        'paymentReference': verification.reference,
        'paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 8. CREATE CLIENT NOTIFICATION
      await _firestore.collection('notifications').add({
        'userId': user.uid,
        'title': 'Booking Confirmed',
        'message': 'Your ${_selectedService!['name']} appointment '
            'on $formattedDate at $_selectedTimeSlot has been confirmed.',
        'type': 'booking',
        'bookingId': bookingId,
        'paymentReference': verification.reference,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 9. SHOW SUCCESS RECEIPT & REDIRECT
      if (!mounted) return;
      _showBookingSuccess(paymentReference: verification.reference);
    } catch (e) {
      debugPrint('Booking/payment error: $e');

      if (bookingId != null) {
        try {
          await _firestore
              .collection('appointments')
              .doc(bookingId)
              .update({
            'status': 'failed',
            'paymentStatus': 'failed',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // SUCCESS RECEIPT DIALOG & REDIRECT
  // ============================================================

  void _showBookingSuccess({
    required String paymentReference,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Expanded(child: Text('Payment Successful')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your appointment has been confirmed!',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Service: ${_selectedService!['name']}'),
              Text('Date: ${_getDateString(_selectedDate!)}'),
              Text('Time: $_selectedTimeSlot'),
              Text(
                  'Amount Paid: R${(_selectedService!['price'] as num).toStringAsFixed(2)}'),
              const Divider(height: 20),
              Text('Receipt Ref: $paymentReference',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context); // Close receipt
                setState(() {
                  _selectedService = null;
                  _selectedDate = null;
                  _selectedTimeSlot = null;
                });
                // Redirect directly to My Bookings screen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const OrdersScreen()),
                );
              },
              child: const Text('VIEW MY BOOKINGS'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final filteredServices = _salonServices
        .where((service) => service['category'] == _selectedCategory)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FA),
      appBar: AppBar(
        title: const Text(
          'Book an Appointment',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: primaryPurple),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CATEGORY
            const Text(
              'Select Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      selectedColor: primaryPurple,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = category;
                          _selectedService = null;
                        });
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 25),

            // SERVICES
            const Text(
              'Select Service',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...filteredServices.map((service) {
              final isSelected =
                  _selectedService?['id'] == service['id'];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isSelected ? lightPurple : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? primaryPurple
                        : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  onTap: () {
                    setState(() {
                      _selectedService = service;
                    });
                  },
                  leading: CircleAvatar(
                    backgroundColor: lightPurple,
                    child: Icon(
                      service['icon'] as IconData,
                      color: primaryPurple,
                    ),
                  ),
                  title: Text(
                    service['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${service['description']}\nDuration: ${service['duration']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    'R${(service['price'] as num).toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: primaryPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            // DATE
            const Text(
              'Select Date',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );

                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                    _selectedTimeSlot = null;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: primaryPurple),
                    const SizedBox(width: 15),
                    Text(
                      _selectedDate == null
                          ? 'Tap to choose appointment date'
                          : _getDateString(_selectedDate!),
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedDate == null
                            ? Colors.grey
                            : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            // TIME SLOTS
            const Text(
              'Select Time Slot',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _timeSlots.map((slot) {
                final isSelected = _selectedTimeSlot == slot;

                return ChoiceChip(
                  label: Text(slot),
                  selected: isSelected,
                  selectedColor: primaryPurple,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color:
                    isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedTimeSlot = slot;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 35),

            // SUMMARY
            if (_selectedService != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: lightPurple,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Booking Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_selectedService!['name']),
                    const SizedBox(height: 5),
                    Text(
                      'Date: ${_selectedDate == null ? 'Not selected' : _getDateString(_selectedDate!)}',
                    ),
                    Text(
                      'Time: ${_selectedTimeSlot ?? 'Not selected'}',
                    ),
                    const Divider(),
                    Text(
                      'Total: R${(_selectedService!['price'] as num).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryPurple,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitBooking,
                icon: const Icon(Icons.payment),
                label: Text(
                  _selectedService == null
                      ? 'SELECT A SERVICE'
                      : 'PAY R${(_selectedService!['price'] as num).toStringAsFixed(2)} & BOOK',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            const Center(
              child: Text(
                'Secure payment powered by Paystack',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}