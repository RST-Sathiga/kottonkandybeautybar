import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Product reviews.
///
/// Firestore: `reviews/{productId}_{uid}`  (one review per client per product)
///   productId, productName, userId, userName, rating (1-5), comment, createdAt
///
/// Everyone who is signed in can READ every review. A client can only write /
/// edit / delete their own, and only for products they have ordered.
const Color _purple = Color(0xFF6B3A82);
const Color _lightPurple = Color(0xFFF3EAF6);

/// Opens the reviews sheet for a product. Call this when a photo is tapped.
Future<void> showProductReviews(
    BuildContext context, {
      required String productId,
      required String productName,
      bool isProduct = true,
    }) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReviewsSheet(
      productId: productId,
      productName: productName,
      isProduct: isProduct,
    ),
  );
}

Widget _stars(double rating, {double size = 18}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) {
      final filled = rating >= i + 1;
      final half = !filled && rating > i + 0.25;
      return Icon(
        filled ? Icons.star : (half ? Icons.star_half : Icons.star_border),
        size: size,
        color: const Color(0xFFF5A623),
      );
    }),
  );
}

class _ReviewsSheet extends StatefulWidget {
  final String productId;
  final String productName;
  final bool isProduct;
  const _ReviewsSheet({
    required this.productId,
    required this.productName,
    required this.isProduct,
  });

  @override
  State<_ReviewsSheet> createState() => _ReviewsSheetState();
}

class _ReviewsSheetState extends State<_ReviewsSheet> {
  final _db = FirebaseFirestore.instance;
  final _commentCtrl = TextEditingController();
  int _rating = 0;
  bool _saving = false;
  bool? _canReview; // null = still checking
  bool _loadedMine = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String get _myDocId => '${widget.productId}_$_uid';

  @override
  void initState() {
    super.initState();
    _checkPurchased();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  /// A client may only review a product they have ordered.
  Future<void> _checkPurchased() async {
    final uid = _uid;
    if (uid == null || !widget.isProduct) {
      if (mounted) setState(() => _canReview = false);
      return;
    }
    try {
      final snap =
      await _db.collection('orders').where('userId', isEqualTo: uid).get();
      final bought = snap.docs.any((d) {
        final status = (d.data()['status'] ?? '').toString().toLowerCase();
        if (status == 'cancelled') return false;
        final items = d.data()['items'];
        if (items is! List) return false;
        return items.any((i) => i is Map && i['id']?.toString() == widget.productId);
      });
      if (mounted) setState(() => _canReview = bought);
    } catch (_) {
      if (mounted) setState(() => _canReview = false);
    }
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_rating < 1) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please tap the stars to rate.')));
      return;
    }
    setState(() => _saving = true);
    try {
      String name = (user.displayName ?? '').trim();
      if (name.isEmpty) {
        try {
          final u = await _db.collection('users').doc(user.uid).get();
          final d = u.data() ?? {};
          name = (d['fullName'] ?? d['name'] ?? '').toString().trim();
        } catch (_) {}
      }
      if (name.isEmpty) name = (user.email ?? 'Client').split('@').first;
      // Show a first name + initial only, other clients can see this.
      final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
      final shown = parts.length > 1 ? '${parts.first} ${parts.last[0]}.' : name;

      final ref = _db.collection('reviews').doc(_myDocId);
      final existing = await ref.get();
      if (existing.exists) {
        // Editing: only change the rating and comment, so the owner's reply is kept.
        await ref.update({
          'userName': shown,
          'rating': _rating,
          'comment': _commentCtrl.text.trim(),
        });
      } else {
        await ref.set({
          'productId': widget.productId,
          'productName': widget.productName,
          'userId': user.uid,
          'userName': shown,
          'rating': _rating,
          'comment': _commentCtrl.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Thank you for your review!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save your review. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteMine() async {
    try {
      await _db.collection('reviews').doc(_myDocId).delete();
      if (mounted) {
        setState(() {
          _rating = 0;
          _commentCtrl.clear();
          _loadedMine = false;
        });
      }
    } catch (_) {}
  }

  String _date(Timestamp? t) {
    if (t == null) return '';
    final d = t.toDate();
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _db
                .collection('reviews')
                .where('productId', isEqualTo: widget.productId)
                .snapshots(),
            builder: (context, snap) {
              final docs = [...(snap.data?.docs ?? [])];
              docs.sort((a, b) {
                final ta = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                final tb = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                return tb.compareTo(ta);
              });

              // Pre-fill the form with my own existing review (once).
              if (!_loadedMine && snap.hasData) {
                _loadedMine = true;
                for (final d in docs) {
                  if (d.id == _myDocId) {
                    _rating = ((d.data()['rating'] as num?) ?? 0).toInt();
                    _commentCtrl.text = (d.data()['comment'] ?? '').toString();
                  }
                }
              }
              final hasMine = docs.any((d) => d.id == _myDocId);
              double avg = 0;
              if (docs.isNotEmpty) {
                avg = docs
                    .map((d) => ((d.data()['rating'] as num?) ?? 0).toDouble())
                    .reduce((a, b) => a + b) /
                    docs.length;
              }

              return ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.productName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (docs.isEmpty)
                    Text('No reviews yet.', style: TextStyle(color: Colors.grey[600]))
                  else
                    Row(
                      children: [
                        Text(
                          avg.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 32, fontWeight: FontWeight.bold, color: _purple),
                        ),
                        const SizedBox(width: 10),
                        _stars(avg, size: 22),
                        const SizedBox(width: 10),
                        Text('${docs.length} review${docs.length == 1 ? '' : 's'}',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  const SizedBox(height: 18),

                  // ---- write / edit my review ----
                  if (_canReview == true)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _lightPurple,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(hasMine ? 'Your review' : 'Rate this product',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Row(
                            children: List.generate(
                              5,
                                  (i) => IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                onPressed: () => setState(() => _rating = i + 1),
                                icon: Icon(
                                  i < _rating ? Icons.star : Icons.star_border,
                                  color: const Color(0xFFF5A623),
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                          TextField(
                            controller: _commentCtrl,
                            maxLines: 3,
                            maxLength: 400,
                            decoration: InputDecoration(
                              hintText: 'Tell others what you think (optional)',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _saving ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _purple,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(_saving
                                      ? 'Saving...'
                                      : (hasMine ? 'Update review' : 'Submit review')),
                                ),
                              ),
                              if (hasMine) ...[
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: _deleteMine,
                                  child: const Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    )
                  else if (_canReview == false && widget.isProduct)
                    Text(
                      'You can leave a review once you have ordered this product.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  const SizedBox(height: 16),

                  // ---- everyone's reviews ----
                  if (snap.hasError)
                    Text('Reviews could not be loaded right now.',
                        style: TextStyle(color: Colors.grey[600]))
                  else
                    ...docs.map((d) {
                      final r = d.data();
                      final mine = d.id == _myDocId;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _stars(((r['rating'] as num?) ?? 0).toDouble(), size: 16),
                                const Spacer(),
                                Text(_date(r['createdAt'] as Timestamp?),
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(mine ? 'You' : (r['userName'] ?? 'Client').toString(),
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            if ((r['comment'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(r['comment'].toString()),
                            ],
                            if ((r['ownerReply'] ?? '').toString().trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _lightPurple,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: _purple,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text('Salon',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('Kotton Kandy replied',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600, fontSize: 12.5)),
                                        const Spacer(),
                                        Text(_date(r['ownerReplyAt'] as Timestamp?),
                                            style: TextStyle(
                                                fontSize: 11, color: Colors.grey[600])),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(r['ownerReply'].toString(),
                                        style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Small "★ 4.5 (12 reviews)" line that opens the reviews when tapped.
class ReviewSummaryButton extends StatelessWidget {
  final String productId;
  final String productName;
  final bool isProduct;
  const ReviewSummaryButton({
    super.key,
    required this.productId,
    required this.productName,
    this.isProduct = true,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('productId', isEqualTo: productId)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        double avg = 0;
        if (docs.isNotEmpty) {
          avg = docs
              .map((d) => ((d.data()['rating'] as num?) ?? 0).toDouble())
              .reduce((a, b) => a + b) /
              docs.length;
        }
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => showProductReviews(context,
              productId: productId, productName: productName, isProduct: isProduct),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                _stars(avg, size: 18),
                const SizedBox(width: 8),
                Text(
                  docs.isEmpty
                      ? 'No reviews yet'
                      : '${avg.toStringAsFixed(1)} (${docs.length} review${docs.length == 1 ? '' : 's'})',
                  style: const TextStyle(
                      color: _purple, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const Icon(Icons.chevron_right, color: _purple, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}