import 'package:flutter/foundation.dart';

/// AdMob ids. Debug builds always use Google's public test units; release
/// builds use the production units.
class AdIds {
  // AdMob app: ca-app-pub-2822978318382771~7313207678
  static const _prodBanner = 'ca-app-pub-2822978318382771/4186060461';
  static const _prodInterstitial = 'ca-app-pub-2822978318382771/9005388281';
  static const _prodAppOpen = 'ca-app-pub-2822978318382771/6038198184';
  static const _prodNative = 'ca-app-pub-2822978318382771/4774886277';
  static const _prodRewardedTools = 'ca-app-pub-2822978318382771/5758076719';

  static const _testBanner = 'ca-app-pub-3940256099942544/9214589741';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testAppOpen = 'ca-app-pub-3940256099942544/9257395921';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const _testNative = 'ca-app-pub-3940256099942544/2247696110';

  static String _pick(String prod, String test) => (kReleaseMode && prod.isNotEmpty) ? prod : test;

  static String get banner => _pick(_prodBanner, _testBanner);
  static String get interstitial => _pick(_prodInterstitial, _testInterstitial);
  static String get appOpen => _pick(_prodAppOpen, _testAppOpen);
  static String get native => _pick(_prodNative, _testNative);
  static String get rewardedTools => _pick(_prodRewardedTools, _testRewarded);
}
