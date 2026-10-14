import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Firebase bootstrap. Everything here is optional: when Firebase is not
/// initialized (tests, screenshot mode, init failure) the app runs on defaults.
class AppFirebase {
  static bool ready = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
      ready = true;
      await Analytics.instance?.setAnalyticsCollectionEnabled(!kDebugMode);
      await RemoteSettings.init();
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }
  }
}

/// Thin wrapper over Firebase Analytics; no-ops when Firebase is unavailable.
/// Events carry no personal data: only feature names, counts and languages.
class Analytics {
  static FirebaseAnalytics? get instance => AppFirebase.ready ? FirebaseAnalytics.instance : null;

  static void log(String name, [Map<String, Object>? params]) {
    instance?.logEvent(name: name, parameters: params).catchError((_) {});
  }

  static void screen(String name) {
    instance?.logScreenView(screenName: name).catchError((_) {});
  }

  static void setLanguage(String code) {
    instance?.setUserProperty(name: 'app_language', value: code).catchError((_) {});
  }
}

/// Remote Config values with in-app defaults. Ad pacing lives here so it can
/// be tuned per audience without an app update.
class RemoteSettings {
  static const defaults = <String, Object>{
    'ads_interstitial_gap_sec': 120,
    'ads_session_grace_sec': 45,
    'ads_app_open_gap_min': 180,
    'ads_app_open_away_sec': 30,
    'ads_app_open_cold_start': true,
    'ads_interstitial_after_export': true,
    'ads_section_every': 2,
    'ads_detail_every': 4,
    'ads_tab_every': 5,
    'ads_native_every': 12,
    // Off: the expanded overlay was seen outliving its page on Android,
    // which risks accidental clicks. Re-enable remotely after device checks.
    'ads_collapsible_banner': false,
    'review_min_moments': 3,
  };

  static FirebaseRemoteConfig? get _rc => AppFirebase.ready ? FirebaseRemoteConfig.instance : null;

  static Future<void> init() async {
    final rc = _rc;
    if (rc == null) return;
    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: kDebugMode ? const Duration(minutes: 1) : const Duration(hours: 6),
    ));
    await rc.setDefaults(defaults);
    // Use the values cached from the last session now; fetch new ones in the
    // background so start-up never waits on the network.
    await rc.activate();
    rc.fetch().then((_) => rc.activate()).catchError((_) => false);
  }

  /// [min] guards counters used as divisors against bad remote values.
  static int getInt(String key, {int min = 0}) {
    final v = _rc?.getInt(key) ?? defaults[key] as int;
    return v < min ? min : v;
  }

  static bool getBool(String key) => _rc?.getBool(key) ?? defaults[key] as bool;

  static Duration seconds(String key) => Duration(seconds: getInt(key));
  static Duration minutes(String key) => Duration(minutes: getInt(key));
}
