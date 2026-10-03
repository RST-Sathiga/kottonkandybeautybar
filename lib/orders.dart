import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  static const Color primaryPurple = Color(0xFF6B3A82);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          // Back button added to return to previous/profile screen
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            "My Activity",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            labelColor: primaryPurple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryPurple,
            tabs: [
              Tab(text: "My Orders"),
              Tab(text: "My Bookings"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MarketplaceOrdersView(),
            _AppointmentsView(),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceOrdersView extends StatelessWidget {
  const _MarketplaceOrdersView();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            labelColor: OrdersScreen.primaryPurple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: OrdersScreen.primaryPurple,
            isScrollable: true,
            tabs: [
              Tab(text: "All"),
              Tab(text: "Pending"),
              Tab(text: "Shipped"),
              Tab(text: "Delivered"),
            ],
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('userId', isEqualTo: user?.uid ?? '')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: OrdersScreen.primaryPurple,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No product orders found."));
                }

                final docs = snapshot.data!.docs;

                return TabBarView(
                  children: [
                    _buildList(docs, "All"),
                    _buildList(docs, "Pending"),
                    _buildList(docs, "Shipped"),
                    _buildList(docs, "Delivered"),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<QueryDocumentSnapshot> docs, String filter) {
    final filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString().toLowerCase();

      if (filter == "All") return true;

      if (filter == "Pending") {
        return status == 'pending' ||
            status == 'confirmed' ||
            status == 'paid' ||
            status == 'processing';
      }

      if (filter == "Shipped") {
        return status == 'shipped' || status == 'in transit';
      }

      if (filter == "Delivered") {
        return status == 'delivered' || status == 'completed';
      }

      return false;
    }).toList();

    if (filtered.isEmpty) {
      return Center(child: Text("No $filter orders."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final data = filtered[index].data() as Map<String, dynamic>;

        final priceVal = data['totalAmount'] ?? data['price'] ?? 0.0;
        final double price = (priceVal as num).toDouble();
        final shippingMethod = data['shippingMethod'] ?? data['deliveryMethod'] ?? 'Courier';
        final address = data['shippingAddress'] ?? data['deliveryAddress'] ?? 'N/A';
        final status = (data['status'] ?? 'paid').toString().toUpperCase();

        String orderTitle = 'Product Order';
        if (data['items'] != null && (data['items'] as List).isNotEmpty) {
          final firstItem = data['items'][0];
          final itemCount = (data['items'] as List).length;
          final itemName = firstItem['name'] ?? firstItem['title'] ?? 'Item';
          orderTitle = itemCount > 1 ? '$itemName (+$itemCount items)' : '$itemName';
        } else if (data['serviceName'] != null) {
          orderTitle = data['serviceName'];
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3EAF6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.local_shipping, color: OrdersScreen.primaryPurple),
            ),
            title: Text(
              orderTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text("Total: R${price.toStringAsFixed(2)}"),
                Text("Shipping: $shippingMethod"),
                Text("Address: $address", style: const TextStyle(fontSize: 11)),
                if (data['paymentReference'] != null)
                  Text("Ref: ${data['paymentReference']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            trailing: Chip(
              label: Text(
                status,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              backgroundColor: OrdersScreen.primaryPurple,
            ),
          ),
        );
      },
    );
  }
}

class _AppointmentsView extends StatelessWidget {
  const _AppointmentsView();

  // Helper method to handle appointment deletion (for failed payments)
  Future<void> _deleteAppointment(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Booking"),
        content: const Text("Are you sure you want to delete this failed appointment?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('appointments').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed booking deleted successfully.")),
        );
      }
    }
  }

  // Helper method to handle appointment rescheduling & slot release
  Future<void> _rescheduleAppointment(
      BuildContext context,
      String docId,
      String oldDate,
      String oldTime,
      String serviceName,
      ) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );

    if (pickedDate == null || !context.mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );

    if (pickedTime == null || !context.mounted) return;

    final String newDateStr = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
    final String newTimeStr = pickedTime.format(context);

    // Use Firestore Transaction to atomically release old slot & assign new slot
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final apptRef = FirebaseFirestore.instance.collection('appointments').doc(docId);

      // 1. Mark old time slot as available again
      if (oldDate.isNotEmpty && oldTime.isNotEmpty) {
        final oldSlotRef = FirebaseFirestore.instance
            .collection('available_slots')
            .doc('${oldDate}_$oldTime');
        transaction.set(oldSlotRef, {
          'date': oldDate,
          'timeSlot': oldTime,
          'isBooked': false,
        }, SetOptions(merge: true));
      }

      // 2. Reserve new time slot
      final newSlotRef = FirebaseFirestore.instance
          .collection('available_slots')
          .doc('${newDateStr}_$newTimeStr');
      transaction.set(newSlotRef, {
        'date': newDateStr,
        'timeSlot': newTimeStr,
        'isBooked': true,
      }, SetOptions(merge: true));

      // 3. Update appointment record
      transaction.update(apptRef, {
        'date': newDateStr,
        'timeSlot': newTimeStr,
        'status': 'rescheduled',
      });
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Rescheduled to $newDateStr at $newTimeStr")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: user?.uid ?? '')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: OrdersScreen.primaryPurple),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No appointments or bookings found."));
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final priceVal = data['price'] ?? 0.0;
            final double price = (priceVal as num).toDouble();
            final String status = (data['status'] ?? 'PENDING').toString().toUpperCase();
            final String date = data['date'] ?? '';
            final String timeSlot = data['timeSlot'] ?? data['time'] ?? '';
            final String? referenceImageUrl = data['referenceImageUrl'] ?? data['referenceImage'] ?? data['imageUrl'];

            final bool isFailed = status.contains('FAILED');

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3EAF6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Booking Header & Status ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(Icons.calendar_today, color: OrdersScreen.primaryPurple),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['serviceName'] ?? 'Service',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text("Date: $date at $timeSlot"),
                            Text("Price: R${price.toStringAsFixed(2)}"),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(
                          status,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: isFailed ? Colors.red : OrdersScreen.primaryPurple,
                      ),
                    ],
                  ),

                  // --- Booking Summary Section ---
                  const Divider(height: 24, thickness: 1),
                  const Text(
                    "Booking Summary",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: OrdersScreen.primaryPurple),
                  ),
                  const SizedBox(height: 6),
                  Text("Customer: ${data['customerName'] ?? user?.displayName ?? 'N/A'}", style: const TextStyle(fontSize: 12)),
                  Text("Notes: ${data['notes'] ?? 'None'}", style: const TextStyle(fontSize: 12)),

                  // --- Reference Info Picture ---
                  if (referenceImageUrl != null && referenceImageUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      "Reference Style Picture:",
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        referenceImageUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 60,
                          color: Colors.grey[300],
                          child: const Center(child: Text("Could not load image")),
                        ),
                      ),
                    ),
                  ],

                  // Space between reference picture and action buttons
                  const SizedBox(height: 16),

                  // --- Action Buttons (Reschedule & Delete) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isFailed) ...[
                        OutlinedButton.icon(
                          onPressed: () => _deleteAppointment(context, doc.id),
                          icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                          label: const Text("Delete", style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      ElevatedButton.icon(
                        onPressed: () => _rescheduleAppointment(
                          context,
                          doc.id,
                          date,
                          timeSlot,
                          data['serviceName'] ?? 'Service',
                        ),
                        icon: const Icon(Icons.edit_calendar, size: 16, color: Colors.white),
                        label: const Text("Reschedule", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OrdersScreen.primaryPurple,
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
}