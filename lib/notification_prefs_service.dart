import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Reads and writes the client's notification preferences in Firestore
/// (users/{uid}.prefs) and keeps this device's FCM token registered.
///
/// The server (Cloud Functions) reads the same fields before sending anything,
/// and the admin app can read them to see who has opted in.
class NotificationPrefsService {
  NotificationPrefsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseMessaging? messaging,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _fcm = messaging ?? FirebaseMessaging.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseMessaging _fcm;

  StreamSubscription<String>? _tokenRefreshSub;

  static const keyPush = 'push';
  static const keyEmail = 'email';
  static const keyPromotions = 'promotions';

  DocumentReference<Map<String, dynamic>> get _userRef =>
      _db.collection('users').doc(_auth.currentUser!.uid);

  /// Live preferences. Defaults: push on, email on, promotions OFF (opt-in).
  Stream<Map<String, bool>> watchPrefs() {
    return _userRef.snapshots().map((snap) {
      final p = (snap.data()?['prefs'] ?? <String, dynamic>{}) as Map<String, dynamic>;
      return {
        keyPush: p[keyPush] as bool? ?? true,
        keyEmail: p[keyEmail] as bool? ?? true,
        keyPromotions: p[keyPromotions] as bool? ?? false,
      };
    });
  }

  /// Returns false if the change could not be applied
  /// (e.g. the user denied the system notification permission).
  Future<bool> setPref(String key, bool value) async {
    if (key == keyPush && value) {
      final settings = await _fcm.requestPermission();
      final denied = settings.authorizationStatus == AuthorizationStatus.denied;
      if (denied) return false;
      await registerToken();
    }

    await _userRef.set({
      'prefs': {key: value},
      'prefsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return true;
  }

  /// Call after login (and when push is switched on).
  Future<void> registerToken() async {
    final token = await _fcm.getToken();
    if (token != null) await _saveToken(token);

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _fcm.onTokenRefresh.listen(_saveToken);
  }

  Future<void> _saveToken(String token) {
    return _userRef.set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  /// Call BEFORE signing out, so the next person on this phone
  /// does not receive the previous user's notifications.
  Future<void> unregisterToken() async {
    await _tokenRefreshSub?.cancel();
    final token = await _fcm.getToken();
    if (token != null && _auth.currentUser != null) {
      await _userRef.update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    }
    await _fcm.deleteToken();
  }

  /// Call BEFORE deleting the user document / auth account.
  /// Removes this device's token and the user's notification inbox.
  Future<void> clearNotificationData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await unregisterToken();
    } catch (_) {}
    try {
      final inbox = await _userRef.collection('notifications').get();
      for (var i = 0; i < inbox.docs.length; i += 400) {
        final batch = _db.batch();
        for (final d in inbox.docs.skip(i).take(400)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    } catch (_) {}
  }
}