import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase.dart';
import 'ad_ids.dart';

/// Ad placement policy (tuned for revenue while staying within AdMob policy).
/// Pacing values come from Remote Config (see [RemoteSettings.defaults]):
/// * Banner: anchored adaptive on tab, editor and detail screens (detail pages
///   can switch to a collapsible banner via Remote Config; off by default).
/// * Native: inline cards inside long lists (every [nativeEvery] rows).
/// * Interstitial: at natural breaks only — after exporting/writing a save,
///   after importing progress, leaving an editor section, every 4th detail page
///   and every 5th tab switch. ≥ 2 min apart, never in the first 45 s.
/// * App open: cold start (from the 2nd launch) and when returning after ≥ 30 s
///   in background; ≥ 3 h apart; never right after pickers/share sheets.
/// * Rewarded: bulk editor tools (unlocked for 1 h), and +4 h ad-free per video
///   (stacking up to 24 h).
class AdsService extends ChangeNotifier with WidgetsBindingObserver {
  AdsService._();
  static final AdsService instance = AdsService._();

  static const _kAdFreeUntil = 'ads_ad_free_until';
  static const _kLaunches = 'ads_launch_count';
  static Duration get _interstitialGap => RemoteSettings.seconds('ads_interstitial_gap_sec');
  static Duration get _sessionGrace => RemoteSettings.seconds('ads_session_grace_sec');
  static Duration get _appOpenGap => RemoteSettings.minutes('ads_app_open_gap_min');
  static const adFreePerVideo = Duration(hours: 4);
  static const adFreeMax = Duration(hours: 24);
  static const toolsUnlock = Duration(hours: 1);
  static int get nativeEvery => RemoteSettings.getInt('ads_native_every', min: 4);
  static bool get collapsibleBanner => RemoteSettings.getBool('ads_collapsible_banner');

  bool _initialized = false;
  bool _canRequest = false;
  DateTime? _adFreeUntil;
  DateTime? _toolsUntil;
  int _launches = 0;
  final DateTime _sessionStart = DateTime.now();
  DateTime? _lastInterstitial;
  DateTime? _lastAppOpen;
  DateTime? _pausedAt;
  int _externalDepth = 0;
  int _detailViews = 0;
  int _tabSwitches = 0;
  int _sectionExits = 0;
  bool _fullscreenShowing = false;
  bool _coldStartPending = true;

  InterstitialAd? _interstitial;
  AppOpenAd? _appOpen;
  DateTime? _appOpenLoadedAt;
  RewardedAd? _rewarded;
  RewardedAd? _rewardedTools;

  bool get adFree => _adFreeUntil != null && DateTime.now().isBefore(_adFreeUntil!);
  DateTime? get adFreeUntil => adFree ? _adFreeUntil : null;
  bool get showAds => _canRequest && !adFree;
  bool get rewardedReady => _rewarded != null;
  bool get toolsUnlocked => _toolsUntil != null && DateTime.now().isBefore(_toolsUntil!);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_kAdFreeUntil);
    _adFreeUntil = until == null ? null : DateTime.fromMillisecondsSinceEpoch(until);
    _launches = (prefs.getInt(_kLaunches) ?? 0) + 1;
    await prefs.setInt(_kLaunches, _launches);
    WidgetsBinding.instance.addObserver(this);
    await _gatherConsent();
  }

  Future<void> _gatherConsent() async {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        if (!done.isCompleted) done.complete();
      },
      (_) {
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future.timeout(Duration(seconds: 12), onTimeout: () {});
    _canRequest = await ConsentInformation.instance.canRequestAds();
    if (_canRequest) {
      await MobileAds.instance.initialize();
      _loadInterstitial();
      _loadRewarded();
      _loadRewardedTools();
      _loadAppOpen(showWhenLoaded: _launches > 1);
    }
    notifyListeners();
  }

  Future<bool> privacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  Future<void> showPrivacyOptions() async {
    await ConsentForm.showPrivacyOptionsForm((_) {});
    _canRequest = await ConsentInformation.instance.canRequestAds();
    notifyListeners();
  }

  /// Wrap calls that leave the app (pickers, share sheet) so returning from
  /// them is not treated as an app resume.
  Future<T> external<T>(Future<T> Function() fn) async {
    _externalDepth++;
    try {
      return await fn();
    } finally {
      Future.delayed(Duration(seconds: 2), () => _externalDepth--);
    }
  }

  void _show(AdWithoutView ad, VoidCallback reload, {VoidCallback? onClosed}) {
    _fullscreenShowing = true;
    final cb = FullScreenContentCallback<AdWithoutView>(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _fullscreenShowing = false;
        onClosed?.call();
        reload();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _fullscreenShowing = false;
        reload();
      },
    );
    if (ad is InterstitialAd) {
      ad.fullScreenContentCallback = cb as FullScreenContentCallback<InterstitialAd>?;
      ad.show();
    } else if (ad is AppOpenAd) {
      ad.fullScreenContentCallback = cb as FullScreenContentCallback<AppOpenAd>?;
      ad.show();
    }
  }

  // ---------------- interstitial ----------------
  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) {
          _interstitial = null;
          Future.delayed(Duration(seconds: 30), () => _canRequest ? _loadInterstitial() : null);
        },
      ),
    );
  }

  bool get _interstitialAllowed {
    if (!showAds || _fullscreenShowing || _interstitial == null || _externalDepth > 0) return false;
    final now = DateTime.now();
    if (now.difference(_sessionStart) < _sessionGrace) return false;
    final last = _lastInterstitial ?? _lastAppOpen;
    if (last != null && now.difference(last) < _interstitialGap) return false;
    return true;
  }

  /// After a save was exported or written back.
  Future<void> onSaveExported(String method) async {
    Analytics.log('save_exported', {'method': method});
    if (RemoteSettings.getBool('ads_interstitial_after_export')) await _showInterstitial();
  }

  /// After progress was imported into the tracker.
  Future<void> onProgressImported() async {
    Analytics.log('progress_imported');
    await _showInterstitial();
  }

  /// Leaving an editor section back to the hub.
  void onEditorSectionClosed() {
    _sectionExits++;
    if (_sectionExits % RemoteSettings.getInt('ads_section_every', min: 1) == 0) _showInterstitial();
  }

  /// Counts detail pages; shows an interstitial on every Nth (default 4th).
  void onDetailViewed() {
    _detailViews++;
    if (_detailViews % RemoteSettings.getInt('ads_detail_every', min: 2) == 0) _showInterstitial();
  }

  /// Counts bottom-tab switches; shows an interstitial on every Nth (default 5th).
  void onTabChanged() {
    _tabSwitches++;
    if (_tabSwitches % RemoteSettings.getInt('ads_tab_every', min: 2) == 0) _showInterstitial();
  }

  Future<void> _showInterstitial() async {
    if (!_interstitialAllowed) return;
    final ad = _interstitial!;
    _interstitial = null;
    _show(ad, _loadInterstitial, onClosed: () => _lastInterstitial = DateTime.now());
  }

  // ---------------- app open ----------------
  void _loadAppOpen({bool showWhenLoaded = false}) {
    final requestedAt = DateTime.now();
    AppOpenAd.load(
      adUnitId: AdIds.appOpen,
      request: AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpen = ad;
          _appOpenLoadedAt = DateTime.now();
          // Cold start: only if it arrived quickly, so it never interrupts use.
          if (showWhenLoaded && _coldStartPending && RemoteSettings.getBool('ads_app_open_cold_start') && DateTime.now().difference(requestedAt) < Duration(seconds: 5)) {
            _coldStartPending = false;
            _maybeShowAppOpen();
          }
        },
        onAdFailedToLoad: (_) => _appOpen = null,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      if (away >= RemoteSettings.seconds('ads_app_open_away_sec')) _maybeShowAppOpen();
    }
  }

  void _maybeShowAppOpen() {
    _coldStartPending = false;
    if (!showAds || _externalDepth > 0 || _fullscreenShowing || _launches <= 1) return;
    final now = DateTime.now();
    if (_lastAppOpen != null && now.difference(_lastAppOpen!) < _appOpenGap) return;
    final ad = _appOpen;
    if (ad == null) {
      _loadAppOpen();
      return;
    }
    if (_appOpenLoadedAt != null && now.difference(_appOpenLoadedAt!) > Duration(hours: 4)) {
      ad.dispose();
      _appOpen = null;
      _loadAppOpen();
      return;
    }
    _appOpen = null;
    _show(ad, _loadAppOpen, onClosed: () => _lastAppOpen = DateTime.now());
  }

  // ---------------- rewarded ----------------
  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          notifyListeners();
        },
        onAdFailedToLoad: (_) {
          _rewarded = null;
          notifyListeners();
        },
      ),
    );
  }

  void _loadRewardedTools() {
    RewardedAd.load(
      adUnitId: AdIds.rewardedTools,
      request: AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedTools = ad,
        onAdFailedToLoad: (_) => _rewardedTools = null,
      ),
    );
  }

  Future<bool> _showRewarded(RewardedAd ad, VoidCallback reload, Future<void> Function() onReward) {
    final earned = Completer<bool>();
    _fullscreenShowing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _fullscreenShowing = false;
        _lastInterstitial = DateTime.now(); // don't stack an interstitial right after
        reload();
        if (!earned.isCompleted) earned.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _fullscreenShowing = false;
        reload();
        if (!earned.isCompleted) earned.complete(false);
      },
    );
    ad.show(onUserEarnedReward: (_, _) async {
      await onReward();
      notifyListeners();
      if (!earned.isCompleted) earned.complete(true);
    });
    return earned.future;
  }

  /// +4 h without ads per video, capped at 24 h from now.
  Future<bool> watchForAdFree() async {
    final ad = _rewarded;
    if (ad == null) {
      if (_canRequest) _loadRewarded();
      return false;
    }
    _rewarded = null;
    return _showRewarded(ad, _loadRewarded, () async {
      final now = DateTime.now();
      final base = adFree ? _adFreeUntil! : now;
      final next = base.add(adFreePerVideo);
      final cap = now.add(adFreeMax);
      _adFreeUntil = next.isAfter(cap) ? cap : next;
      Analytics.log('ad_free_earned');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kAdFreeUntil, _adFreeUntil!.millisecondsSinceEpoch);
    });
  }

  /// Bulk editor tools: asks the user to watch a video once per hour. Returns
  /// true when the action may proceed (also when no ad is available, so the
  /// feature is never blocked by fill rate).
  Future<bool> unlockTools(BuildContext context, String feature) async {
    if (toolsUnlocked || !showAds) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(feature),
        content: Text(tr('Watch a short video to unlock bulk tools (max hearts, unlock all, complete bundles…) for 1 hour.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Not now'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Watch video'))),
        ],
      ),
    );
    Analytics.log('tools_unlock_prompt', {'accepted': ok == true ? 1 : 0});
    if (ok != true) return false;
    final ad = _rewardedTools ?? _rewarded;
    if (ad == null) {
      _loadRewardedTools();
      _toolsUntil = DateTime.now().add(toolsUnlock);
      return true;
    }
    if (identical(ad, _rewardedTools)) {
      _rewardedTools = null;
    } else {
      _rewarded = null;
    }
    final earned = await _showRewarded(ad, identical(ad, _rewarded) ? _loadRewarded : _loadRewardedTools, () async {
      _toolsUntil = DateTime.now().add(toolsUnlock);
      Analytics.log('tools_unlocked');
    });
    return earned;
  }

  /// Small random jitter used by native slots so cards don't line up exactly.
  int nativeOffset(int seed) => 4 + Random(seed).nextInt(4);
}
