import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ui/theme.dart';
import 'ad_ids.dart';
import 'ad_style.dart';
import 'ads_service.dart';

/// The one native ad of the whole app. Every native slot (see
/// [NativeListAd]) shows this same [NativeAd], but only one slot may own it at a
/// time: a native ad's platform view has a single parent, so two [AdWidget]s on
/// the same ad would clash. Slots that don't own it render nothing.
///
/// A new ad is requested only when the current one has been displayed
/// [maxDisplays] times or is [maxAge] old, and only at the moment a slot takes
/// ownership, so an ad that is on screen is never swapped under the user.
class NativeAdPool extends ChangeNotifier {
  NativeAdPool._() {
    AdsService.instance.addListener(_onAdsChanged);
  }
  static final NativeAdPool instance = NativeAdPool._();

  static const maxDisplays = 10;
  static const maxAge = Duration(minutes: 7);

  /// Time the previous owner's platform view gets to detach before the next slot
  /// attaches the same ad.
  static const _handover = Duration(milliseconds: 300);

  NativeAd? _ad; // requested: loading or loaded
  bool _loaded = false;
  DateTime? _loadedAt;
  int _displays = 0;
  bool _counted = false;
  int _style = 0;

  Object? _owner;
  DateTime? _releasedAt;
  bool Function()? _onScreen;
  FarmPalette? _palette;
  Timer? _countTimer;
  Timer? _retry;
  int _failures = 0;

  /// The ad for [slot]: only its owner gets one, and only once it has loaded.
  NativeAd? adFor(Object slot) => (_loaded && identical(_owner, slot)) ? _ad : null;

  bool get _stale => _loaded && (_displays >= maxDisplays || DateTime.now().difference(_loadedAt!) >= maxAge);

  /// Asks to show the ad in [slot]. [onScreen] tells whether the slot is really
  /// in view (it is built in a list's cache area before it is visible).
  /// Idempotent; does nothing while another slot owns the ad.
  void claim(Object slot, FarmPalette palette, bool Function() onScreen) {
    if (!AdsService.instance.showAds) return;
    if (_owner != null && !identical(_owner, slot)) return;
    // Let the previous owner's view detach first; release() notifies when due.
    if (_owner == null && _releasedAt != null && DateTime.now().difference(_releasedAt!) < _handover) return;
    _palette = palette;
    _onScreen = onScreen;
    if (!identical(_owner, slot)) {
      _owner = slot;
      _counted = false;
      // The new owner is not attached yet, so this is the safe moment to renew.
      if (_loaded && (_stale || _styleOf(palette) != _style)) _discard();
      _armCount();
    }
    _load();
  }

  void release(Object slot) {
    if (!identical(_owner, slot)) return;
    _owner = null;
    _releasedAt = DateTime.now();
    _countTimer?.cancel();
    // Not synchronously: release runs while the tree is being torn down.
    Timer(_handover, notifyListeners);
  }

  static int _styleOf(FarmPalette p) => Object.hash(adSurface(p).toARGB32(), p.text.toARGB32(), p.textMuted.toARGB32(), p.wood.toARGB32());

  void _load() {
    final p = _palette;
    if (_ad != null || p == null || (_retry?.isActive ?? false)) return;
    _style = _styleOf(p);
    final ad = NativeAd(
      adUnitId: AdIds.native,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (a) {
          if (!identical(a, _ad)) return;
          _loaded = true;
          _loadedAt = DateTime.now();
          _displays = 0;
          _failures = 0;
          _armCount();
          notifyListeners();
        },
        onAdFailedToLoad: (a, _) {
          a.dispose();
          if (!identical(a, _ad)) return;
          _ad = null;
          _loaded = false;
          // 30 s, 1 m, 2 m, 4 m, then every 5 m while some slot wants the ad.
          final wait = min(30 * (1 << min(_failures++, 4)), 300);
          _retry = Timer(Duration(seconds: wait), () {
            if (_owner != null) _load();
          });
        },
      ),
      // Layout lives in android/.../SvNativeAdFactory.kt (fixed dp sizes); the
      // view is built when the ad loads, so the colours are fixed per ad.
      factoryId: 'svMedium',
      customOptions: {
        'bg': adSurface(p).toARGB32(),
        'text': p.text.toARGB32(),
        'muted': p.textMuted.toARGB32(),
        'cta': p.wood.toARGB32(),
        'ctaText': Colors.white.toARGB32(),
      },
    );
    _ad = ad;
    ad.load();
  }

  void _discard() {
    _countTimer?.cancel();
    _ad?.dispose();
    _ad = null;
    _loaded = false;
    _displays = 0;
  }

  /// Counts one display once the owner has really been in view (and the app in
  /// the foreground) for a second.
  void _armCount() {
    _countTimer?.cancel();
    final owner = _owner;
    if (owner == null || !_loaded || _counted) return;
    _countTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!identical(_owner, owner) || !_loaded) return t.cancel();
      final state = WidgetsBinding.instance.lifecycleState;
      if ((state == null || state == AppLifecycleState.resumed) && (_onScreen?.call() ?? false)) {
        _displays++;
        _counted = true;
        t.cancel();
      }
    });
  }

  void _onAdsChanged() {
    if (!AdsService.instance.showAds) {
      _retry?.cancel();
      _discard();
    }
    notifyListeners();
  }
}
