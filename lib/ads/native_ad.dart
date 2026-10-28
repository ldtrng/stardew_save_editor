import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ui/theme.dart';
import 'ad_style.dart';
import 'ads_service.dart';
import 'native_ad_pool.dart';

/// Slot for the app's single native ad ([NativeAdPool]). It claims the ad while
/// its page is the visible one and renders nothing when it can't have it (ad not
/// loaded yet, or another slot owns it), so a page or list can hold several
/// slots and at most one shows the ad.
///
/// In lists, keep slots at least a screen and a half apart (see
/// [AdsService.nativeEvery]) so the next slot is rarely built while the owner is
/// still on screen.
class NativeListAd extends StatefulWidget {
  final EdgeInsetsGeometry? margin;

  const NativeListAd({super.key, this.margin});

  @override
  State<NativeListAd> createState() => _NativeListAdState();
}

class _NativeListAdState extends State<NativeListAd> {
  final _pool = NativeAdPool.instance;
  bool _routeVisible = true;
  Size _screen = Size.zero;
  late FarmPalette _palette;

  @override
  void initState() {
    super.initState();
    _pool.addListener(_onPool);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _palette = context.farm;
    _screen = MediaQuery.sizeOf(context);
    // Pages under another route are built but have their tickers off.
    _routeVisible = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  void _onPool() {
    if (!mounted) return;
    _sync();
    setState(() {});
  }

  void _sync() {
    if (_routeVisible) {
      _pool.claim(this, _palette, _isOnScreen);
    } else {
      _pool.release(this);
    }
  }

  /// At least half of the card is inside the screen.
  bool _isOnScreen() {
    final box = context.findRenderObject();
    if (!mounted || box is! RenderBox || !box.attached || !box.hasSize || box.size.isEmpty) return false;
    final r = (box.localToGlobal(Offset.zero) & box.size).intersect(Offset.zero & _screen);
    return !r.isEmpty && r.height >= box.size.height / 2;
  }

  @override
  void dispose() {
    _pool.removeListener(_onPool);
    _pool.release(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _pool.adFor(this);
    if (ad == null || !AdsService.instance.showAds) return const SizedBox.shrink();
    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      // Same colour as the template so any slack below its content blends in.
      color: adSurface(context.farm),
      child: LayoutBuilder(
        builder: (context, box) => SizedBox(height: _height(box.maxWidth), child: AdWidget(ad: ad)),
      ),
    );
  }

  /// Height mirrors SvNativeAdFactory.kt: a 1.91:1 media area plus
  /// [_chrome] of fixed-size rows (the media view absorbs any rounding difference).
  static const _chrome = 146.0;
  double _height(double width) => width / 1.91 + _chrome;
}

/// Same slot, named for pages that show a single ad outside a data list.
class NativeMediaAd extends NativeListAd {
  const NativeMediaAd({super.key, super.margin});
}
