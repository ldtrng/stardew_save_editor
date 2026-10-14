import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ui/theme.dart';
import 'ad_ids.dart';
import 'ads_service.dart';

/// Inline native ad card (small template) for long lists.
class NativeListAd extends StatefulWidget {
  const NativeListAd({super.key});
  @override
  State<NativeListAd> createState() => _NativeListAdState();
}

class _NativeListAdState extends State<NativeListAd> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ad == null && AdsService.instance.showAds) _load();
  }

  void _load() {
    final p = context.farm;
    _ad = NativeAd(
      adUnitId: AdIds.native,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) => mounted ? setState(() => _loaded = true) : null,
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: p.panel,
        cornerRadius: 0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: p.grassDark,
          style: NativeTemplateFontStyle.bold,
          size: 14,
        ),
        primaryTextStyle: NativeTemplateTextStyle(textColor: p.text, style: NativeTemplateFontStyle.bold, size: 15),
        secondaryTextStyle: NativeTemplateTextStyle(textColor: p.textMuted, size: 13),
        tertiaryTextStyle: NativeTemplateTextStyle(textColor: p.textMuted, size: 12),
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded || !AdsService.instance.showAds) return const SizedBox.shrink();
    final p = context.farm;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(border: Border.all(color: p.outline, width: 2)),
      constraints: const BoxConstraints(minHeight: 90, maxHeight: 120),
      child: AdWidget(ad: ad),
    );
  }
}
