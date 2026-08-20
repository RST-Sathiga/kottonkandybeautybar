import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paystack_flutter_sdk/paystack_flutter_sdk.dart';

import 'payment_service.dart';

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
  // ============================================================
  // FIREBASE & AUTH
  // ============================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // PAYSTACK
  // ============================================================

  final PaymentService _paymentService = PaymentService();
  final Paystack _paystack = Paystack();

  // YOUR PAYSTACK TEST PUBLIC KEY
  static const String paystackPublicKey =
      'pk_test_d6fa71f69720adde60ca2596bf8c765d29949801';

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
    {
      'id': 'press_on_install',
      'name': 'Custom Press-On Installation',
      'category': 'Press-ons',
      'description':
      'Professional sizing, prep, and application of premium press-on nails.',
      'price': 180.00,
      'duration': '45 mins',
      'icon': Icons.back_hand,
    },
    {
      'id': 'nail_art_addon',
      'name': 'Deluxe Nail Art & Gems',
      'category': 'Press-ons',
      'description':
      'Intricate hand-painted art and crystal placement.',
      'price': 120.00,
      'duration': '30 mins',
      'icon': Icons.brush,
    },
    {
      'id': 'classic_lashes',
      'name': 'Classic Lash Extensions',
      'category': 'Lashes',
      'description':
      'Natural-looking individual lash extensions for everyday elegance.',
      'price': 350.00,
      'duration': '1 hour 30 mins',
      'icon': Icons.visibility,
    },
    {
      'id': 'volume_lashes',
      'name': 'Russian Volume Lashes',
      'category': 'Lashes',
      'description':
      'Full, fluffy, and glamorous multi-lash handmade fans.',
      'price': 480.00,
      'duration': '2 hours',
      'icon': Icons.visibility_outlined,
    },
    {
      'id': 'silk_press',
      'name': 'Signature Silk Press',
      'category': 'Hair',
      'description':
      'Smooth, silky blowout and straightening for natural hair.',
      'price': 400.00,
      'duration': '1 hour 30 mins',
      'icon': Icons.face,
    },
    {
      'id': 'cornrows_styling',
      'name': 'Protective Cornrows',
      'category': 'Hair',
      'description':
      'Clean, neat protective styling with extensions optional.',
      'price': 300.00,
      'duration': '1 hour',
      'icon': Icons.spa,
    },
    {
      'id': 'full_face_makeup',
      'name': 'Glam Full Face Makeup',
      'category': 'Makeup',
      'description':
      'Flawless foundation, eyeshadow art, contour, and lashes included.',
      'price': 450.00,
      'duration': '1 hour',
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

    _initializePaystack();
  }

  // ============================================================
  // INITIALIZE PAYSTACK
  // ============================================================

  Future<void> _initializePaystack() async {
    try {
      await _paystack.initialize(
        paystackPublicKey,
        true,
      );

      debugPrint('Paystack initialized successfully');
    } catch (e) {
      debugPrint('Paystack initialization error: $e');
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
  // CONVERT RAND TO KOBO
  // ============================================================

  int _amountInKobo(double amount) {
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
        .where(
      'date',
      isEqualTo: date,
    )
        .where(
      'timeSlot',
      isEqualTo: _selectedTimeSlot,
    )
        .where(
      'status',
      whereIn: [
        'Pending Payment',
        'Confirmed',
        'Paid',
      ],
    )
        .limit(1)
        .get();

    return snapshot.docs.isEmpty;
  }

  // ============================================================
  // START PAYMENT + BOOKING
  // ============================================================

  Future<void> _submitBooking() async {
    // ----------------------------------------------------------
    // CHECK SERVICE
    // ----------------------------------------------------------

    if (_selectedService == null) {
      _showMessage('Please select a service.');
      return;
    }

    // ----------------------------------------------------------
    // CHECK DATE
    // ----------------------------------------------------------

    if (_selectedDate == null) {
      _showMessage('Please select an appointment date.');
      return;
    }

    // ----------------------------------------------------------
    // CHECK TIME
    // ----------------------------------------------------------

    if (_selectedTimeSlot == null) {
      _showMessage('Please select a time slot.');
      return;
    }

    // ----------------------------------------------------------
    // CHECK LOGIN
    // ----------------------------------------------------------

    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'You must be logged in to book an appointment.',
      );
      return;
    }

    // ----------------------------------------------------------
    // CHECK EMAIL
    // ----------------------------------------------------------

    if (user.email == null || user.email!.isEmpty) {
      _showMessage(
        'Your account needs an email address before payment.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String? bookingId;

    try {
      // ========================================================
      // 1. CHECK SLOT BEFORE PAYMENT
      // ========================================================

      final bool available = await _isSlotAvailable();

      if (!available) {
        throw Exception(
          'This time slot is already booked. Please choose another time.',
        );
      }

      // ========================================================
      // 2. GET PRICE
      // ========================================================

      final double price =
      (_selectedService!['price'] as num).toDouble();

      final int amountInKobo = _amountInKobo(price);

      // ========================================================
      // 3. CREATE PENDING BOOKING
      // ========================================================

      final DocumentReference bookingRef =
      _firestore.collection('appointments').doc();

      bookingId = bookingRef.id;

      await bookingRef.set({
        'id': bookingId,
        'userId': user.uid,
        'userEmail': user.email ?? 'Unknown',

        'serviceId': _selectedService!['id'],
        'serviceName': _selectedService!['name'],
        'category': _selectedService!['category'],
        'price': price,
        'amountInKobo': amountInKobo,
        'duration': _selectedService!['duration'],

        'date': _getDateString(_selectedDate!),
        'timeSlot': _selectedTimeSlot,

        // IMPORTANT:
        // The booking is NOT confirmed yet.
        'status': 'Pending Payment',

        'paymentStatus': 'pending',

        'createdAt': FieldValue.serverTimestamp(),
      });

      // ========================================================
      // 4. INITIALIZE PAYSTACK PAYMENT
      // ========================================================

      final PaymentInitialization payment =
      await _paymentService.initializePayment(
        email: user.email!,
        amountInKobo: amountInKobo,
        bookingId: bookingId,
        serviceName: _selectedService!['name'],
      );

      // ========================================================
      // 5. SAVE PAYMENT REFERENCE
      // ========================================================

      await bookingRef.update({
        'paymentReference': payment.reference,
        'paymentStatus': 'initialized',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ========================================================
      // 6. OPEN PAYSTACK
      // ========================================================

      await _paystack.launch(
        payment.accessCode,
      );

      // ========================================================
      // 7. VERIFY PAYMENT ON SERVER
      // ========================================================

      final PaymentVerification verification =
      await _paymentService.verifyPayment(
        reference: payment.reference,
      );

      // ========================================================
      // 8. PAYMENT FAILED
      // ========================================================

      if (!verification.success ||
          verification.status != 'success') {
        await bookingRef.update({
          'status': 'Payment Failed',
          'paymentStatus': verification.status,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        throw Exception(
          'Payment was not completed.',
        );
      }

      // ========================================================
      // 9. PAYMENT SUCCESSFUL
      // ========================================================

      await bookingRef.update({
        'status': 'Confirmed',
        'paymentStatus': 'paid',
        'paymentReference': verification.reference,
        'paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ========================================================
      // 10. CREATE CLIENT NOTIFICATION
      // ========================================================

      await _firestore.collection('notifications').add({
        'userId': user.uid,
        'title': 'Booking Confirmed',
        'message':
        'Your ${_selectedService!['name']} appointment '
            'on ${_getDateString(_selectedDate!)} '
            'at $_selectedTimeSlot has been confirmed.',
        'type': 'booking',
        'bookingId': bookingId,
        'paymentReference': verification.reference,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ========================================================
      // 11. SHOW SUCCESS
      // ========================================================

      if (!mounted) return;

      _showBookingSuccess(
        paymentReference: verification.reference,
      );
    } catch (e) {
      debugPrint(
        'Booking/payment error: $e',
      );

      // ========================================================
      // MARK BOOKING AS FAILED
      // ========================================================

      if (bookingId != null) {
        try {
          await _firestore
              .collection('appointments')
              .doc(bookingId)
              .update({
            'status': 'Payment Failed',
            'paymentStatus': 'failed',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }

      _showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
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
  // SUCCESS DIALOG
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
              Icon(
                Icons.check_circle,
                color: Colors.green,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Payment Successful',
                ),
              ),
            ],
          ),
          content: Text(
            'Your appointment has been confirmed.\n\n'
                'Service: ${_selectedService!['name']}\n'
                'Date: ${_getDateString(_selectedDate!)}\n'
                'Time: $_selectedTimeSlot\n'
                'Amount: R${(_selectedService!['price'] as num).toStringAsFixed(2)}\n\n'
                'Payment Reference:\n'
                '$paymentReference',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);

                setState(() {
                  _selectedService = null;
                  _selectedDate = null;
                  _selectedTimeSlot = null;
                });
              },
              child: const Text('DONE'),
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
        .where(
          (service) =>
      service['category'] == _selectedCategory,
    )
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
        iconTheme: const IconThemeData(
          color: Colors.black,
        ),
      ),

      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: primaryPurple,
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [

            // =================================================
            // CATEGORY
            // =================================================

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
                scrollDirection:
                Axis.horizontal,

                itemCount:
                _categories.length,

                itemBuilder:
                    (context, index) {
                  final category =
                  _categories[index];

                  final isSelected =
                      category ==
                          _selectedCategory;

                  return Padding(
                    padding:
                    const EdgeInsets.only(
                      right: 10,
                    ),

                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      selectedColor:
                      primaryPurple,
                      backgroundColor:
                      Colors.white,

                      labelStyle:
                      TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.black87,
                        fontWeight:
                        FontWeight.w600,
                      ),

                      onSelected:
                          (selected) {
                        setState(() {
                          _selectedCategory =
                              category;

                          // Clear old service
                          _selectedService =
                          null;
                        });
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 25),

            // =================================================
            // SERVICES
            // =================================================

            const Text(
              'Select Service',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            ...filteredServices.map(
                  (service) {
                final isSelected =
                    _selectedService?['id'] ==
                        service['id'];

                return Container(
                  margin:
                  const EdgeInsets.only(
                    bottom: 12,
                  ),

                  decoration:
                  BoxDecoration(
                    color: isSelected
                        ? lightPurple
                        : Colors.white,

                    borderRadius:
                    BorderRadius.circular(
                      16,
                    ),

                    border: Border.all(
                      color: isSelected
                          ? primaryPurple
                          : Colors.transparent,
                      width: 2,
                    ),

                    boxShadow: [
                      BoxShadow(
                        color:
                        Colors.black.withValues(
                          alpha: 0.05,
                        ),
                        blurRadius: 8,
                        offset:
                        const Offset(0, 2),
                      ),
                    ],
                  ),

                  child: ListTile(
                    onTap: () {
                      setState(() {
                        _selectedService =
                            service;
                      });
                    },

                    leading:
                    CircleAvatar(
                      backgroundColor:
                      lightPurple,

                      child: Icon(
                        service['icon']
                        as IconData,
                        color:
                        primaryPurple,
                      ),
                    ),

                    title: Text(
                      service['name'],
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    subtitle: Text(
                      '${service['description']}\n'
                          'Duration: ${service['duration']}',

                      maxLines: 2,

                      overflow:
                      TextOverflow.ellipsis,
                    ),

                    isThreeLine: true,

                    trailing: Text(
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
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // =================================================
            // DATE
            // =================================================

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
                final picked =
                await showDatePicker(
                  context: context,

                  initialDate:
                  DateTime.now(),

                  firstDate:
                  DateTime.now(),

                  lastDate:
                  DateTime.now().add(
                    const Duration(
                      days: 60,
                    ),
                  ),
                );

                if (picked != null) {
                  setState(() {
                    _selectedDate =
                        picked;

                    // Reset time when
                    // date changes.
                    _selectedTimeSlot =
                    null;
                  });
                }
              },

              child: Container(
                padding:
                const EdgeInsets.all(
                  16,
                ),

                decoration:
                BoxDecoration(
                  color:
                  Colors.white,

                  borderRadius:
                  BorderRadius.circular(
                    16,
                  ),
                ),

                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color:
                      primaryPurple,
                    ),

                    const SizedBox(
                      width: 15,
                    ),

                    Text(
                      _selectedDate == null
                          ? 'Tap to choose appointment date'
                          : _getDateString(
                        _selectedDate!,
                      ),

                      style: TextStyle(
                        fontSize: 16,

                        color:
                        _selectedDate ==
                            null
                            ? Colors.grey
                            : Colors.black87,

                        fontWeight:
                        FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            // =================================================
            // TIME
            // =================================================

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

              children:
              _timeSlots.map(
                    (slot) {
                  final isSelected =
                      _selectedTimeSlot ==
                          slot;

                  return ChoiceChip(
                    label:
                    Text(slot),

                    selected:
                    isSelected,

                    selectedColor:
                    primaryPurple,

                    backgroundColor:
                    Colors.white,

                    labelStyle:
                    TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.black87,

                      fontWeight:
                      FontWeight.w600,
                    ),

                    onSelected:
                        (selected) {
                      setState(() {
                        _selectedTimeSlot =
                            slot;
                      });
                    },
                  );
                },
              ).toList(),
            ),

            const SizedBox(height: 35),

            // =================================================
            // PAYMENT SUMMARY
            // =================================================

            if (_selectedService != null)
              Container(
                width:
                double.infinity,

                padding:
                const EdgeInsets.all(
                  18,
                ),

                decoration:
                BoxDecoration(
                  color:
                  lightPurple,

                  borderRadius:
                  BorderRadius.circular(
                    16,
                  ),
                ),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Booking Summary',
                      style:
                      TextStyle(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Text(
                      _selectedService![
                      'name'],
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      'Date: ${_selectedDate == null ? 'Not selected' : _getDateString(_selectedDate!)}',
                    ),

                    Text(
                      'Time: ${_selectedTimeSlot ?? 'Not selected'}',
                    ),

                    const Divider(),

                    Text(
                      'Total: R${(_selectedService!['price'] as num).toStringAsFixed(2)}',

                      style:
                      const TextStyle(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.bold,
                        color:
                        primaryPurple,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 25),

            // =================================================
            // PAY BUTTON
            // =================================================

            SizedBox(
              width:
              double.infinity,

              height: 55,

              child:
              ElevatedButton.icon(
                onPressed:
                _isLoading
                    ? null
                    : _submitBooking,

                icon: const Icon(
                  Icons.payment,
                ),

                label: Text(
                  _selectedService == null
                      ? 'SELECT A SERVICE'
                      : 'PAY R${(_selectedService!['price'] as num).toStringAsFixed(2)} & BOOK',
                ),

                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  primaryPurple,

                  foregroundColor:
                  Colors.white,

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

            const SizedBox(
              height: 12,
            ),

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