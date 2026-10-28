import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kDebugMode;

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
///   after importing progress, leaving an editor section, every Nth detail page
///   and every Nth tab switch. No time-based gap: pacing comes from the counters.
/// * App open: cold start (from the 2nd launch) and every return from the
///   background; never right after pickers/share sheets or another full-screen ad.
/// * Rewarded: bulk editor tools (unlocked for 1 h).
class AdsService extends ChangeNotifier with WidgetsBindingObserver {
  AdsService._();
  static final AdsService instance = AdsService._();

  static const _kLegacyAdFreeUntil = 'ads_ad_free_until';
  static const _kLaunches = 'ads_launch_count';
  static const toolsUnlock = Duration(hours: 1);
  static int get nativeEvery => RemoteSettings.getInt('ads_native_every', min: 12);

  bool _initialized = false;
  bool _canRequest = false;
  DateTime? _toolsUntil;
  int _launches = 0;
  DateTime? _lastInterstitial;
  DateTime? _lastAppOpen;
  DateTime? _pausedAt;
  int _externalDepth = 0;
  final Map<String, int> _since = {};
  bool _fullscreenShowing = false;
  bool _coldStartPending = true;

  /// False until the cold-start app open ad has been shown, failed or timed
  /// out; [StartupGate] keeps the home page hidden meanwhile.
  final ValueNotifier<bool> startupReady = ValueNotifier(false);

  InterstitialAd? _interstitial;
  bool _interstitialLoading = false;
  int _interstitialFailures = 0;
  AppOpenAd? _appOpen;
  bool _appOpenLoading = false;
  DateTime? _appOpenLoadedAt;
  RewardedAd? _rewardedTools;

  bool get showAds => _canRequest;
  bool get toolsUnlocked => _toolsUntil != null && DateTime.now().isBefore(_toolsUntil!);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLegacyAdFreeUntil);
    _launches = (prefs.getInt(_kLaunches) ?? 0) + 1;
    await prefs.setInt(_kLaunches, _launches);
    WidgetsBinding.instance.addObserver(this);
    // No app open ad on the very first launch after install: open the app at once.
    if (_launches <= 1) _finishStartup();
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
    final coldStartAd = RemoteSettings.getBool('ads_app_open_cold_start');
    if (_canRequest) {
      await MobileAds.instance.initialize();
      _loadInterstitial();
      _loadRewardedTools();
      if (_launches > 1) _loadAppOpen(coldStart: coldStartAd);
    }
    // Nothing to wait for: ads are off, first launch, or no cold-start ad wanted.
    if (!_canRequest || _launches <= 1 || !coldStartAd) _finishStartup();
    notifyListeners();
  }

  void _finishStartup() {
    _coldStartPending = false;
    if (!startupReady.value) startupReady.value = true;
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

  void _show(AdWithoutView ad, VoidCallback reload, {VoidCallback? onClosed, VoidCallback? onFinished}) {
    _fullscreenShowing = true;
    if (ad is InterstitialAd) {
      ad.fullScreenContentCallback = _fullScreenCallback<InterstitialAd>(reload, onClosed, onFinished);
      ad.show();
    } else if (ad is AppOpenAd) {
      ad.fullScreenContentCallback = _fullScreenCallback<AppOpenAd>(reload, onClosed, onFinished);
      ad.show();
    }
  }

  /// The callback's type parameter must match the ad's own type exactly; a
  /// `FullScreenContentCallback<AdWithoutView>` cast to it throws at runtime.
  FullScreenContentCallback<T> _fullScreenCallback<T extends AdWithoutView>(
          VoidCallback reload, VoidCallback? onClosed, VoidCallback? onFinished) =>
      FullScreenContentCallback<T>(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _fullscreenShowing = false;
          onClosed?.call();
          reload();
          onFinished?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, _) {
          ad.dispose();
          _fullscreenShowing = false;
          reload();
          onFinished?.call();
        },
      );

  // ---------------- interstitial ----------------
  void _loadInterstitial() {
    if (_interstitialLoading || _interstitial != null) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoading = false;
          _interstitialFailures = 0;
          _interstitial = ad;
        },
        onAdFailedToLoad: (_) {
          _interstitialLoading = false;
          _interstitial = null;
          // 30 s, 1 m, 2 m, 4 m, then every 5 m: a no-fill market must not
          // turn into a request every 30 s for the whole session.
          final wait = min(30 * (1 << min(_interstitialFailures++, 4)), 300);
          Future.delayed(Duration(seconds: wait), () => _canRequest ? _loadInterstitial() : null);
        },
      ),
    );
  }

  void _dbg(String message) {
    if (kDebugMode) debugPrint('[ads] $message');
  }

  /// Most recent full-screen ad of any kind (interstitial or app open).
  DateTime? get _lastFullscreen {
    final a = _lastInterstitial, b = _lastAppOpen;
    if (a == null || b == null) return a ?? b;
    return a.isAfter(b) ? a : b;
  }

  bool get _interstitialAllowed {
    if (!showAds || _fullscreenShowing || _externalDepth > 0) return false;
    if (_interstitial == null) {
      _dbg('interstitial skipped: not loaded');
      return false;
    }
    return true;
  }

  /// Flows that leave the app (pickers, share sheet) are only considered over
  /// 2 s after returning, so wait for that before trying to show an ad.
  Future<void> _afterExternal() async {
    for (var i = 0; i < 8 && _externalDepth > 0; i++) {
      await Future.delayed(Duration(milliseconds: 500));
    }
  }

  /// After a save was exported or written back.
  Future<void> onSaveExported(String method) async {
    Analytics.log('save_exported', {'method': method});
    if (!RemoteSettings.getBool('ads_interstitial_after_export')) return;
    await _afterExternal();
    await _showInterstitial();
  }

  /// After progress was imported into the tracker.
  Future<void> onProgressImported() async {
    Analytics.log('progress_imported');
    await _afterExternal();
    await _showInterstitial();
  }

  /// A user task just finished (save opened or restored from a backup, tracker
  /// backup shared or restored, farm created or switched): a natural pause.
  Future<void> onTaskDone(String task) async {
    Analytics.log('task_done', {'task': task});
    await _afterExternal();
    await _showInterstitial();
  }

  /// Leaving an editor section back to the hub.
  void onEditorSectionClosed() => _tick('section', RemoteSettings.getInt('ads_section_every', min: 1));

  /// Leaving a collection list (Fish, Museum, Cooking…) back to the hub.
  void onCollectionClosed() => _tick('collection', RemoteSettings.getInt('ads_collection_every', min: 1));

  /// Counts detail pages; an interstitial is due on every Nth (default 3rd).
  void onDetailViewed() => _tick('detail', RemoteSettings.getInt('ads_detail_every', min: 2));

  /// Counts bottom-tab switches; an interstitial is due on every Nth (default 4th).
  void onTabChanged() => _tick('tab', RemoteSettings.getInt('ads_tab_every', min: 2));

  /// Counts one navigation action. Once [every] actions have piled up the
  /// interstitial is *due*; if it can't show (not loaded yet, another ad on
  /// screen), the next action retries instead of waiting for another full
  /// cycle, so a blocked slot is not lost. Any interstitial that shows resets all counters.
  void _tick(String key, int every) {
    final n = _since[key] = (_since[key] ?? 0) + 1;
    if (n >= every) _showInterstitial();
  }

  Future<void> _showInterstitial() async {
    if (!_interstitialAllowed) return;
    final ad = _interstitial!;
    _interstitial = null;
    _since.clear();
    _show(ad, _loadInterstitial, onClosed: () => _lastInterstitial = DateTime.now());
  }

  // ---------------- app open ----------------
  /// [coldStart]: the app was just launched, so show the ad as soon as it
  /// arrives (the home page waits for it, up to 5 s) and open the app either way.
  void _loadAppOpen({bool coldStart = false}) {
    if (coldStart) Future.delayed(Duration(seconds: 5), _finishStartup);
    if (_appOpenLoading) return;
    _appOpenLoading = true;
    AppOpenAd.load(
      adUnitId: AdIds.appOpen,
      request: AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenLoading = false;
          _appOpen = ad;
          _appOpenLoadedAt = DateTime.now();
          if (coldStart && _coldStartPending) _maybeShowAppOpen(coldStart: true);
        },
        onAdFailedToLoad: (_) {
          _appOpenLoading = false;
          _appOpen = null;
          if (coldStart) _finishStartup();
        },
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      // Have one ready for the moment the user comes back.
      if (showAds && _launches > 1 && !_fullscreenShowing && _appOpen == null) _loadAppOpen();
    } else if (state == AppLifecycleState.resumed) {
      // Only a real return from the background (a pause came first).
      final wasPaused = _pausedAt != null;
      _pausedAt = null;
      _dbg('resumed (was in background: $wasPaused)');
      if (wasPaused && startupReady.value) _maybeShowAppOpen();
    }
  }

  void _maybeShowAppOpen({bool coldStart = false}) {
    if (!_tryShowAppOpen(coldStart)) {
      if (coldStart) _finishStartup();
    }
  }

  /// Returns true when an ad went on screen.
  bool _tryShowAppOpen(bool coldStart) {
    _coldStartPending = false;
    if (!showAds || _externalDepth > 0 || _fullscreenShowing) {
      _dbg('app open skipped: ads off / external flow / fullscreen ad showing');
      return false;
    }
    if (_launches <= 1) {
      _dbg('app open skipped: first launch');
      return false;
    }
    final now = DateTime.now();
    // Returning from an interstitial/rewarded video also fires a resume right
    // as it closes; a later return from the background is a real one.
    final last = _lastFullscreen;
    if (last != null && now.difference(last) < Duration(seconds: 5)) {
      _dbg('app open skipped: a full-screen ad just closed');
      return false;
    }
    final ad = _appOpen;
    if (ad == null) {
      _dbg('app open skipped: not loaded yet, loading');
      _loadAppOpen();
      return false;
    }
    if (_appOpenLoadedAt != null && now.difference(_appOpenLoadedAt!) > Duration(hours: 4)) {
      ad.dispose();
      _appOpen = null;
      _loadAppOpen();
      return false;
    }
    _appOpen = null;
    _show(ad, _loadAppOpen, onClosed: () => _lastAppOpen = DateTime.now(), onFinished: coldStart ? _finishStartup : null);
    return true;
  }

  // ---------------- rewarded ----------------
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
    final ad = _rewardedTools;
    if (ad == null) {
      _loadRewardedTools();
      _toolsUntil = DateTime.now().add(toolsUnlock);
      return true;
    }
    _rewardedTools = null;
    final earned = await _showRewarded(ad, _loadRewardedTools, () async {
      _toolsUntil = DateTime.now().add(toolsUnlock);
      Analytics.log('tools_unlocked');
    });
    return earned;
  }

  /// Small random jitter used by native slots so cards don't line up exactly.
  int nativeOffset(int seed) => 4 + Random(seed).nextInt(4);
}
