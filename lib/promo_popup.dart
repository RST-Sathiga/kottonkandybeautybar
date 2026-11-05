import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// One item that is on sale while the promo is live.
class SaleLine {
  final String name;
  final double percent;
  const SaleLine(this.name, this.percent);
}

class PromoPopup extends StatelessWidget {
  final WeeklyPromo promo;
  final List<SaleLine> saleItems;

  const PromoPopup({
    super.key,
    required this.promo,
    this.saleItems = const [],
  });

  static const Color promoPurple = Color(0xFF6B3A87);

  static StreamSubscription<User?>? _authSubscription;
  static String? _shownForUid;

  static void _listenForSignOut() {
    _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) _shownForUid = null;
    });
  }

  static Future<void> showIfAvailable(BuildContext context) async {
    _listenForSignOut();

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || _shownForUid == user.uid) return;
    _shownForUid = user.uid;

    try {
      final WeeklyPromo? promo = await fetchLivePromo();
      if (promo == null || !context.mounted) return;
      final List<SaleLine> sale = await fetchSaleItems();
      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (context) => PromoPopup(promo: promo, saleItems: sale),
      );
    } catch (e) {
      debugPrint('Promo popup error: $e');
    }
  }

  static Future<WeeklyPromo?> fetchLivePromo() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('kind', isEqualTo: 'promo')
        .where('active', isEqualTo: true)
        .get();
    final promos = snapshot.docs.map(WeeklyPromo.fromDoc).where((p) => p.isLive).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    return promos.isEmpty ? null : promos.first;
  }

  /// Items the owner has put on sale (a promo is live when this is shown,
  /// so both "with the promo" and "always" sales apply). Biggest discount first.
  static Future<List<SaleLine>> fetchSaleItems() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('saleActive', isEqualTo: true)
          .get();
      final items = <SaleLine>[];
      for (final d in snapshot.docs) {
        final data = d.data();
        if (data['kind'] == 'promo') continue;
        final DateTime? deleteAt =
        data['pendingDeletion'] == true ? (data['deleteAt'] as Timestamp?)?.toDate() : null;
        if (deleteAt != null && !deleteAt.isAfter(DateTime.now())) continue;
        final double pct = ((data['salePercent'] as num?) ?? 0).toDouble();
        final String name = (data['name'] ?? '').toString().trim();
        if (name.isEmpty || pct <= 0 || pct >= 100) continue;
        items.add(SaleLine(name, pct));
      }
      items.sort((a, b) => b.percent.compareTo(a.percent));
      return items;
    } catch (e) {
      debugPrint('Promo sale items error: $e');
      return const [];
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 2.1,
                child: promo.imageUrl.isNotEmpty
                    ? Image.network(
                  promo.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _imagePlaceholder(),
                )
                    : _imagePlaceholder(),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: Colors.grey.withValues(alpha: 0.6),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close, size: 20, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  children: [
                    const Text(
                      "THIS WEEK'S PROMO",
                      style: TextStyle(
                        color: promoPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      promo.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (promo.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        promo.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                    ],
                    if (saleItems.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ON SALE NOW',
                              style: TextStyle(
                                color: Color(0xFFC62828),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...saleItems.take(4).map(
                                  (s) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    Text(
                                      '${s.percent.toStringAsFixed(0)}% off',
                                      style: const TextStyle(
                                        color: Color(0xFFC62828),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (saleItems.length > 4)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '+ ${saleItems.length - 4} more on sale in the shop',
                                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (promo.endsAt != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Valid until ${_formatDate(promo.endsAt!)}',
                        style: const TextStyle(color: promoPurple, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: promoPurple,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 50),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(promo.buttonText.isEmpty ? 'Got it' : promo.buttonText),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF8D7D0),
      alignment: Alignment.center,
      child: Icon(Icons.local_offer, size: 60, color: promoPurple.withValues(alpha: 0.6)),
    );
  }
}

class WeeklyPromo {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String buttonText;
  final bool active;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? createdAt;

  const WeeklyPromo({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.buttonText,
    required this.active,
    this.startsAt,
    this.endsAt,
    this.createdAt,
  });

  bool get isLive {
    final DateTime now = DateTime.now();
    if (!active) return false;
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (endsAt != null && now.isAfter(endsAt!)) return false;
    return true;
  }

  factory WeeklyPromo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return WeeklyPromo(
      id: doc.id,
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? data['message']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      buttonText: data['buttonText']?.toString() ?? 'Got it',
      active: data['active'] == true,
      startsAt: (data['startsAt'] as Timestamp?)?.toDate(),
      endsAt: (data['endsAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}