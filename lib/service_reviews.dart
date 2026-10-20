import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color _purple = Color(0xFF6B3A82);
const Color _lightPurple = Color(0xFFF3EAF6);

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(dynamic ts) {
  if (ts is! Timestamp) return '';
  final d = ts.toDate();
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// First name only, so other clients never see a full name.
Future<String> _displayName(User user) async {
  String name = (user.displayName ?? '').trim();
  if (name.isEmpty) {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snap.data() ?? {};
      for (final k in ['firstName', 'name', 'fullName', 'displayName']) {
        final v = (data[k] ?? '').toString().trim();
        if (v.isNotEmpty) {
          name = v;
          break;
        }
      }
    } catch (_) {}
  }
  if (name.isEmpty) name = (user.email ?? '').split('@').first;
  if (name.isEmpty) name = 'Client';
  name = name.split(' ').first;
  return name.length > 40 ? name.substring(0, 40) : name;
}

// ============================================================
// Stars
// ============================================================

class _Stars extends StatelessWidget {
  final double rating;
  final double size;
  const _Stars({required this.rating, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final IconData icon = rating >= i + 1
            ? Icons.star
            : (rating >= i + 0.5 ? Icons.star_half : Icons.star_border);
        return Icon(icon, size: size, color: Colors.amber);
      }),
    );
  }
}

// ============================================================
// Small rating line to put under a service (taps open the reviews)
// ============================================================

class ServiceRatingChip extends StatelessWidget {
  final String serviceId;
  final String serviceName;

  const ServiceRatingChip({
    super.key,
    required this.serviceId,
    required this.serviceName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('service_reviews')
          .where('serviceId', isEqualTo: serviceId)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        double avg = 0;
        if (docs.isNotEmpty) {
          avg = docs
              .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0)
              .reduce((a, b) => a + b) /
              docs.length;
        }
        final String label = snap.hasError
            ? 'Reviews'
            : (docs.isEmpty
            ? 'No reviews yet · Be the first'
            : '${avg.toStringAsFixed(1)} (${docs.length}) · Read reviews');

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceReviewsScreen(
                serviceId: serviceId,
                serviceName: serviceName,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _purple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// Reviews screen for one service. Everyone signed in can read all
// reviews and replies. Only clients with a paid booking for this
// service can write a review (one per service, editable).
// ============================================================

class ServiceReviewsScreen extends StatefulWidget {
  final String serviceId;
  final String serviceName;

  const ServiceReviewsScreen({
    super.key,
    required this.serviceId,
    required this.serviceName,
  });

  @override
  State<ServiceReviewsScreen> createState() => _ServiceReviewsScreenState();
}

class _ServiceReviewsScreenState extends State<ServiceReviewsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;

  String? _appointmentId; // a paid booking of this service by this client
  bool _isAdmin = false;
  bool _loadingAccess = true;

  String get _myReviewId => '${widget.serviceId}_${_user?.uid}';

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    final user = _user;
    if (user == null) {
      setState(() => _loadingAccess = false);
      return;
    }
    try {
      final adminSnap = await _db.collection('admins').doc(user.uid).get();
      _isAdmin = adminSnap.exists;
    } catch (_) {}

    try {
      final q = await _db
          .collection('appointments')
          .where('userId', isEqualTo: user.uid)
          .where('serviceId', isEqualTo: widget.serviceId)
          .where('paymentStatus', isEqualTo: 'paid')
          .get();
      if (q.docs.isNotEmpty) _appointmentId = q.docs.first.id;
    } catch (_) {}

    if (mounted) setState(() => _loadingAccess = false);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openReviewSheet(
      QueryDocumentSnapshot<Map<String, dynamic>>? existing) async {
    final user = _user;
    if (user == null) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(
        serviceName: widget.serviceName,
        initialRating: (existing?.data()['rating'] as num?)?.toInt() ?? 0,
        initialComment: (existing?.data()['comment'] ?? '').toString(),
      ),
    );
    if (result == null) return;

    try {
      final ref = _db.collection('service_reviews').doc(_myReviewId);
      if (existing == null) {
        await ref.set({
          'serviceId': widget.serviceId,
          'serviceName': widget.serviceName,
          'userId': user.uid,
          'userName': await _displayName(user),
          'rating': result['rating'],
          'comment': result['comment'],
          'appointmentId': _appointmentId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await ref.update({
          'rating': result['rating'],
          'comment': result['comment'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      _toast('Thanks for your review!');
    } catch (e) {
      debugPrint('Could not save review: $e');
      _toast('Could not save your review. Please try again.');
    }
  }

  Future<void> _deleteReview(String reviewId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text('This also removes all replies to it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final ref = _db.collection('service_reviews').doc(reviewId);
      final replies = await ref.collection('replies').get();
      final batch = _db.batch();
      for (final r in replies.docs) {
        batch.delete(r.reference);
      }
      batch.delete(ref);
      await batch.commit();
    } catch (e) {
      debugPrint('Could not delete review: $e');
      _toast('Could not delete the review. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: Text(widget.serviceName,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _user == null
          ? const Center(child: Text('Please log in to see reviews.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db
            .collection('service_reviews')
            .where('serviceId', isEqualTo: widget.serviceId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            debugPrint('Reviews error: ${snap.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.rate_review_outlined, size: 48, color: _purple),
                    const SizedBox(height: 12),
                    const Text(
                      'Reviews are not available right now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please try again in a little while.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snap.hasData || _loadingAccess) {
            return const Center(
                child: CircularProgressIndicator(color: _purple));
          }

          final docs = snap.data!.docs.toList()
            ..sort((a, b) {
              final ta = a.data()['createdAt'];
              final tb = b.data()['createdAt'];
              final da = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
              final db = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
              return db.compareTo(da);
            });

          QueryDocumentSnapshot<Map<String, dynamic>>? mine;
          for (final d in docs) {
            if (d.id == _myReviewId) mine = d;
          }

          double avg = 0;
          if (docs.isNotEmpty) {
            avg = docs
                .map((d) =>
            (d.data()['rating'] as num?)?.toDouble() ?? 0)
                .reduce((a, b) => a + b) /
                docs.length;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _summaryCard(avg, docs.length),
              const SizedBox(height: 14),
              _writeCard(mine),
              const SizedBox(height: 18),
              Text(
                docs.isEmpty ? 'No reviews yet' : 'All reviews',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ...docs.map((d) => _ReviewCard(
                key: ValueKey(d.id),
                doc: d,
                currentUid: _user!.uid,
                isAdmin: _isAdmin,
                onDelete: () => _deleteReview(d.id),
              )),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryCard(double avg, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(
            count == 0 ? '–' : avg.toStringAsFixed(1),
            style: const TextStyle(
                fontSize: 36, fontWeight: FontWeight.bold, color: _purple),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Stars(rating: avg, size: 22),
              const SizedBox(height: 2),
              Text('$count review${count == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _writeCard(QueryDocumentSnapshot<Map<String, dynamic>>? mine) {
    final canWrite = mine != null || _appointmentId != null;
    if (!canWrite) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _lightPurple,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Everyone can read and reply to reviews. Only clients who have '
              'booked and paid for this service can write one.',
          style: TextStyle(fontSize: 13),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton.icon(
        onPressed: () => _openReviewSheet(mine),
        icon: Icon(mine == null ? Icons.rate_review_outlined : Icons.edit),
        label: Text(
          mine == null ? 'WRITE A REVIEW' : 'EDIT MY REVIEW',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _purple,
          foregroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ============================================================
// One review with its replies
// ============================================================

class _ReviewCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String currentUid;
  final bool isAdmin;
  final VoidCallback onDelete;

  const _ReviewCard({
    super.key,
    required this.doc,
    required this.currentUid,
    required this.isAdmin,
    required this.onDelete,
  });

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  final TextEditingController _replyCtrl = TextEditingController();
  bool _replying = false;
  bool _sending = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (text.isEmpty || user == null || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.doc.reference.collection('replies').add({
        'userId': user.uid,
        'userName': widget.isAdmin ? 'Kotton Kandy' : await _displayName(user),
        'text': text,
        'isOwner': widget.isAdmin,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _replyCtrl.clear();
      if (mounted) setState(() => _replying = false);
    } catch (e) {
      debugPrint('Could not reply: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not send your reply. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.doc.data();
    final rating = (r['rating'] as num?)?.toDouble() ?? 0;
    final comment = (r['comment'] ?? '').toString();
    final mine = r['userId'] == widget.currentUid;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _lightPurple,
                child: Text(
                  ((r['userName'] ?? '?').toString().isEmpty
                      ? '?'
                      : (r['userName'] ?? '?').toString()[0])
                      .toUpperCase(),
                  style: const TextStyle(
                      color: _purple, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r['userName'] ?? 'Client'}${mine ? ' (you)' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(_fmtDate(r['createdAt']),
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              _Stars(rating: rating, size: 16),
              if (mine || widget.isAdmin)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: widget.onDelete,
                ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comment, style: const TextStyle(fontSize: 14)),
          ],
          const SizedBox(height: 6),

          // replies
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.doc.reference
                .collection('replies')
                .orderBy('createdAt')
                .snapshots(),
            builder: (context, snap) {
              final replies = snap.data?.docs ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: replies.map((rd) {
                  final p = rd.data();
                  final owner = p['isOwner'] == true;
                  final canDelete = p['userId'] == widget.currentUid ||
                      mine ||
                      widget.isAdmin;
                  return Container(
                    margin: const EdgeInsets.only(top: 8, left: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: owner ? _lightPurple : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${p['userName'] ?? 'Client'}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5),
                                    ),
                                  ),
                                  if (owner)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: _purple,
                                        borderRadius:
                                        BorderRadius.circular(8),
                                      ),
                                      child: const Text('Salon',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  const SizedBox(width: 8),
                                  Text(_fmtDate(p['createdAt']),
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text((p['text'] ?? '').toString(),
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        if (canDelete)
                          InkWell(
                            onTap: () => rd.reference.delete(),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close, size: 16),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),

          // reply box
          if (_replying) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyCtrl,
                    maxLength: 300,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Write a reply...',
                      counterText: '',
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: _sending ? null : _sendReply,
                  icon: _sending
                      ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, color: _purple),
                ),
              ],
            ),
          ] else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _replying = true),
                icon: const Icon(Icons.reply, size: 18, color: _purple),
                label: const Text('Reply',
                    style: TextStyle(color: _purple)),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// Bottom sheet: pick stars and write a comment
// ============================================================

class _ReviewSheet extends StatefulWidget {
  final String serviceName;
  final int initialRating;
  final String initialComment;

  const _ReviewSheet({
    required this.serviceName,
    required this.initialRating,
    required this.initialComment,
  });

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late int _rating = widget.initialRating;
  late final TextEditingController _ctrl =
  TextEditingController(text: widget.initialComment);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Rate ${widget.serviceName}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    onPressed: () => setState(() => _rating = i + 1),
                    icon: Icon(
                      i < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                  );
                }),
              ),
              TextField(
                controller: _ctrl,
                maxLength: 400,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Tell others about your experience (optional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _rating == 0
                      ? null
                      : () => Navigator.pop(context, {
                    'rating': _rating,
                    'comment': _ctrl.text.trim(),
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('SUBMIT',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}