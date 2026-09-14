import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Google's official TEST ad unit IDs (https://developers.google.com/admob/android/test-ads).
/// These are safe to ship in a prototype — they never serve real ads or earn
/// real revenue, and using them (instead of real IDs during development)
/// protects your AdMob account from invalid-traffic flags.
///
/// Before release: create an app in your own AdMob account, generate real
/// ad unit IDs there, and replace the values below. Also update the test
/// App IDs in AndroidManifest.xml and Info.plist.
class AdConfig {
  static bool get adsSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static String get bannerAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/6300978111';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2934735716';
    return '';
  }
}
