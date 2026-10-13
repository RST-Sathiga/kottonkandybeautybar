import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Makes sure every signed-in client has a profile in `users/{uid}`, so the
/// admin Users page can list them with name, email and photo.
/// Never touches points or credit. Safe to call on every login.
Future<void> syncUserProfile(User user) async {
  try {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();
    final data = snap.data() ?? <String, dynamic>{};

    final update = <String, dynamic>{'uid': user.uid};

    if ((user.email ?? '').isNotEmpty && data['email'] != user.email) {
      update['email'] = user.email;
    }
    final name = (user.displayName ?? '').trim();
    if (name.isNotEmpty && (data['name'] ?? '').toString().isEmpty) {
      update['name'] = name;
    }
    final photo = user.photoURL ?? '';
    if (photo.isNotEmpty && (data['photoUrl'] ?? '').toString().isEmpty) {
      update['photoUrl'] = photo;
    }
    if (!snap.exists) {
      update['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(update, SetOptions(merge: true));
  } catch (_) {
    // Never block the app if this fails.
  }
}