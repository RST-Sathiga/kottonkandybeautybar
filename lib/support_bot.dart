import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// What the bot replies with.
class BotReply {
  final String text;
  final bool escalate; // true = hand the chat over to the owner
  final List<String> suggestions; // tappable follow-up topics
  const BotReply(this.text, {this.escalate = false, this.suggestions = const []});
}

class _Intent {
  final String id;
  final List<String> keywords; // matched as whole words / phrases
  final String answer;
  final List<String> related; // follow-up chips
  const _Intent(this.id, this.keywords, this.answer, [this.related = const []]);
}

/// FAQ chatbot for Kotton Kandy. No admin involved until the customer asks
/// for a person.
class SupportBot {
  static const greeting =
      'Hi! I am the Kotton Kandy assistant. I can help with orders, delivery, '
      'bookings, refunds, products and loyalty points. What would you like to know?';

  static const topics = [
    'Track my order',
    'Booking policy',
    'Delivery times',
    'Refunds',
    'Loyalty points',
    'Speak to the owner',
  ];

  // Edit these answers whenever your policies change.
  static const _intents = <_Intent>[
    _Intent('order', ['track my order', 'track', 'tracking', 'my order', 'order status', 'where is my order', 'where is my parcel', 'parcel', 'shipped'],
        'ORDER', ['Delivery times']),
    _Intent('howtobuy', ['buy', 'purchase', 'checkout', 'place an order', 'how do i order', 'how can i order', 'add to cart', 'cart', 'shop'],
        'To buy a product: open the Shop on the Home tab, tap a product, add it to your cart, then go to checkout. '
            'Choose delivery or a locker/kiosk, pay by card or EFT, and your order appears under My Orders. '
            'You earn 25 loyalty points for every order.',
        ['Delivery times', 'Loyalty points']),
    _Intent('reschedule', ['reschedule', 'change my booking', 'change my appointment', 'move my appointment', 'move my booking', 'different date', 'different time'],
        'To reschedule, open Profile > Refunds, find your upcoming appointment and tap Reschedule. '
            'A R100 rescheduling fee applies and the new time must be available.',
        ['Refunds', 'Booking policy']),
    _Intent('cancel', ['cancel', 'cancellation', 'cannot make it', "can't make it", 'unable to attend'],
        'To cancel, open Profile > Refunds, choose your appointment and tap Request refund. '
            'If you cancel yourself you receive a 50% refund. If the salon cancels, you receive a full refund.',
        ['Refunds', 'Reschedule']),
    _Intent('refund', ['refund', 'money back', 'reimburse', 'refunded'],
        'If you cancel a booking yourself you receive a 50% refund of what you paid. If the salon cancels, you receive a full refund. '
            'Approved refunds go back to your original payment method within 3-5 business days. Request one on the Refunds page.',
        ['Booking policy']),
    _Intent('booking', ['book', 'booking', 'appointment', 'policy', 'late', 'how do i book', 'how can i book'],
        'To book: open the Bookings tab, choose a service, pick a date and time, add a reference photo if you have one, and pay. '
            'Your booking is confirmed once payment is complete. If you cancel yourself you receive a 50% refund; if the salon cancels, a full refund. '
            'A R100 fee applies to reschedule.',
        ['Reschedule', 'Refunds']),
    _Intent('delivery', ['delivery', 'deliver', 'courier', 'shipping', 'how long', 'locker', 'kiosk', 'pudo', 'arrive', 'when will'],
        'We ship with The Courier Guy, to your door or to a locker/kiosk. Delivery usually takes 2-5 business days once your order has shipped. '
            'When it ships, the tracking number appears in the app under My Orders.',
        ['Track my order']),
    _Intent('loyalty', ['loyalty', 'points', 'reward', 'rewards', 'credit', 'qr', 'redeem', 'discount', 'scan'],
        'You earn 25 points for every order and 50 points for every completed booking (scan the QR code at the salon after your appointment). '
            'At 500 points you can redeem R100 credit, usable on a booking or a purchase.',
        ['Booking policy']),
    _Intent('products', ['product', 'products', 'press on', 'press-on', 'nails', 'size', 'sizes', 'stock', 'price', 'prices', 'item'],
        'You can browse all our products in the Shop, including sizes, prices and photos. If a product you want is not listed, '
            'tap "Speak to the owner" and we will help.',
        ['How do I buy a product?', 'Delivery times']),
    _Intent('payment', ['pay', 'payment', 'card', 'eft', 'secure', 'paystack'],
        'We accept card and EFT payments through Paystack. All payments are encrypted and processed through a secure gateway.'),
    _Intent('account', ['password', 'login', 'log in', 'profile', 'email', 'my details', 'account'],
        'To reset your password tap "Forgot Password?" on the login screen. To change your details go to Profile > Personal Information and tap Edit.'),
    _Intent('referral', ['referral', 'referrals', 'refer a friend', 'friend', 'invite'],
        'Our referral program is coming soon. Tap "Speak to the owner" if you would like to know more.'),
  ];

  static const _humanWords = [
    'human', 'real person', 'owner', 'agent', 'someone', 'speak to', 'talk to',
    'complaint', 'call me', 'speak with',
  ];

  static String _clean(String s) =>
      ' ${s.toLowerCase().replaceAll(RegExp(r"[^a-z0-9' ]"), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';

  static bool _has(String t, String phrase) => t.contains(' $phrase ') ||
      // allow simple plurals / endings: "book" matches "booking"
      (phrase.length >= 5 && t.contains(' $phrase'));

  static bool wantsHuman(String text) {
    final t = _clean(text);
    return _humanWords.any((w) => _has(t, w));
  }

  /// Matches [message] against the FAQ intents (best score wins; longer
  /// phrases score higher).
  static Future<BotReply> generateResponse(String message) async {
    final t = _clean(message);

    if (wantsHuman(message)) {
      return const BotReply(
        'No problem, I am connecting you to the owner now. She will reply here as soon as she can.',
        escalate: true,
      );
    }

    // Small talk
    if (RegExp(r"^ (hi|hello|hey|howzit|good (morning|afternoon|evening)) ").hasMatch(t) && t.trim().split(' ').length <= 3) {
      return const BotReply('Hi there! What can I help you with?', suggestions: topics);
    }
    if (RegExp(r'\b(thanks|thank you|thx|cheers)\b').hasMatch(t)) {
      return const BotReply("You're welcome! Is there anything else I can help with?",
          suggestions: ['Track my order', 'Booking policy', 'Speak to the owner']);
    }
    if (RegExp(r'^ (ok|okay|cool|great|nice|alright|k) $').hasMatch(t)) {
      return const BotReply('Great! Let me know if you need anything else.', suggestions: topics);
    }
    if (RegExp(r'\b(bye|goodbye|that is all|that s all)\b').hasMatch(t)) {
      return const BotReply('Thank you for chatting with Kotton Kandy. Have a lovely day!');
    }

    _Intent? best;
    var bestScore = 0;
    for (final i in _intents) {
      var score = 0;
      for (final k in i.keywords) {
        if (_has(t, k)) score += k.split(' ').length * 2 + 1; // phrases weigh more
      }
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }

    if (best == null) {
      return const BotReply(
        'Sorry, I am not sure about that one. Pick a topic below, or I can connect you to the owner.',
        suggestions: ['Booking policy', 'Delivery times', 'Track my order', 'Speak to the owner'],
      );
    }

    if (best.id == 'order') return _orderStatus();
    return BotReply(best.answer, suggestions: best.related);
  }

  static Future<BotReply> _orderStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const BotReply('Please log in to see your orders.');
    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: uid)
          .get();
      if (snap.docs.isEmpty) {
        return const BotReply('You have no orders yet. Browse the shop to place one!');
      }
      final docs = snap.docs.toList()
        ..sort((a, b) {
          final ta = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final tb = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
        });
      final d = docs.first.data();
      final status = (d['status'] ?? 'confirmed').toString().replaceAll('_', ' ');
      final tn = (d['trackingNumber'] ?? '').toString();
      final id = docs.first.id;
      return BotReply(
        'Your latest order (#${id.substring(0, id.length > 8 ? 8 : id.length)}) is: $status.'
            '${tn.isNotEmpty ? ' Tracking number: $tn.' : ' A tracking number will appear in My Orders once it ships.'}',
        suggestions: const ['Delivery times'],
      );
    } catch (_) {
      return const BotReply('I could not load your orders right now. You can also check Profile > My Orders.');
    }
  }
}