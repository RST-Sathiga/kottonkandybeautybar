import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  static const Color primaryPurple = Color(0xFF6B3A82);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          title: const Text(
            "My Orders",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            labelColor: primaryPurple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryPurple,
            isScrollable: true,
            tabs: [
              Tab(text: "All"),
              Tab(text: "Pending"),
              Tab(text: "Shipped"),
              Tab(text: "Delivered"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('appointments')
              .where('userId', isEqualTo: user?.uid ?? '')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primaryPurple));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No orders or bookings found."));
            }

            final docs = snapshot.data!.docs;

            return TabBarView(
              children: [
                _buildOrderList(docs, "All"),
                _buildOrderList(docs, "pending"),
                _buildOrderList(docs, "shipped"),
                _buildOrderList(docs, "delivered"),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderList(List<QueryDocumentSnapshot> docs, String filter) {
    final filtered = filter == "All"
        ? docs
        : docs.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == filter).toList();

    if (filtered.isEmpty) {
      return Center(child: Text("No $filter orders."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final data = filtered[index].data() as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3EAF6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.shopping_bag, color: primaryPurple),
            ),
            title: Text(data['serviceName'] ?? 'Service', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Price: R${data['price'] ?? '0.00'}"),
            trailing: Chip(
              label: Text(
                data['status']?.toString().toUpperCase() ?? 'PENDING',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              backgroundColor: primaryPurple,
            ),
          ),
        );
      },
    );
  }
}