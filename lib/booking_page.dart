import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final PaymentService _paymentService = PaymentService();

  static const Color primaryPurple = Color(0xFF6B3A82);
  static const Color lightPurple = Color(0xFFF3EAF6);

  String _selectedCategory = 'Press-ons';
  Map<String, dynamic>? _selectedService;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  bool _isLoading = false;
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

  @override
  void initState() {
    super.initState();
    if (widget.preselectedService != null) {
      _selectedService = widget.preselectedService;
      _selectedCategory = widget.preselectedService!['category'] ?? 'Press-ons';
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

      if (mounted) {
        setState(() {
          _availableTimeSlots = validSlots;
        });
      }
    } catch (e) {
      _showMessage('Failed to load time slots: $e');
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
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
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
    if (user == null || user.email == null || user.email!.isEmpty) {
      _showMessage('Please log in with a valid email account before booking.');
      return;
    }

    setState(() => _isLoading = true);

    String? bookingId;

    try {
      final double price = (_selectedService!['price'] as num).toDouble();
      final int amountInCents = _amountInCents(price);

      final DocumentReference bookingRef = _firestore.collection('appointments').doc();
      bookingId = bookingRef.id;

      final String? imageUrl = await _uploadReferenceImage(bookingId);
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
        'durationMins': _selectedService!['durationMins'],
        'duration': _selectedService!['duration'],
        'date': formattedDate,
        'timeSlot': _selectedTimeSlot,
        'referencePhoto': imageUrl,
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
      final bool? isPaid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => PaystackCheckoutScreen(
            authorizationUrl: initResult.authorizationUrl,
            reference: initResult.reference,
          ),
        ),
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

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OrdersScreen()),
      );
    } catch (e) {
      if (bookingId != null) {
        await _firestore.collection('appointments').doc(bookingId).update({'status': 'failed'});
      }
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredServices = _salonServices
        .where((service) => service['category'] == _selectedCategory)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FA),
      appBar: AppBar(
        title: const Text('Book an Appointment', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
            const Text('1. Select Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            ...filteredServices.map((service) {
              final isSelected = _selectedService?['id'] == service['id'];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isSelected ? lightPurple : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? primaryPurple : Colors.transparent, width: 2),
                ),
                child: ListTile(
                  onTap: () {
                    setState(() {
                      _selectedService = service;
                      _selectedTimeSlot = null;
                    });
                    if (_selectedDate != null) {
                      _generateAvailableTimeSlots();
                    }
                  },
                  leading: CircleAvatar(
                    backgroundColor: lightPurple,
                    child: Icon(service['icon'] as IconData, color: primaryPurple),
                  ),
                  title: Text(service['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${service['description']}\nDuration: ${service['duration']}'),
                  isThreeLine: true,
                  trailing: Text(
                    'R${(service['price'] as num).toStringAsFixed(2)}',
                    style: const TextStyle(color: primaryPurple, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            const Text('3. Select Date', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

            const Text('4. Select Time Slot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 30),
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