import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ui/theme.dart';
import 'ad_ids.dart';
import 'ads_service.dart';

/// Anchored adaptive banner; collapses to nothing when ads are off.
/// [collapsible] requests a collapsible banner (used on detail pages).
class AdBanner extends StatefulWidget {
  const AdBanner({super.key, this.collapsible = false});
  final bool collapsible;
  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  int? _width;

  @override
  void initState() {
    super.initState();
    AdsService.instance.addListener(_onAds);
  }

  void _onAds() {
    if (!mounted) return;
    if (!AdsService.instance.showAds) {
      _ad?.dispose();
      _ad = null;
      _loaded = false;
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    if (!AdsService.instance.showAds) return;
    final width = MediaQuery.of(context).size.width.truncate();
    if (_ad != null && _width == width) return;
    _width = width;
    // ignore: deprecated_member_use
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;
    _ad?.dispose();
    _ad = BannerAd(
      adUnitId: AdIds.banner,
      size: size,
      request: widget.collapsible ? const AdRequest(extras: {'collapsible': 'bottom'}) : const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => mounted ? setState(() => _loaded = true) : null,
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _ad = null;
            _width = null;
          });
          Future.delayed(const Duration(seconds: 45), () {
            if (mounted && _ad == null) _load();
          });
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    AdsService.instance.removeListener(_onAds);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!AdsService.instance.showAds) return const SizedBox.shrink();
    if (ad == null) {
      if (_width == null) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
      return const SizedBox.shrink();
    }
    if (!_loaded) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.farm.outline, width: 2))),
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: ad),
    );
  }
}
