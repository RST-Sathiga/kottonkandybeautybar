import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'booking_page.dart';

// ───────────────────────── Purple theme ─────────────────────────

const kPurple = Color(0xFF6B3A82);
const kLightPurple = Color(0xFFF3EAF6);

/// Wraps a page so every colour on it is the app's purple instead of pink.
Widget purpleTheme(BuildContext context, Widget child) {
  final base = Theme.of(context);
  OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: w),
  );

  return Theme(
    data: base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: kPurple,
        onPrimary: Colors.white,
        primaryContainer: kLightPurple,
        onPrimaryContainer: kPurple,
        secondaryContainer: kLightPurple,
        onSecondaryContainer: Colors.black87,
        surfaceTint: Colors.transparent,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        focusedBorder: border(kPurple, 2),
        floatingLabelStyle: const TextStyle(color: kPurple),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kPurple,
          side: const BorderSide(color: kPurple),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: kPurple),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPurple,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0x4D6B3A82),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 55),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: kPurple),
    ),
    child: child,
  );
}

// ───────────────────────── Policy ─────────────────────────

enum RefundReason { cantAttend, reschedule, ownerCancelled }

String money(double v) => 'R${v.toStringAsFixed(2)}';

String formatDateTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day}/${d.month}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

class RefundPolicy {
  static const cancelRetainedRate = 0.5; // owner keeps 50% if the client cancels
  static const rescheduleFee = 100.0; // flat R100 to reschedule

  static double fee(RefundReason r, double total) => switch (r) {
    RefundReason.cantAttend => total * cancelRetainedRate,
    RefundReason.reschedule =>
    total < rescheduleFee ? total : rescheduleFee,
    RefundReason.ownerCancelled => 0.0,
  };

  static double refund(RefundReason r, double total) => total - fee(r, total);

  static String title(RefundReason r) => switch (r) {
    RefundReason.cantAttend => 'I am unable to attend my appointment',
    RefundReason.reschedule => 'I want to reschedule',
    RefundReason.ownerCancelled => 'Cancelled by the salon',
  };

  static String message(RefundReason r, double total) => switch (r) {
    RefundReason.cantAttend => '',
    RefundReason.reschedule =>
    'A rescheduling fee of ${money(rescheduleFee)} applies. '
        'This fee is non-refundable and is payable at the time of rescheduling.',
    RefundReason.ownerCancelled =>
    'This appointment was cancelled by the salon. '
        'You are entitled to a full refund of ${money(total)}.',
  };
}

// ───────────────────────── Tolerant readers ─────────────────────────
// Bookings may store the date as a Timestamp or as text, and the price as a
// number or as text, so these accept both instead of crashing.

double parseMoney(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) {
    return double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  }
  return 0;
}

(int, int)? _parseTimeText(String text) {
  final m = RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])?').firstMatch(text);
  if (m == null) return null;
  var h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  final ampm = m.group(3)?.toLowerCase();
  if (ampm == 'pm' && h < 12) h += 12;
  if (ampm == 'am' && h == 12) h = 0;
  if (h > 23 || min > 59) return null;
  return (h, min);
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

DateTime? _parseDateText(String text) {
  final t = text.trim();
  final iso = DateTime.tryParse(t);
  if (iso != null) return iso;

  DateTime? withTime(int y, int mo, int d) {
    final time = _parseTimeText(t);
    return DateTime(y, mo, d, time?.$1 ?? 0, time?.$2 ?? 0);
  }

  // 15/10/2026 or 15-10-2026
  var m = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})').firstMatch(t);
  if (m != null) {
    return withTime(
        int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
  }

  // 15 Oct 2026 or 15 October, 2026
  m = RegExp(r'(\d{1,2})\s+([A-Za-z]{3,})\.?,?\s+(\d{4})').firstMatch(t);
  if (m != null) {
    final mo = _months[m.group(2)!.substring(0, 3).toLowerCase()];
    if (mo != null) {
      return withTime(int.parse(m.group(3)!), mo, int.parse(m.group(1)!));
    }
  }

  // Oct 15, 2026
  m = RegExp(r'([A-Za-z]{3,})\.?\s+(\d{1,2}),?\s+(\d{4})').firstMatch(t);
  if (m != null) {
    final mo = _months[m.group(1)!.substring(0, 3).toLowerCase()];
    if (mo != null) {
      return withTime(int.parse(m.group(3)!), mo, int.parse(m.group(2)!));
    }
  }
  return null;
}

/// Reads the appointment date from a Timestamp or text, and adds the separate
/// `time` field (e.g. "14:30" or "2:30 PM") when the date has no time in it.
DateTime? parseAppointmentDate(dynamic value, [dynamic time]) {
  DateTime? d;
  if (value is Timestamp) {
    d = value.toDate();
  } else if (value is String) {
    d = _parseDateText(value);
  }
  if (d == null) return null;

  if (time is String && d.hour == 0 && d.minute == 0) {
    final t = _parseTimeText(time);
    if (t != null) d = DateTime(d.year, d.month, d.day, t.$1, t.$2);
  }
  return d;
}

// ───────────────────────── Models ─────────────────────────

/// A booking from the `appointments` collection.
class Appointment {
  final String id, title, status;
  final DateTime date;
  final double total;

  /// The raw Firestore data, handed to the booking page when rescheduling.
  final Map<String, dynamic> raw;
  Appointment(this.id, this.title, this.status, this.date, this.total, this.raw);

  factory Appointment.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Appointment(
      doc.id,
      (d['serviceName'] ?? d['service'] ?? d['title'] ?? d['name'] ?? 'Appointment')
          .toString(),
      (d['status'] ?? '').toString().toLowerCase(),
      parseAppointmentDate(d['date'], d['timeSlot'] ?? d['time']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      // Use what was actually paid by card (price minus any loyalty credit).
      parseMoney(d['amountPaid'] ?? d['price'] ?? d['total'] ?? d['amount']),
      d,
    );
  }
}

/// A document from the `refund_requests` collection.
/// The document id is the appointment id, so each appointment has one request.
class RefundRequest {
  final String appointmentId, title, status, adminReason, note;
  final RefundReason reason;
  final double fee, refund;
  final DateTime createdAt;
  final bool refundSent;
  RefundRequest({
    required this.appointmentId,
    required this.title,
    required this.status,
    required this.adminReason,
    required this.note,
    required this.reason,
    required this.fee,
    required this.refund,
    required this.createdAt,
    this.refundSent = false,
  });

  factory RefundRequest.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return RefundRequest(
      appointmentId: (d['appointmentId'] ?? doc.id).toString(),
      title: (d['serviceName'] ?? 'Appointment').toString(),
      status: (d['status'] ?? 'pending').toString().toLowerCase(),
      adminReason: (d['adminReason'] ?? '').toString(),
      note: (d['note'] ?? '').toString(),
      reason: RefundReason.values.firstWhere(
            (r) => r.name == d['reason'],
        orElse: () => RefundReason.cantAttend,
      ),
      fee: (d['fee'] as num?)?.toDouble() ?? 0,
      refund: (d['refundAmount'] as num?)?.toDouble() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      refundSent: d['refundSent'] == true,
    );
  }
}

// ───────────────────────── Refunds page ─────────────────────────

class RefundsPage extends StatefulWidget {
  const RefundsPage({super.key});

  @override
  State<RefundsPage> createState() => _RefundsPageState();
}

class _RefundsPageState extends State<RefundsPage> {
  // Only paid, confirmed bookings can be refunded or rescheduled.
  // (pending = payment not finished, failed = payment failed.)
  static const _refundable = {'confirmed', 'paid'};

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _requestStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _appointmentStream;

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      final db = FirebaseFirestore.instance;
      _requestStream =
          db.collection('refund_requests').where('userId', isEqualTo: _uid).snapshots();
      _appointmentStream =
          db.collection('appointments').where('userId', isEqualTo: _uid).snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return purpleTheme(
      context,
      Scaffold(
        appBar: AppBar(title: const Text('Refunds')),
        body: _uid == null
            ? const Center(child: Text('Please log in to see your refunds.'))
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _requestStream,
          builder: (context, reqSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _appointmentStream,
              builder: (context, apptSnap) {
                if (reqSnap.hasError || apptSnap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                          'Could not load your refunds.\n\n${reqSnap.error ?? apptSnap.error}'),
                    ),
                  );
                }
                if (!reqSnap.hasData || !apptSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final requests = reqSnap.data!.docs
                    .map(RefundRequest.fromDoc)
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                final requested = requests.map((r) => r.appointmentId).toSet();

                final now = DateTime.now();
                final eligible = apptSnap.data!.docs
                    .map(Appointment.fromDoc)
                    .where((a) =>
                a.date.isAfter(now) &&
                    _refundable.contains(a.status) &&
                    !requested.contains(a.id))
                    .toList()
                  ..sort((a, b) => a.date.compareTo(b.date));

                return _content(context, eligible, requests);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<Appointment> eligible,
      List<RefundRequest> requests) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Upcoming appointments', style: text.titleMedium),
        const SizedBox(height: 8),
        if (eligible.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('You have no upcoming appointments to request a refund for.'),
          ),
        for (final a in eligible)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title, style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text('${formatDateTime(a.date)} · ${money(a.total)}'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookingPage(
                                rescheduleAppointment: {...a.raw, 'id': a.id},
                              ),
                            ),
                          ),
                          child: const Text('Reschedule'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => RefundRequestPage(appointment: a)),
                          ),
                          child: const Text('Request refund'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text('Your refund requests', style: text.titleMedium),
        const SizedBox(height: 8),
        if (requests.isEmpty)
          const Text('Nothing here yet. Requests you submit will show up here.'),
        for (final r in requests) _requestCard(context, r),
      ],
    );
  }

  Widget _requestCard(BuildContext context, RefundRequest r) {
    final (label, color) = switch (r.status) {
      'approved' => ('Approved', Colors.green.shade100),
      'declined' => ('Declined', Colors.red.shade100),
      _ => ('Pending', Colors.orange.shade100),
    };

    final amountLine = switch (r.status) {
      'declined' => 'No refund',
      'approved' => r.refundSent
          ? 'Refund of ${money(r.refund)} has been sent'
          : 'Refund of ${money(r.refund)} approved. It is being processed.',
      _ => 'Expected refund: ${money(r.refund)}',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.title,
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                Chip(
                  label: Text(label),
                  backgroundColor: color,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(RefundPolicy.title(r.reason)),
            const SizedBox(height: 4),
            Text(amountLine,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (r.adminReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Note from the salon: ${r.adminReason}'),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Request page ─────────────────────────

class RefundRequestPage extends StatefulWidget {
  final Appointment appointment;
  const RefundRequestPage({super.key, required this.appointment});

  @override
  State<RefundRequestPage> createState() => _RefundRequestPageState();
}

class _RefundRequestPageState extends State<RefundRequestPage> {
  // Rescheduling is not a refund (it goes through the booking page instead),
  // and "cancelled by the owner" is created from the admin side.
  static const _choices = [RefundReason.cantAttend];

  RefundReason? _reason = RefundReason.cantAttend;
  bool _sending = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    final a = widget.appointment;
    final reason = _reason;
    if (user == null || reason == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _sending = true);

    try {
      // Document id = appointment id, so an appointment can only have one request.
      await FirebaseFirestore.instance.collection('refund_requests').doc(a.id).set({
        'appointmentId': a.id,
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'serviceName': a.title,
        'appointmentDate': Timestamp.fromDate(a.date),
        'total': a.total,
        'reason': reason.name,
        'note': _note.text.trim(),
        'fee': RefundPolicy.fee(reason, a.total),
        'refundAmount': RefundPolicy.refund(reason, a.total),
        'status': 'pending',
        'adminReason': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      navigator.pop();
      messenger.showSnackBar(const SnackBar(
          content: Text('Your request has been submitted. The salon will review it and update you.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not send your request. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    return purpleTheme(
      context,
      Scaffold(
        appBar: AppBar(title: const Text('Request a refund')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(a.title, style: Theme.of(context).textTheme.titleLarge),
            Text(formatDateTime(a.date)),
            Text('Total paid: ${money(a.total)}'),
            const SizedBox(height: 20),
            Text('Why are you requesting a refund?',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final r in _choices)
              Card(
                color: _reason == r ? kLightPurple : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: _reason == r ? kPurple : Colors.transparent, width: 1.5),
                ),
                child: ListTile(
                  title: Text(RefundPolicy.title(r)),
                  trailing: _reason == r
                      ? const Icon(Icons.check_circle, color: kPurple)
                      : null,
                  onTap: _sending ? null : () => setState(() => _reason = r),
                ),
              ),
            if (_reason != null) ...[
              const SizedBox(height: 12),
              Card(
                color: kLightPurple,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (RefundPolicy.message(_reason!, a.total).isNotEmpty) ...[
                        Text(RefundPolicy.message(_reason!, a.total)),
                        const Divider(height: 24),
                      ],
                      _row('Total paid', money(a.total)),
                      _row(
                          _reason == RefundReason.reschedule
                              ? 'Reschedule fee'
                              : 'Cancellation fee',
                          '- ${money(RefundPolicy.fee(_reason!, a.total))}'),
                      _row(
                          _reason == RefundReason.reschedule
                              ? 'Kept for new booking'
                              : 'Estimated refund',
                          money(RefundPolicy.refund(_reason!, a.total)),
                          bold: true),
                      const SizedBox(height: 8),
                      const Text(
                          'All requests are reviewed by the salon. You will be notified of the outcome.',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLines: 3,
              enabled: !_sending,
              decoration: const InputDecoration(
                  labelText: 'Additional details (optional)'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (_reason == null || _sending) ? null : _submit,
              child: _sending
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_reason == RefundReason.reschedule
                  ? 'Submit reschedule request'
                  : 'Submit refund request'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
        Text(value,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
      ],
    ),
  );
}