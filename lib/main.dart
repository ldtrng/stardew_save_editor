import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'ads/ads_service.dart';
import 'app_shell.dart';
import 'data/game_data.dart';
import 'dev/screenshot_mode.dart';
import 'l10n/l10n.dart';
import 'save/items.dart';
import 'save/qi_quests.dart';
import 'services/firebase.dart';
import 'state/editor_state.dart';
import 'state/settings_state.dart';
import 'state/tracker_state.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase first so Remote Config ad pacing is active before ads load.
  if (!screenshotMode) await AppFirebase.init();
  runApp(await bootstrap());
  if (!screenshotMode) {
    Analytics.setLanguage(L10n.i.code);
    AdsService.instance.init();
  }
}

/// Loads data and returns the app with its providers (also used by the
/// screenshot integration test, which skips ads).
Future<Widget> bootstrap() async {
  final settings = SettingsState();
  await Future.wait([
    L10n.i.load(),
    settings.load(),
    ItemDb.load(),
    QiQuestTemplate.load(),
    GameData.load(),
  ]);
  final tracker = TrackerState();
  await tracker.load();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider(create: (_) => EditorState()),
      ChangeNotifierProvider.value(value: tracker),
      ChangeNotifierProvider.value(value: AdsService.instance),
      ChangeNotifierProvider.value(value: L10n.i),
    ],
    child: const ValleyApp(),
  );
}

class ValleyApp extends StatelessWidget {
  const ValleyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final l10n = context.watch<L10n>();
    return MaterialApp(
      title: 'SV Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: settings.themeMode,
      locale: l10n.locale,
      supportedLocales: [for (final c in L10n.languages.keys) L10n.i.localeFor(c)],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Rebuild everything when the language changes so every tr() re-runs.
      navigatorKey: screenshotMode ? shotNavigatorKey : null,
      navigatorObservers: Analytics.observers,
      home: AppShell(key: ValueKey(l10n.code)),
    );
  }
}
