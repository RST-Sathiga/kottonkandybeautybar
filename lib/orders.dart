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
          iconTheme: const IconThemeData(color: Colors.black),
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
              // Query both 'orders' and fallback 'marketplace_orders'
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

        // Fallbacks for field names
        final priceVal = data['totalAmount'] ?? data['price'] ?? 0.0;
        final double price = (priceVal as num).toDouble();
        final shippingMethod = data['shippingMethod'] ?? data['deliveryMethod'] ?? 'Courier';
        final address = data['shippingAddress'] ?? data['deliveryAddress'] ?? 'N/A';
        final status = (data['status'] ?? 'paid').toString().toUpperCase();

        // Extract title or item count
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
            final data = docs[index].data() as Map<String, dynamic>;
            final priceVal = data['price'] ?? 0.0;
            final double price = (priceVal as num).toDouble();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3EAF6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.calendar_today, color: OrdersScreen.primaryPurple),
                ),
                title: Text(
                  data['serviceName'] ?? 'Service',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Date: ${data['date'] ?? 'N/A'} at ${data['timeSlot'] ?? data['time'] ?? 'N/A'}"),
                    Text("Price: R${price.toStringAsFixed(2)}"),
                  ],
                ),
                trailing: Chip(
                  label: Text(
                    data['status']?.toString().toUpperCase() ?? 'PENDING',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: OrdersScreen.primaryPurple,
                ),
              ),
            );
          },
        );
      },
    );
  }
}