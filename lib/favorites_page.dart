import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  static const Color primaryPurple = Color(0xFF6B3A82);
  static const Color lightPurple = Color(0xFFF3EAF6);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Live product details (picture + current price), keyed by product id.
  // Used for favourites saved before the picture was stored with them.
  Map<String, Map<String, dynamic>> _products = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final snap = await _firestore.collection('products').get();
      if (!mounted) return;
      setState(() {
        _products = {for (final d in snap.docs) d.id: d.data()};
      });
    } catch (e) {
      debugPrint('Could not load products for favourites: $e');
    }
  }

  String? _imageFor(String id, Map<String, dynamic> fav) {
    final saved = (fav['image'] ?? fav['imageUrl'] ?? '').toString();
    if (saved.isNotEmpty) return saved;
    final p = _products[id];
    if (p == null) return null;
    final url = (p['imageUrl'] ?? '').toString();
    if (url.isNotEmpty) return url;
    final asset = (p['image'] ?? '').toString();
    return asset.isNotEmpty ? asset : null;
  }

  num _priceFor(String id, Map<String, dynamic> fav) {
    final live = _products[id]?['price'];
    if (live is num) return live;
    final saved = fav['price'];
    return saved is num ? saved : 0;
  }

  IconData _iconFor(String id, Map<String, dynamic> fav) {
    final category =
    (fav['category'] ?? _products[id]?['category'] ?? '').toString();
    switch (category) {
      case 'Hair':
        return Icons.content_cut;
      case 'Nails':
        return Icons.brush;
      case 'Makeup':
        return Icons.face;
      case 'Lashes':
        return Icons.remove_red_eye;
      case 'Skincare':
        return Icons.spa;
      default:
        return Icons.shopping_bag_outlined;
    }
  }

  Widget _thumb(String? image, IconData icon) {
    final fallback = Center(child: Icon(icon, color: primaryPurple, size: 36));
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: lightPurple,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: image == null
          ? fallback
          : (image.startsWith('http')
          ? Image.network(
        image,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      )
          : Image.asset(
        image,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      )),
    );
  }

  Future<void> _remove(String uid, String id) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .doc(id)
          .delete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove favourite: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text(
          'My Favourites',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: user == null
          ? const Center(child: Text('Please sign in to see your favourites.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load favourites.'));
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: primaryPurple),
            );
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite_border,
                      size: 60, color: primaryPurple),
                  const SizedBox(height: 12),
                  const Text(
                    'No favourites yet',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap the heart on a product or service to save it here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final fav = doc.data();
              final name = (fav['name'] ?? '').toString();
              final description = (fav['description'] ?? '').toString();
              final price = _priceFor(doc.id, fav);

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _thumb(_imageFor(doc.id, fav), _iconFor(doc.id, fav)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'R${price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: primaryPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove from favourites',
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () => _remove(user.uid, doc.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}