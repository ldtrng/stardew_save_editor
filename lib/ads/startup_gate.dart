import 'dart:async';

import 'package:flutter/material.dart';

import 'ads_service.dart';

/// Keeps the home page hidden (blank, same colour as the launch screen) until
/// the cold-start app open ad has been shown, failed or timed out, so the ad
/// appears before the home page. [AdsService.startupReady] opens it at once on
/// the first launch after install, when ads are off, or after 5 s without an
/// ad; the timer here is only a safety net if ads never finish initialising.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key, required this.child});
  final Widget child;
  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late final Timer _fallback;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    AdsService.instance.startupReady.addListener(_changed);
    _fallback = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _fallback.cancel();
    AdsService.instance.startupReady.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timedOut || AdsService.instance.startupReady.value) return widget.child;
    return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
  }
}
