
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingPage extends StatefulWidget {
  final Map<String, dynamic>? preselectedService;

  const BookingPage({super.key, this.preselectedService});

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

  final List<String> _categories = [
    'Press-ons',
    'Lashes',
    'Hair',
    'Makeup'
  ];

  // ============================================================
  // SAMPLE SALON SERVICES
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
      'description': 'Intricate hand-painted art and crystal placement.',
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
      'description': 'Full, fluffy, and glamorous multi-lash handmade fans.',
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ============================================================
  // SUBMIT BOOKING
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

    setState(() {
      _isLoading = true;
    });

    try {
      await _firestore.runTransaction((transaction) async {
        final querySnapshot = await _firestore
            .collection('appointments')
            .where(
          'date',
          isEqualTo:
          _selectedDate!.toIso8601String().split('T')[0],
        )
            .where('timeSlot', isEqualTo: _selectedTimeSlot)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          throw Exception(
            'This time slot is already booked. Please choose another time.',
          );
        }

        final docRef = _firestore.collection('appointments').doc();

        transaction.set(docRef, {
          'id': docRef.id,
          'userId': user.uid,
          'userEmail': user.email ?? 'Unknown',
          'serviceName': _selectedService!['name'],
          'category': _selectedService!['category'],
          'price': _selectedService!['price'],
          'duration': _selectedService!['duration'],
          'date': _selectedDate!.toIso8601String().split('T')[0],
          'timeSlot': _selectedTimeSlot,
          'status': 'Confirmed',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Booking Confirmed!'),
          content: Text(
            'Your appointment for ${_selectedService!['name']} on '
                '${_selectedDate!.toIso8601String().split('T')[0]} at '
                '$_selectedTimeSlot has been successfully booked.',
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
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showMessage(
        e.toString().replaceAll('Exception: ', ''),
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
        child: CircularProgressIndicator(
          color: primaryPurple,
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =====================================================
            // CATEGORY
            // =====================================================
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
                  final isSelected =
                      category == _selectedCategory;

                  return Padding(
                    padding:
                    const EdgeInsets.only(right: 10),
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
                        });
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 25),

            // =====================================================
            // SERVICES
            // =====================================================
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
                margin:
                const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color:
                  isSelected ? lightPurple : Colors.white,
                  borderRadius:
                  BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? primaryPurple
                        : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                      Colors.black.withValues(alpha: 0.05),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
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

            // =====================================================
            // DATE PICKER
            // =====================================================
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
                  lastDate: DateTime.now().add(
                    const Duration(days: 60),
                  ),
                );

                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: primaryPurple,
                    ),
                    const SizedBox(width: 15),
                    Text(
                      _selectedDate == null
                          ? 'Tap to choose appointment date'
                          : _selectedDate!
                          .toIso8601String()
                          .split('T')[0],
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

            // =====================================================
            // TIME SLOTS
            // =====================================================
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
                final isSelected =
                    _selectedTimeSlot == slot;

                return ChoiceChip(
                  label: Text(slot),
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
                      _selectedTimeSlot = slot;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 35),

            // =====================================================
            // CONFIRM BUTTON
            // =====================================================
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'CONFIRM APPOINTMENT',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}