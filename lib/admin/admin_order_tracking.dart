import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ADMIN: change an order's status and add the courier tracking number.
/// Use it from your admin orders list, e.g.
///   onPressed: () => showOrderTrackingDialog(context, orderId: doc.id, data: data),
/// Clients see the change live on the Orders tab of their app.
Future<void> showOrderTrackingDialog(
    BuildContext context, {
      required String orderId,
      required Map<String, dynamic> data,
    }) async {
  const statuses = {
    'confirmed': 'Confirmed',
    'shipped': 'Shipped',
    'out_for_delivery': 'Out for delivery',
    'ready_for_collection': 'Ready for collection',
    'delivered': 'Delivered',
    'cancelled': 'Cancelled',
  };

  String normalise(String s) => s.toLowerCase().trim().replaceAll(RegExp(r'[\s-]+'), '_');
  String status = normalise((data['status'] ?? 'confirmed').toString());
  if (!statuses.containsKey(status)) status = 'confirmed';

  final courier = TextEditingController(text: (data['courier'] ?? 'The Courier Guy').toString());
  final tracking = TextEditingController(text: (data['trackingNumber'] ?? '').toString());
  final link = TextEditingController(text: (data['trackingUrl'] ?? '').toString());

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      bool saving = false;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Update order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: statuses.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => status = v ?? status),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: courier,
                  decoration: const InputDecoration(labelText: 'Courier', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tracking,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Tracking number', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: link,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                      labelText: 'Tracking link (optional)', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('CANCEL')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B3A82), foregroundColor: Colors.white),
              onPressed: saving
                  ? null
                  : () async {
                setState(() => saving = true);
                try {
                  await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
                    'status': status,
                    'courier': courier.text.trim(),
                    'trackingNumber': tracking.text.trim(),
                    'trackingUrl': link.text.trim(),
                    'statusUpdatedAt': FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setState(() => saving = false);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Could not save: $e')));
                  }
                }
              },
              child: Text(saving ? 'SAVING...' : 'SAVE'),
            ),
          ],
        ),
      );
    },
  );
}