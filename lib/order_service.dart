import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// One product line inside an order.
class OrderItem {
  final String productId;
  final String name;
  final double price; // price of ONE unit, in Rand
  final int quantity;
  final String? imageUrl;

  const OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.imageUrl,
  });

  // Field names match what the "My Bookings & Orders" screen reads.
  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'price': price,
        'quantity': quantity,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };
}

/// Saves product orders in the Firestore collection `orders`.
/// Firestore creates the collection automatically on the first save,
/// so there is nothing to set up by hand in the console.
class OrderService {
  OrderService._();

  static final CollectionReference<Map<String, dynamic>> _orders =
      FirebaseFirestore.instance.collection('orders');

  /// Creates the order for the logged-in user and returns its id.
  /// Call this when the customer starts paying (status = Pending).
  static Future<String> createOrder({
    required List<OrderItem> items,
    String? paymentReference,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to place an order.');
    }
    if (items.isEmpty) {
      throw Exception('Your cart is empty.');
    }

    final double total =
        items.fold<double>(0, (sum, i) => sum + i.price * i.quantity);

    final doc = _orders.doc(); // auto-generated id
    await doc.set({
      'orderId': doc.id,
      'userId': user.uid, // <- this is what links the order to the customer
      'userEmail': user.email,
      'items': items.map((i) => i.toMap()).toList(),
      'totalAmount': total,
      'amountInCents': (total * 100).round(),
      'paymentReference': paymentReference,
      'paymentStatus': 'initialized',
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Call when the payment succeeds.
  static Future<void> markPaid(String orderId, {String? paymentReference}) {
    return _orders.doc(orderId).update({
      'status': 'Paid',
      'paymentStatus': 'success',
      if (paymentReference != null) 'paymentReference': paymentReference,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Call when the payment fails or the customer cancels.
  static Future<void> markFailed(String orderId) {
    return _orders.doc(orderId).update({
      'status': 'Payment Failed',
      'paymentStatus': 'failed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
