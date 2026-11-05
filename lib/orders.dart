import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'marketplace.dart';

// ---------------------------------------------------------------------------
// Helpers: safely read Firestore values no matter how they were saved
// ---------------------------------------------------------------------------

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) {
    return double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
  }
  return 0.0;
}

int _toInt(dynamic v, {int fallback = 1}) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

String _toDateString(dynamic v) {
  if (v is Timestamp) {
    final d = v.toDate();
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }
  return v?.toString() ?? 'N/A';
}

// Newest first (done here so no Firestore composite index is needed)
List<QueryDocumentSnapshot> _sortNewestFirst(List<QueryDocumentSnapshot> docs) {
  DateTime timeOf(QueryDocumentSnapshot d) {
    final data = d.data() as Map<String, dynamic>;
    final t = data['createdAt'];
    // A just-saved order has no server time yet, so treat it as newest.
    return t is Timestamp ? t.toDate() : DateTime.now();
  }

  final list = List<QueryDocumentSnapshot>.from(docs);
  list.sort((a, b) => timeOf(b).compareTo(timeOf(a)));
  return list;
}


// ---------------------------------------------------------------------------
// Order tracking helpers
// ---------------------------------------------------------------------------

String _normStatus(String s) => s.toLowerCase().trim().replaceAll(RegExp(r'[\s-]+'), '_');

/// -1 = cancelled/failed, 0 = confirmed, 1 = shipped, 2 = out for delivery
/// (or ready for collection), 3 = delivered.
int _orderStep(String rawStatus) {
  final s = _normStatus(rawStatus);
  if (s.contains('cancel') || s.contains('fail') || s == 'refunded') return -1;
  switch (s) {
    case 'shipped':
    case 'dispatched':
    case 'in_transit':
      return 1;
    case 'out_for_delivery':
    case 'ready_for_collection':
      return 2;
    case 'delivered':
    case 'collected':
    case 'completed':
      return 3;
    default:
      return 0; // pending, paid, confirmed, processing ...
  }
}

String _friendlyStatus(String rawStatus) {
  final s = _normStatus(rawStatus);
  switch (_orderStep(rawStatus)) {
    case -1:
      return s.contains('fail') ? 'Payment failed' : 'Cancelled';
    case 1:
      return 'Shipped';
    case 2:
      return s == 'ready_for_collection' ? 'Ready for collection' : 'Out for delivery';
    case 3:
      return 'Delivered';
    default:
      return s == 'pending' ? 'Pending' : 'Confirmed';
  }
}

Color _statusColor(int step) {
  if (step == -1) return Colors.red;
  if (step == 3) return Colors.green.shade600;
  return OrdersScreen.primaryPurple;
}

/// Confirmed -> Shipped -> Out for delivery -> Delivered
class _OrderTracker extends StatelessWidget {
  final int step;
  final bool collection;
  const _OrderTracker({required this.step, required this.collection});

  @override
  Widget build(BuildContext context) {
    final labels = ['Confirmed', 'Shipped', collection ? 'Ready for collection' : 'Out for delivery', 'Delivered'];
    const purple = OrdersScreen.primaryPurple;
    final grey = Colors.grey.shade300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(4, (i) {
        final bool done = i <= step;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(height: 3, color: i == 0 ? Colors.transparent : (i <= step ? purple : grey)),
                  ),
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: done ? purple : grey,
                    child: Icon(done ? Icons.check : Icons.circle, size: done ? 14 : 6, color: Colors.white),
                  ),
                  Expanded(
                    child: Container(height: 3, color: i == 3 ? Colors.transparent : (i < step ? purple : grey)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: i == step ? FontWeight.bold : FontWeight.normal,
                  color: done ? Colors.black87 : Colors.grey,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Courier name + tracking number (with copy buttons), or a "coming soon" note.
class _TrackingInfo extends StatelessWidget {
  final int step;
  final String courier;
  final String trackingNumber;
  final String trackingUrl;
  final bool collection;

  const _TrackingInfo({
    required this.step,
    required this.courier,
    required this.trackingNumber,
    required this.trackingUrl,
    required this.collection,
  });

  void _copy(BuildContext context, String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what copied'), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (trackingNumber.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: OrdersScreen.lightPurple,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping_outlined, size: 18, color: OrdersScreen.primaryPurple),
                const SizedBox(width: 6),
                Text(courier.isEmpty ? 'Courier' : courier,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Tracking number', style: TextStyle(fontSize: 11, color: Colors.grey)),
            Row(
              children: [
                Expanded(
                  child: SelectableText(trackingNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
                ),
                IconButton(
                  tooltip: 'Copy tracking number',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => _copy(context, trackingNumber, 'Tracking number'),
                ),
              ],
            ),
            if (trackingUrl.isNotEmpty)
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Copy tracking link'),
                onPressed: () => _copy(context, trackingUrl, 'Tracking link'),
              ),
          ],
        ),
      );
    }

    String message;
    if (step == 3) {
      message = collection ? 'Your order has been collected. Thank you!' : 'Your order has been delivered. Thank you!';
    } else if (step == 0) {
      message = 'We are getting your order ready. Your tracking number will appear here once it ships.';
    } else {
      message = 'Your tracking number will appear here shortly.';
    }
    return Text(message, style: const TextStyle(fontSize: 12, color: Colors.grey));
  }
}

class OrdersScreen extends StatefulWidget {
  static const Color primaryPurple = Color(0xFF6B3A82);
  static const Color lightPurple = Color(0xFFF3EAF6);

  /// 0 = Appointments tab, 1 = Orders tab.
  final int initialTab;

  const OrdersScreen({super.key, this.initialTab = 0});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Goes back to the previous screen, or to the marketplace if there isn't one.
  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const MarketplaceScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: _goBack,
        ),
        title: const Text(
          "My Bookings & Orders",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: OrdersScreen.primaryPurple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: OrdersScreen.primaryPurple,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month), text: "Appointments"),
            Tab(icon: Icon(Icons.shopping_bag), text: "Orders"),
          ],
        ),
      ),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: OrdersScreen.primaryPurple));
          }

          final currentUser = authSnapshot.data ?? FirebaseAuth.instance.currentUser;

          if (currentUser == null) {
            return const Center(
              child: Text(
                "Please log in to view your bookings and orders.",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _AppointmentsView(currentUser: currentUser),
              _OrdersView(currentUser: currentUser),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// APPOINTMENTS TAB (display only: rescheduling and refunds live on the Refunds page)
// ---------------------------------------------------------------------------

class _AppointmentsView extends StatelessWidget {
  final User currentUser;

  const _AppointmentsView({required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("We could not load your appointments right now. Please try again later."));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: OrdersScreen.primaryPurple));
        }

        final docs = _sortNewestFirst(snapshot.data?.docs ?? []);

        if (docs.isEmpty) {
          return const Center(
            child: Text("No appointments found."),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            try {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final double price = _toDouble(data['price'] ?? data['totalAmount']);
              final String rawStatus = (data['status'] ?? 'PENDING').toString();
              final String statusUpper = rawStatus.toUpperCase();
              final String date = _toDateString(data['date']);
              final String timeSlot = (data['timeSlot'] ?? data['time'] ?? 'N/A').toString();
              final String serviceName = (data['serviceName'] ?? 'Service').toString();
              final String customerEmail = (data['userEmail'] ?? currentUser.email ?? 'N/A').toString();

              final bool wasRescheduled = data['rescheduled'] == true;
              final String previousDate = _toDateString(data['previousDate']);
              final String previousTime = (data['previousTimeSlot'] ?? '').toString();

              final dynamic refRaw = data['referencePhoto'] ??
                  data['referenceImageUrl'] ??
                  data['referenceImage'] ??
                  data['imageUrl'];
              final String? referenceImageUrl = refRaw is String ? refRaw : null;
              Uint8List? referenceBytes;
              if (data['referencePhotoData'] is String) {
                try {
                  referenceBytes = base64Decode(data['referencePhotoData'] as String);
                } catch (_) {}
              }
              final bool hasReference = (referenceImageUrl != null && referenceImageUrl.isNotEmpty) || referenceBytes != null;

              final bool isFailed = statusUpper.contains('FAIL') || statusUpper.contains('CANCEL');

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
                                serviceName,
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
                            statusUpper,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: isFailed ? Colors.red : OrdersScreen.primaryPurple,
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 1),
                    const Text(
                      "Booking Summary",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: OrdersScreen.primaryPurple),
                    ),
                    const SizedBox(height: 6),
                    Text("Customer: $customerEmail", style: const TextStyle(fontSize: 12)),
                    if (wasRescheduled)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          "Rescheduled from $previousDate${previousTime.isEmpty ? '' : ' at $previousTime'}",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),

                    if (hasReference) ...[
                      const SizedBox(height: 12),
                      const Text(
                        "Reference Style Picture:",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: referenceBytes != null
                            ? Image.memory(
                          referenceBytes,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                            : Image.network(
                          referenceImageUrl!,
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
                  ],
                ),
              );
            } catch (e) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Could not display this item.',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              );
            }
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// ORDERS TAB
// ---------------------------------------------------------------------------

class _OrdersView extends StatelessWidget {
  final User currentUser;

  const _OrdersView({required this.currentUser});

  static const Set<String> _paidStates = {'paid', 'success'};

  /// Cancel button (before the order ships) or the progress of a cancellation already requested.
  List<Widget> _cancelSection(
      BuildContext context,
      String docId,
      Map<String, dynamic> data,
      String orderId,
      int step,
      double amountPaid,
      List<dynamic> items,
      Map<String, dynamic>? req,
      ) {
    if (req != null) {
      final String reqStatus = (req['status'] ?? '').toString().toLowerCase();
      final bool sent = req['refundSent'] == true;
      final String money = 'R${amountPaid.toStringAsFixed(2)}';
      String text;
      Color color;
      if (reqStatus == 'declined') {
        final String why = (req['adminReason'] ?? '').toString();
        text = 'Cancellation declined.${why.isEmpty ? '' : ' $why'}';
        color = Colors.red.shade700;
      } else if (reqStatus == 'approved') {
        text = sent
            ? 'Your refund of $money has been sent to your original payment method.'
            : 'Cancellation approved. Your refund of $money is being processed (3-5 business days).';
        color = Colors.green.shade700;
      } else {
        text = 'Cancellation requested. The salon is reviewing it, and your refund of $money follows once it is approved.';
        color = Colors.orange.shade800;
      }
      return [
        const Divider(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text, style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ];
    }

    final String paymentStatus = _normStatus((data['paymentStatus'] ?? '').toString());
    final bool canCancel = step == 0 && _paidStates.contains(paymentStatus);
    if (!canCancel) return const [];

    return [
      const Divider(height: 24),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _confirmCancel(context, docId, data, orderId, amountPaid, items),
          icon: const Icon(Icons.cancel_outlined, size: 18),
          label: const Text('CANCEL ORDER & REQUEST REFUND'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade300),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ];
  }

  Future<void> _confirmCancel(
      BuildContext context,
      String docId,
      Map<String, dynamic> data,
      String orderId,
      double amountPaid,
      List<dynamic> items,
      ) async {
    final messenger = ScaffoldMessenger.of(context);
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          'You will be refunded R${amountPaid.toStringAsFixed(2)}, the amount you paid, to your '
              'original payment method once the salon approves it (3-5 business days).\n\n'
              'Orders that have already shipped cannot be cancelled. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes, cancel order', style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
    if (yes != true) return;

    final names = items
        .map((e) => e is Map ? (e['name'] ?? e['title'] ?? '').toString() : '')
        .where((n) => n.isNotEmpty)
        .join(', ');
    final short = orderId.substring(0, orderId.length > 8 ? 8 : orderId.length);

    try {
      // One refund request per order: its id is the order id.
      await FirebaseFirestore.instance.collection('refund_requests').doc(docId).set({
        'type': 'order',
        'orderId': docId,
        'userId': currentUser.uid,
        'userEmail': currentUser.email ?? (data['userEmail'] ?? '').toString(),
        'serviceName': names.isEmpty ? 'Order #$short' : 'Order #$short: $names',
        'reason': 'orderCancelled',
        'total': amountPaid,
        'fee': 0,
        'refundAmount': amountPaid,
        'paymentReference': (data['paymentReference'] ?? '').toString(),
        'status': 'pending',
        'refundSent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Cancellation requested. We will update you here.')),
      );
    } catch (e) {
      debugPrint('Cancellation request failed: $e');
      messenger.showSnackBar(const SnackBar(content: Text('Could not request the cancellation. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("We could not load your orders right now. Please try again later."));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: OrdersScreen.primaryPurple));
        }

        final docs = _sortNewestFirst(snapshot.data?.docs ?? []);

        if (docs.isEmpty) {
          return const Center(
            child: Text("No product orders found."),
          );
        }

        // The customer's refund requests, so each order can show its cancellation progress.
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('refund_requests')
              .where('userId', isEqualTo: currentUser.uid)
              .snapshots(),
          builder: (context, reqSnap) {
            final Map<String, Map<String, dynamic>> reqs = {
              for (final d in (reqSnap.data?.docs ?? []))
                (((d.data() as Map<String, dynamic>)['orderId']) ?? '').toString():
                d.data() as Map<String, dynamic>,
            };
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                try {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final String orderId = (data['orderId'] ?? doc.id).toString();
                  final String rawStatus = (data['status'] ?? 'PENDING').toString();
                  final String statusUpper = rawStatus.toUpperCase();
                  final double totalAmount = _toDouble(data['totalAmount'] ?? data['price']);
                  final List<dynamic> items = data['items'] is List ? data['items'] as List<dynamic> : [];
                  final String customerEmail = (data['userEmail'] ?? currentUser.email ?? 'N/A').toString();

                  final int step = _orderStep(rawStatus);
                  final bool collection = _normStatus(rawStatus) == 'ready_for_collection' ||
                      (data['deliveryMethod'] ?? data['shippingMethod'] ?? '').toString().toLowerCase().contains('kiosk') ||
                      (data['deliveryMethod'] ?? data['shippingMethod'] ?? '').toString().toLowerCase().contains('collect');
                  final String courier = (data['courier'] ?? 'The Courier Guy').toString();
                  final String trackingNumber = (data['trackingNumber'] ?? '').toString().trim();
                  final String trackingUrl = (data['trackingUrl'] ?? '').toString().trim();
                  final double creditUsed = _toDouble(data['creditUsed']);
                  final double amountPaid = data['amountPaid'] != null ? _toDouble(data['amountPaid']) : totalAmount;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Order #${orderId.substring(0, orderId.length > 8 ? 8 : orderId.length)}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Customer: $customerEmail",
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Chip(
                              label: Text(
                                _friendlyStatus(rawStatus).toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: _statusColor(step),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        if (step >= 0) ...[
                          _OrderTracker(step: step, collection: collection),
                          const SizedBox(height: 14),
                          _TrackingInfo(
                            step: step,
                            courier: courier,
                            trackingNumber: trackingNumber,
                            trackingUrl: trackingUrl,
                            collection: collection,
                          ),
                          const Divider(height: 24),
                        ],
                        _DeliverySummary(data: data),
                        if (items.isNotEmpty) ...[
                          const Text(
                            "Items Ordered",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: OrdersScreen.primaryPurple),
                          ),
                          const SizedBox(height: 8),
                          Table(
                            columnWidths: const {
                              0: FlexColumnWidth(3),
                              1: FlexColumnWidth(1),
                              2: FlexColumnWidth(2),
                            },
                            children: items.map((item) {
                              final Map<String, dynamic> itemMap =
                              item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
                              final String name = (itemMap['name'] ?? itemMap['title'] ?? 'Product').toString();
                              final int qty = _toInt(itemMap['quantity'] ?? itemMap['qty']);
                              final double itemPrice = _toDouble(itemMap['price']);

                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(name, style: const TextStyle(fontSize: 13)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text("x$qty", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      "R${(itemPrice * qty).toStringAsFixed(2)}",
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                          const Divider(height: 20),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                (data['serviceName'] ?? data['productName'] ?? 'Product Order').toString(),
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                              ),
                              Text(
                                "R${totalAmount.toStringAsFixed(2)}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                        ],
                        if (creditUsed > 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Loyalty credit used", style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text("-R${creditUsed.toStringAsFixed(2)}",
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Total Amount Paid",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              "R${amountPaid.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: OrdersScreen.primaryPurple,
                              ),
                            ),
                          ],
                        ),
                        ..._cancelSection(context, doc.id, data, orderId, step, amountPaid, items, reqs[doc.id]),
                      ],
                    ),
                  );
                } catch (e) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Could not display this item.',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Where the order is going: the locker or the address the customer chose
// ---------------------------------------------------------------------------

class _DeliverySummary extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DeliverySummary({required this.data});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? locker =
    data['locker'] is Map ? Map<String, dynamic>.from(data['locker'] as Map) : null;
    final Map<String, dynamic>? addr = data['deliveryAddressData'] is Map
        ? Map<String, dynamic>.from(data['deliveryAddressData'] as Map)
        : null;
    final String method = (data['deliveryMethod'] ?? data['shippingMethod'] ?? '').toString();
    final String fallback = (data['deliveryAddress'] ?? data['shippingAddress'] ?? '').toString();

    final bool isLocker = data['deliveryType'] == 'locker' || locker != null;
    final String title = isLocker ? 'Collect from locker' : 'Delivery address';

    String line;
    if (isLocker) {
      line = [(locker?['name'] ?? '').toString(), (locker?['address'] ?? '').toString()]
          .where((s) => s.isNotEmpty)
          .join('\n');
    } else {
      line = (addr?['formatted'] ?? '').toString();
    }
    if (line.isEmpty) line = fallback;
    if (line.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isLocker ? Icons.inventory_2_outlined : Icons.home_outlined,
                size: 20, color: OrdersScreen.primaryPurple),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: OrdersScreen.primaryPurple)),
                  const SizedBox(height: 2),
                  Text(line, style: const TextStyle(fontSize: 13)),
                  if (method.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(method, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                    ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 24),
      ],
    );
  }
}