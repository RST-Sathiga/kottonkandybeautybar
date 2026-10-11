// Put this file in lib/admin/
//
// Needs: url_launcher  ->  flutter pub add url_launcher
//
// Open it from your admin dashboard with:
//   Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminRefundsPage()));
// or use it as a tab body with:  const AdminRefundsPage(showAppBar: false)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const _paystackDashboard = 'https://dashboard.paystack.com/#/transactions';

String _money(num v) => 'R${v.toStringAsFixed(2)}';

String _fmt(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day}/${d.month}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

String _reasonLabel(String reason) => switch (reason) {
  'cantAttend' => 'Client cannot attend (cancellation)',
  'reschedule' => 'Reschedule',
  'ownerCancelled' => 'Cancelled by the salon (full refund)',
  _ => reason,
};

// ───────────────────────── Model ─────────────────────────

class _Req {
  final String id, appointmentId, service, email, status, reason, note, adminReason;
  final double total, fee, refund;
  final bool refundSent;
  final DateTime? appointmentDate;
  final DateTime createdAt;

  _Req({
    required this.id,
    required this.appointmentId,
    required this.service,
    required this.email,
    required this.status,
    required this.reason,
    required this.note,
    required this.adminReason,
    required this.total,
    required this.fee,
    required this.refund,
    required this.refundSent,
    required this.appointmentDate,
    required this.createdAt,
  });

  factory _Req.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return _Req(
      id: doc.id,
      appointmentId: (d['appointmentId'] ?? doc.id).toString(),
      service: (d['serviceName'] ?? 'Appointment').toString(),
      email: (d['userEmail'] ?? 'Unknown client').toString(),
      status: (d['status'] ?? 'pending').toString().toLowerCase(),
      reason: (d['reason'] ?? '').toString(),
      note: (d['note'] ?? '').toString(),
      adminReason: (d['adminReason'] ?? '').toString(),
      total: (d['total'] as num?)?.toDouble() ?? 0,
      fee: (d['fee'] as num?)?.toDouble() ?? 0,
      refund: (d['refundAmount'] as num?)?.toDouble() ?? 0,
      refundSent: d['refundSent'] == true,
      appointmentDate: (d['appointmentDate'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ───────────────────────── Page ─────────────────────────

class AdminRefundsPage extends StatefulWidget {
  /// Set to false when the page is used as the body of a tab in your dashboard.
  final bool showAppBar;

  /// Optional buttons for the app bar (for example a sign-out button).
  final List<Widget>? actions;
  const AdminRefundsPage({super.key, this.showAppBar = true, this.actions});

  @override
  State<AdminRefundsPage> createState() => _AdminRefundsPageState();
}

class _AdminRefundsPageState extends State<AdminRefundsPage> {
  final _db = FirebaseFirestore.instance;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
  _db.collection('refund_requests').snapshots();

  @override
  Widget build(BuildContext context) {
    const tabBar = TabBar(
      labelColor: Colors.black87,
      unselectedLabelColor: Colors.black54,
      indicatorColor: Colors.black87,
      tabs: [
        Tab(text: 'Pending'),
        Tab(text: 'Approved'),
        Tab(text: 'Declined'),
      ],
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: widget.showAppBar
            ? AppBar(
          title: const Text('Refund Requests'),
          actions: widget.actions,
          bottom: tabBar,
        )
            : null,
        body: Column(
          children: [
            if (!widget.showAppBar) const Material(color: Colors.white, child: tabBar),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _stream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Could not load refund requests.\n\n${snap.error}'),
                      ),
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final all = snap.data!.docs.map(_Req.fromDoc).toList()
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  return TabBarView(
                    children: [
                      _list(all.where((r) => r.status == 'pending').toList(),
                          'No pending refund requests.'),
                      _list(all.where((r) => r.status == 'approved').toList(),
                          'No approved refunds yet.'),
                      _list(all.where((r) => r.status == 'declined').toList(),
                          'No declined requests.'),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<_Req> items, String emptyText) {
    if (items.isEmpty) return Center(child: Text(emptyText));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) => _card(items[i]),
    );
  }

  // ───────────── Request card ─────────────

  Widget _card(_Req r) {
    final text = Theme.of(context).textTheme;
    final (label, color) = switch (r.status) {
      'approved' => ('Approved', Colors.green.shade100),
      'declined' => ('Declined', Colors.red.shade100),
      _ => ('Pending', Colors.orange.shade100),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(r.service, style: text.titleMedium)),
                Chip(
                  label: Text(label),
                  backgroundColor: color,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Client: ${r.email}'),
            if (r.appointmentDate != null)
              Text('Appointment: ${_fmt(r.appointmentDate!)}'),
            Text('Requested: ${_fmt(r.createdAt)}'),
            Text('Reason: ${_reasonLabel(r.reason)}'),
            if (r.note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Client note: ${r.note}',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            const Divider(height: 24),
            _row('Total paid', _money(r.total)),
            if (r.fee > 0) _row('Cancellation fee', '- ${_money(r.fee)}'),
            _row('Refund amount', _money(r.refund), bold: true),
            if (r.adminReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Your note: ${r.adminReason}'),
            ],
            const SizedBox(height: 12),
            _actions(r),
          ],
        ),
      ),
    );
  }

  Widget _actions(_Req r) {
    if (r.status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _decide(r, approve: false),
              icon: const Icon(Icons.close, color: Colors.red),
              label: const Text('Decline', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _decide(r, approve: true),
              icon: const Icon(Icons.check),
              label: const Text('Approve'),
            ),
          ),
        ],
      );
    }

    if (r.status == 'approved') {
      if (r.refundSent) {
        return const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Refund sent', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        );
      }
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _showPaystackSheet(r),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Send refund on Paystack'),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
        Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
      ],
    ),
  );

  // ───────────── Approve / decline ─────────────

  Future<void> _decide(_Req r, {required bool approve}) async {
    final messenger = ScaffoldMessenger.of(context);

    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(approve: approve, refund: r.refund),
    );
    if (note == null) return; // cancelled

    try {
      final batch = _db.batch();
      batch.update(_db.collection('refund_requests').doc(r.id), {
        'status': approve ? 'approved' : 'declined',
        'adminReason': note,
        'decidedAt': FieldValue.serverTimestamp(),
      });

      // Approving a cancellation frees the slot and removes it from the client's list.
      if (approve && r.reason != 'reschedule') {
        batch.update(_db.collection('appointments').doc(r.appointmentId), {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelReason': 'Refund approved',
        });
      }
      await batch.commit();

      messenger.showSnackBar(SnackBar(
        content: Text(approve ? 'Refund approved.' : 'Refund request declined.'),
      ));

      if (approve && mounted) _showPaystackSheet(r);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save your decision: $e')));
    }
  }

  // ───────────── Paystack ─────────────

  Future<void> _showPaystackSheet(_Req r) async {
    String? reference;
    try {
      final snap = await _db.collection('appointments').doc(r.appointmentId).get();
      reference = snap.data()?['paymentReference']?.toString();
    } catch (_) {}
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _PaystackSheet(
        request: r,
        reference: reference,
        onMarkSent: () async {
          final sure = await showDialog<bool>(
            context: sheetContext,
            builder: (d) => AlertDialog(
              title: const Text('Refund sent?'),
              content: Text(
                  'Confirm that you have sent the ${_money(r.refund)} refund on Paystack. '
                      'The client will see that their refund was sent.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(d, false),
                    child: const Text('Not yet')),
                TextButton(
                    onPressed: () => Navigator.pop(d, true),
                    child: const Text('Yes, it is sent')),
              ],
            ),
          );
          if (sure != true) return;
          await _db.collection('refund_requests').doc(r.id).update({
            'refundSent': true,
            'refundSentAt': FieldValue.serverTimestamp(),
          });
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
      ),
    );
  }
}

// ───────────────────────── Reason dialog ─────────────────────────

class _ReasonDialog extends StatefulWidget {
  final bool approve;
  final double refund;
  const _ReasonDialog({required this.approve, required this.refund});

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (!widget.approve && text.isEmpty) {
      setState(() => _error = 'Please give a reason for declining.');
      return;
    }
    Navigator.pop(
      context,
      text.isEmpty ? 'Your refund has been approved.' : text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.approve ? 'Approve refund' : 'Decline refund'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.approve)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                  'The client will be refunded ${_money(widget.refund)}. '
                      'You will then be taken to Paystack to send it.'),
            ),
          TextField(
            controller: _controller,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.approve ? 'Note to client (optional)' : 'Reason for declining',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.approve ? 'Approve' : 'Decline'),
        ),
      ],
    );
  }
}

// ───────────────────────── Paystack sheet ─────────────────────────

class _PaystackSheet extends StatelessWidget {
  final _Req request;
  final String? reference;
  final Future<void> Function() onMarkSent;

  const _PaystackSheet({
    required this.request,
    required this.reference,
    required this.onMarkSent,
  });

  Future<void> _copy(BuildContext context, String value, String what) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$what copied.')));
    }
  }

  Future<void> _openPaystack(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(
        Uri.parse(_paystackDashboard),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception('not opened');
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not open Paystack. Open dashboard.paystack.com in your browser.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final amount = request.refund.toStringAsFixed(2);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send refund on Paystack', style: text.titleLarge),
            const SizedBox(height: 4),
            Text('${request.service} · ${request.email}'),
            const SizedBox(height: 16),
            _copyRow(context, 'Refund amount', 'R$amount', amount, 'Amount'),
            const SizedBox(height: 8),
            if (reference != null && reference!.isNotEmpty)
              _copyRow(context, 'Payment reference', reference!, reference!, 'Reference')
            else
              const Text(
                'No payment reference was found on this booking. '
                    'Search for the client\'s email in Paystack instead.',
                style: TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            const Text('1. Tap Open Paystack and log in.\n'
                '2. Find the transaction using the payment reference.\n'
                '3. Choose Refund and enter the refund amount above.\n'
                '4. Come back here and tap Mark refund as sent.'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openPaystack(context),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Paystack'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onMarkSent,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Mark refund as sent'),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Do this later'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _copyRow(BuildContext context, String label, String shown, String copyValue,
      String what) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                Text(shown, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy',
            onPressed: () => _copy(context, copyValue, what),
          ),
        ],
      ),
    );
  }
}