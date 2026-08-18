import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'booking_service.dart';
import 'date_selector.dart';
import 'service_card.dart';
import 'time_selector.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime selectedDate = DateTime.now();

  String? selectedTime;

  BookingService? selectedService;

  bool isBooking = false;

  String get dateKey {
    final String year = selectedDate.year.toString();

    final String month =
    selectedDate.month.toString().padLeft(2, '0');

    final String day =
    selectedDate.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String get formattedDate {
    return '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';
  }

  String get bookingDocumentId {
    return '${dateKey}_${selectedTime!.replaceAll(':', '-')}';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get bookedTimesStream {
    return _firestore
        .collection('bookings')
        .where('dateKey', isEqualTo: dateKey)
        .snapshots();
  }

  bool isTimeBooked(
      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      String time,
      ) {
    if (!snapshot.hasData) {
      return false;
    }

    return snapshot.data!.docs.any(
          (doc) => doc.data()['time'] == time,
    );
  }

  Future<void> confirmBooking() async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please log in before making a booking.',
          ),
        ),
      );
      return;
    }

    if (selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a service.',
          ),
        ),
      );
      return;
    }

    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select an appointment time.',
          ),
        ),
      );
      return;
    }

    setState(() {
      isBooking = true;
    });

    try {
      final User user = _auth.currentUser!;

      final String bookingId = bookingDocumentId;

      final DocumentReference<Map<String, dynamic>> bookingRef =
      _firestore.collection('bookings').doc(bookingId);

      await _firestore.runTransaction(
            (transaction) async {
          final DocumentSnapshot<Map<String, dynamic>> bookingSnapshot =
          await transaction.get(bookingRef);

          if (bookingSnapshot.exists) {
            throw Exception(
              'This appointment time has already been booked.',
            );
          }

          transaction.set(
            bookingRef,
            {
              'bookingId': bookingId,

              'customerId': user.uid,

              'customerEmail': user.email ?? '',

              'customerName':
              user.displayName ?? 'Customer',

              'service': selectedService!.name,

              'price': selectedService!.price,

              'date': Timestamp.fromDate(
                DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                ),
              ),

              'dateKey': dateKey,

              'time': selectedTime,

              'status': 'pending',

              'createdAt': FieldValue.serverTimestamp(),

              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        isBooking = false;
      });

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              'Booking Confirmed',
            ),
            content: Text(
              'Your appointment has been successfully booked.\n\n'
                  'Service: ${selectedService!.name}\n'
                  'Price: R${selectedService!.price.toStringAsFixed(0)}\n'
                  'Date: $formattedDate\n'
                  'Time: $selectedTime\n\n'
                  'Status: Pending confirmation',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        selectedTime = null;
        selectedService = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isBooking = false;
      });

      String message =
          'Something went wrong. Please try again.';

      if (e.toString().contains(
        'already been booked',
      )) {
        message =
        'Sorry, this time has just been booked by another customer. Please choose another time.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Book Appointment',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: bookedTimesStream,

        builder: (
            context,
            snapshot,
            ) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),

            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                const Text(
                  'Choose a Date',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.shade200,
                    ),
                  ),

                  child: DateSelector(
                    selectedDate: selectedDate,

                    onDateSelected: (date) {
                      setState(() {
                        selectedDate = date;
                        selectedTime = null;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'Choose a Time',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Available times are from 09:00 to 16:00.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 12),

                TimeSelector(
                  selectedTime: selectedTime,

                  bookedTimes: snapshot.hasData
                      ? snapshot.data!.docs
                      .map(
                        (doc) =>
                    doc.data()['time']
                    as String?,
                  )
                      .whereType<String>()
                      .toSet()
                      : {},

                  onTimeSelected: (time) {
                    setState(() {
                      selectedTime = time;
                    });
                  },
                ),

                const SizedBox(height: 28),

                const Text(
                  'Choose a Service',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                ...bookingServices.map(
                      (service) {
                    return ServiceCard(
                      service: service,

                      selected:
                      selectedService == service,

                      onTap: () {
                        setState(() {
                          selectedService =
                              service;
                        });
                      },
                    );
                  },
                ),

                const SizedBox(height: 10),

                if (selectedService != null ||
                    selectedTime != null)
                  Container(
                    width: double.infinity,

                    padding:
                    const EdgeInsets.all(18),

                    decoration: BoxDecoration(
                      color:
                      const Color(0xFFF8F8F8),

                      borderRadius:
                      BorderRadius.circular(16),
                    ),

                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [
                        const Text(
                          'Booking Summary',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 14,
                        ),

                        Text(
                          'Date: $formattedDate',
                          style:
                          const TextStyle(
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(
                          height: 6,
                        ),

                        Text(
                          'Time: ${selectedTime ?? 'Not selected'}',
                          style:
                          const TextStyle(
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(
                          height: 6,
                        ),

                        Text(
                          'Service: ${selectedService?.name ?? 'Not selected'}',
                          style:
                          const TextStyle(
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(
                          height: 6,
                        ),

                        if (selectedService !=
                            null)
                          Text(
                            'Total: R${selectedService!.price.toStringAsFixed(0)}',

                            style:
                            const TextStyle(
                              fontSize: 17,
                              fontWeight:
                              FontWeight.bold,
                              color:
                              Color(0xFFE91E63),
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 55,

                  child: ElevatedButton(
                    onPressed:
                    isBooking
                        ? null
                        : confirmBooking,

                    child: isBooking
                        ? const SizedBox(
                      width: 24,
                      height: 24,

                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        color:
                        Colors.white,
                      ),
                    )
                        : const Text(
                      'Confirm Booking',
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}