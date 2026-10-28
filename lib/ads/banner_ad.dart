import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ui/theme.dart';
import 'ad_ids.dart';
import 'ad_style.dart';
import 'ads_service.dart';

/// One anchored adaptive banner under the whole navigator (installed through
/// `MaterialApp.builder`), so every page shows it without per-screen widgets and
/// without a new ad request each time a page opens. Collapses to nothing while
/// no ad is loaded or ads are off, and steps aside while the keyboard is open.
class AdBannerHost extends StatefulWidget {
  const AdBannerHost({super.key, required this.child});
  final Widget child;
  @override
  State<AdBannerHost> createState() => _AdBannerHostState();
}

class _AdBannerHostState extends State<AdBannerHost> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _loading = false;
  int? _width;
  int _failures = 0;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    AdsService.instance.addListener(_onAds);
    AdsService.instance.startupReady.addListener(_onAds);
  }

  void _onAds() {
    if (!mounted) return;
    if (!AdsService.instance.showAds) {
      _ad?.dispose();
      _ad = null;
      _loaded = false;
    } else {
      _load();
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !AdsService.instance.showAds) return;
    // Wait out the back-off after a failed request instead of hammering the
    // ad server (every rebuild or tab switch used to fire a new request).
    if (_retry?.isActive ?? false) return;
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (_ad != null && _width == width) return;
    _loading = true;
    // ignore: deprecated_member_use
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    _loading = false;
    if (!mounted) return;
    if (size == null) return _scheduleRetry();
    _width = width;
    _loaded = false;
    _ad?.dispose();
    final ad = BannerAd(
      adUnitId: AdIds.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (a) {
          if (!mounted || !identical(a, _ad)) return;
          _failures = 0;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (a, _) {
          a.dispose();
          if (!mounted || !identical(a, _ad)) return;
          setState(() {
            _ad = null;
            _loaded = false;
            _width = null;
          });
          _scheduleRetry();
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  /// 30 s, 1 m, 2 m, 4 m, then every 5 m while the banner stays on screen.
  void _scheduleRetry() {
    _failures++;
    final seconds = min(30 * (1 << min(_failures - 1, 4)), 300);
    _retry?.cancel();
    _retry = Timer(Duration(seconds: seconds), () {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _retry?.cancel();
    AdsService.instance.removeListener(_onAds);
    AdsService.instance.startupReady.removeListener(_onAds);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    final mq = MediaQuery.of(context);
    // Not before the home page is revealed (the cold-start app open ad comes first).
    final shown = ad != null && _loaded && AdsService.instance.showAds && AdsService.instance.startupReady.value;
    final keyboard = mq.viewInsets.bottom > 0;
    final p = context.farm;
    // The banner takes over the bottom system inset, so pages above it must not
    // pad for it again.
    final inset = mq.padding.bottom;
    final pageMedia = (!shown || keyboard) ? mq : mq.copyWith(padding: mq.padding.copyWith(bottom: 0), viewPadding: mq.viewPadding.copyWith(bottom: 0));
    // The tree shape never changes, so the navigator keeps its state when the
    // ad appears or goes away.
    return Column(children: [
      Expanded(child: MediaQuery(data: pageMedia, child: widget.child)),
      if (shown)
        // Kept in the tree (just not laid out) while the keyboard is up, so the
        // loaded ad survives and no new request is made.
        Visibility(
          visible: !keyboard,
          maintainState: true,
          child: Container(
            decoration: BoxDecoration(color: adSurface(p), border: Border(top: BorderSide(color: p.outline, width: 2))),
            width: double.infinity,
            height: ad.size.height.toDouble() + 2 + inset,
            padding: EdgeInsets.only(bottom: inset),
            alignment: Alignment.center,
            child: SizedBox(width: ad.size.width.toDouble(), height: ad.size.height.toDouble(), child: AdWidget(ad: ad)),
          ),
        ),
    ]);
  }
}
