import 'package:flutter/material.dart';

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
  DateTime selectedDate = DateTime.now();

  String? selectedTime;

  BookingService? selectedService;

  void confirmBooking() {
    if (selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a service.'),
        ),
      );
      return;
    }

    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an appointment time.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Booking Confirmed'),
          content: Text(
            'Service: ${selectedService!.name}\n'
                'Price: R${selectedService!.price.toStringAsFixed(0)}\n'
                'Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}\n'
                'Time: $selectedTime',
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
  }

  String get formattedDate {
    return '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                borderRadius: BorderRadius.circular(16),
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

            const SizedBox(height: 12),

            TimeSelector(
              selectedTime: selectedTime,
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
                  selected: selectedService == service,
                  onTap: () {
                    setState(() {
                      selectedService = service;
                    });
                  },
                );
              },
            ),

            const SizedBox(height: 10),

            if (selectedService != null || selectedTime != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Booking Summary',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      'Date: $formattedDate',
                      style: const TextStyle(
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Time: ${selectedTime ?? 'Not selected'}',
                      style: const TextStyle(
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Service: ${selectedService?.name ?? 'Not selected'}',
                      style: const TextStyle(
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 6),

                    if (selectedService != null)
                      Text(
                        'Total: R${selectedService!.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE91E63),
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
                onPressed: confirmBooking,
                child: const Text(
                  'Confirm Booking',
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}