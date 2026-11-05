import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Google Maps Platform settings.
///
/// 1. Paste your API key below (Google Cloud Console > APIs & Services > Credentials).
/// 2. Restrict the key to your app (Android package + SHA-1, iOS bundle id) and to
///    these APIs only: Maps SDK for Android, Maps SDK for iOS, Places API (New).
/// 3. Because the address search calls Google over the web (REST), a key that is
///    restricted to your Android/iOS app only works if the app identifies itself.
///    Fill in the three values below so the app can send them.
class MapsConfig {
  MapsConfig._();

  static const String apiKey = 'PASTE_YOUR_GOOGLE_MAPS_API_KEY';

  /// Your Android applicationId (android/app/build.gradle).
  static const String androidPackage = 'com.kottonkandy.app';

  /// SHA-1 of the key your app is signed with, uppercase hex, no colons.
  /// Debug key: run `./gradlew signingReport` in the android folder.
  static const String androidSha1 = '';

  /// Your iOS bundle identifier (leave empty if you only build for Android).
  static const String iosBundleId = '';

  static bool get hasKey => apiKey.isNotEmpty && !apiKey.startsWith('PASTE');

  /// Headers that prove the request comes from your app (needed for a restricted key).
  static Map<String, String> get restrictionHeaders {
    if (kIsWeb) return {};
    try {
      if (Platform.isAndroid) {
        return {
          if (androidPackage.isNotEmpty) 'X-Android-Package': androidPackage,
          if (androidSha1.isNotEmpty) 'X-Android-Cert': androidSha1,
        };
      }
      if (Platform.isIOS && iosBundleId.isNotEmpty) {
        return {'X-Ios-Bundle-Identifier': iosBundleId};
      }
    } catch (_) {}
    return {};
  }
}
