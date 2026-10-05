import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

class OrdersScreen extends StatefulWidget {
  static const Color primaryPurple = Color(0xFF6B3A82);
  static const Color lightPurple = Color(0xFFF3EAF6);

  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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

class _AppointmentsView extends StatelessWidget {
  final User currentUser;

  const _AppointmentsView({required this.currentUser});

  Future<void> _deleteAppointment(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Booking"),
        content: const Text("Are you sure you want to delete this appointment?"),
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
          const SnackBar(content: Text("Booking deleted successfully.")),
        );
      }
    }
  }

  Future<void> _rescheduleAppointment(
      BuildContext context,
      String docId,
      String oldDate,
      String oldTime,
      String currentServiceName,
      ) async {
    final List<String> availableServices = [
      'Press-on Plain',
      'Press-on Glam',
      'Press-on Installation',
      'Cluster Lashes',
      'Classic Lashes',
      'Volume Lashes',
      'Afro Crotchet',
      'Knotless / Box Braids',
      'Wig Installation',
      'Soft Glam',
      'Full Glam',
    ];

    final List<String> availableTimeSlots = [
      '08:00 AM',
      '09:30 AM',
      '11:00 AM',
      '01:00 PM',
      '02:30 PM',
      '07:00 PM',
      '09:00 PM',
    ];

    DateTime? selectedDate;
    String? selectedTime = availableTimeSlots.contains(oldTime) ? oldTime : availableTimeSlots.first;
    String selectedService = availableServices.contains(currentServiceName) ? currentServiceName : availableServices.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Reschedule Appointment",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text("Service Type", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedService,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: availableServices.map((service) {
                      return DropdownMenuItem(value: service, child: Text(service));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedService = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text("Appointment Date", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDate == null
                                ? "Current: $oldDate"
                                : "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}",
                            style: const TextStyle(fontSize: 15),
                          ),
                          const Icon(Icons.calendar_today, color: OrdersScreen.primaryPurple),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Time Slot", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedTime,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: availableTimeSlots.map((slot) {
                      return DropdownMenuItem(value: slot, child: Text(slot));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedTime = val);
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OrdersScreen.primaryPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final String newDateStr = selectedDate == null
                            ? oldDate
                            : "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";
                        final String newTimeStr = selectedTime ?? oldTime;

                        await FirebaseFirestore.instance.collection('appointments').doc(docId).update({
                          'serviceName': selectedService,
                          'date': newDateStr,
                          'timeSlot': newTimeStr,
                          'status': 'rescheduled',
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Rescheduled $selectedService to $newDateStr at $newTimeStr")),
                          );
                        }
                      },
                      child: const Text('Confirm Reschedule', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
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

              final dynamic refRaw = data['referencePhoto'] ??
                  data['referenceImageUrl'] ??
                  data['referenceImage'] ??
                  data['imageUrl'];
              final String? referenceImageUrl = refRaw is String ? refRaw : null;

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

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _deleteAppointment(context, doc.id),
                          icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                          label: const Text("Delete", style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size(0, 40),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _rescheduleAppointment(
                            context,
                            doc.id,
                            date,
                            timeSlot,
                            serviceName,
                          ),
                          icon: const Icon(Icons.edit_calendar, size: 16, color: Colors.white),
                          label: const Text("Reschedule", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: OrdersScreen.primaryPurple,
                            minimumSize: const Size(0, 40),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            } catch (e) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Could not display this item: $e',
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

class _OrdersView extends StatelessWidget {
  final User currentUser;

  const _OrdersView({required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error loading orders: ${snapshot.error}"));
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

              final bool isFailed = statusUpper.contains('FAIL') || statusUpper.contains('CANCEL');

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
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
                            statusUpper,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: isFailed ? Colors.red : OrdersScreen.primaryPurple,
                        ),
                      ],
                    ),
                    const Divider(height: 20),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Total Amount Paid",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          "R${totalAmount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: OrdersScreen.primaryPurple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            } catch (e) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Could not display this item: $e',
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