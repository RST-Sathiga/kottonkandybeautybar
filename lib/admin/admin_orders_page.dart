import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_order_tracking.dart';

/// ADMIN: all shop orders, newest first. Tap "Update" to change the status and
/// add the courier tracking number. Clients see the change straight away.
class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  static const Color primaryPurple = Color(0xFF6B3A82);

  String _filter = 'all';
  static const _filters = {
    'all': 'All',
    'new': 'To ship',
    'shipped': 'On the way',
    'delivered': 'Delivered',
  };

  String _norm(dynamic s) =>
      (s ?? '').toString().toLowerCase().trim().replaceAll(RegExp(r'[\s-]+'), '_');

  String _group(String status) {
    if (status == 'delivered' || status == 'collected' || status == 'completed') return 'delivered';
    if (status == 'shipped' || status == 'out_for_delivery' || status == 'ready_for_collection') return 'shipped';
    if (status.contains('cancel') || status.contains('fail')) return 'other';
    return 'new';
  }

  DateTime _time(Map<String, dynamic> d) {
    final t = d['createdAt'];
    return t is Timestamp ? t.toDate() : DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: _filters.entries
                .map((e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: _filter == e.key,
                        selectedColor: primaryPurple,
                        labelStyle: TextStyle(color: _filter == e.key ? Colors.white : Colors.black87),
                        onSelected: (_) => setState(() => _filter = e.key),
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('orders').snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator(color: primaryPurple));
              }
              final docs = snap.data!.docs.where((d) {
                if (_filter == 'all') return true;
                return _group(_norm(d.data()['status'])) == _filter;
              }).toList()
                ..sort((a, b) => _time(b.data()).compareTo(_time(a.data())));

              if (docs.isEmpty) return const Center(child: Text('No orders here.'));

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                itemCount: docs.length,
                itemBuilder: (context, i) => _orderCard(docs[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _orderCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final status = _norm(d['status']);
    final items = d['items'] is List ? d['items'] as List : [];
    final total = ((d['amountPaid'] ?? d['totalAmount'] ?? d['price'] ?? 0) as num).toDouble();
    final tracking = (d['trackingNumber'] ?? '').toString();
    final created = _time(d);
    final dateText =
        '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Order #${doc.id.length > 8 ? doc.id.substring(0, 8) : doc.id}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Chip(
                  label: Text(status.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  backgroundColor: _group(status) == 'delivered'
                      ? Colors.green.shade600
                      : (status.contains('cancel') || status.contains('fail'))
                          ? Colors.red
                          : primaryPurple,
                ),
              ],
            ),
            Text('${d['userEmail'] ?? ''} · $dateText',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            ...items.map((i) {
              final m = i is Map ? i : {};
              return Text('${m['quantity'] ?? 1} x ${m['name'] ?? 'Item'}', style: const TextStyle(fontSize: 13));
            }),
            const SizedBox(height: 8),
            Text('Deliver to: ${d['deliveryAddress'] ?? d['shippingAddress'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 12)),
            Text('Method: ${d['deliveryMethod'] ?? d['shippingMethod'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 12)),
            if (tracking.isNotEmpty)
              Text('Tracking: ${d['courier'] ?? 'Courier'} $tracking',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('R${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: primaryPurple, fontSize: 16)),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, foregroundColor: Colors.white),
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const Text('Update'),
                  onPressed: () => showOrderTrackingDialog(context, orderId: doc.id, data: d),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
