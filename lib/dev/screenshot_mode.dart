import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/game_data.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/editor/backups_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tracker/bundles_tracker.dart';
import '../features/tracker/collections.dart';
import '../features/villagers/villager_detail.dart';
import '../l10n/l10n.dart';
import '../services/save_import.dart';
import '../state/editor_state.dart';
import '../state/settings_state.dart';
import '../state/tracker_state.dart';

/// Store-screenshot automation, compiled in only with --dart-define=SHOTS=true.
/// Loads demo data, then walks every language and screen, printing
/// `SHOT_READY lang_n` when a screen is ready; tools/store/capture.sh
/// grabs the frame with `adb screencap` before the next step.
const screenshotMode = bool.fromEnvironment('SHOTS');
const _langs = String.fromEnvironment('LANGS');

final shotNavigatorKey = GlobalKey<NavigatorState>();
final shotTabs = ValueNotifier<int>(0);

Future<void> runScreenshots(BuildContext context) async {
  final editor = context.read<EditorState>();
  final tracker = context.read<TrackerState>();
  await context.read<SettingsState>().setOnboarded();
  final bytes = File('/data/local/tmp/TestSave').readAsBytesSync();
  await editor.loadBytes(bytes, 'Sunny_284519337');
  final save = editor.save!;
  save.mainPlayer
    ..name = 'Ana'
    ..farmName = 'Sunny'
    ..money = 128450;
  SaveImporter(save).apply(tracker);
  tracker.renameFarm(tracker.farm, 'Sunny');
  tracker.setDate(0, 13, 2);
  final gd = GameData.i;
  tracker.setMany(Cat.fish, gd.fish.take(48).map((f) => f['id'].toString()), true);
  tracker.setMany(Cat.cooked, gd.cooking.take(37).map((f) => f['id'].toString()), true);
  tracker.setMany(Cat.crafted, gd.craftingRecipes.take(88).map((f) => f['key'].toString()), true);
  tracker.setMany(Cat.shipped, gd.shipping.take(121).map((f) => f['id'].toString()), true);
  tracker.setMany(Cat.museum, [...gd.artifacts.take(20), ...gd.minerals.take(31)].map((f) => f['id'].toString()), true);
  tracker.setMany(Cat.walnuts, gd.walnuts.take(23).map((f) => f['id'].toString()), true);
  tracker.setMany(Cat.stardrops, gd.stardrops.take(3).map((f) => f['id'].toString()), true);
  tracker.setMany(Cat.crops, gd.crops.take(24).map((c) => (c['harvest']?['id'] ?? c['gameId']).toString()), true);
  final items = <String>[];
  for (final room in bundleRooms(false).take(3)) {
    for (final b in (room['bundles'] as List).cast<Map>()) {
      final n = (b['items'] as List).length;
      for (var i = 0; i < n - 1; i++) {
        items.add('${b['key']}#$i');
      }
    }
  }
  tracker.setMany(Cat.bundleItems, items, true);
  for (final v in ['Abigail', 'Sebastian', 'Leah', 'Emily', 'Linus', 'Robin']) {
    tracker.setHearts(v, 6 + v.length % 4);
  }

  // Summary shown in the import screenshot, matching the demo progress.
  final summary = ImportSummary()
    ..add('Fish caught', tracker.count(Cat.fish))
    ..add('Items shipped', tracker.count(Cat.shipped))
    ..add('Dishes cooked', tracker.count(Cat.cooked))
    ..add('Items crafted', tracker.count(Cat.crafted))
    ..add('Museum donations', tracker.count(Cat.museum))
    ..add('Stardrops', tracker.count(Cat.stardrops))
    ..add('Villager hearts', 28)
    ..add('Bundle items', tracker.count(Cat.bundleItems));

  Future<void> ready(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 3000));
    debugPrint('SHOT_READY $name');
    // adb screencap of a 1080x2424 frame takes a few seconds.
    await Future<void>.delayed(const Duration(milliseconds: 6000));
  }

  NavigatorState nav() => shotNavigatorKey.currentState!;
  Route<void> route(Widget page) => PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
  final langs = _langs.isEmpty ? L10n.languages.keys.toList() : _langs.split(',');
  for (final code in langs) {
    await L10n.i.setLanguage(code);
    await Future<void>.delayed(const Duration(seconds: 2));
    shotTabs.value = 2;
    await ready('${code}_1');
    shotTabs.value = 3;
    await ready('${code}_2');
    nav().push(route(VillagerDetail(villager: GameData.i.villager('Sebastian')!)));
    await ready('${code}_3');
    nav().pop();
    nav().push(route(const SeasonCalendarScreen()));
    await ready('${code}_4');
    nav().pop();
    nav().push(route(const BundlesTrackerScreen()));
    await ready('${code}_5');
    nav().pop();
    nav().push(route(const BackupsScreen()));
    await ready('${code}_6');
    nav().pop();
    showImportSummary(shotNavigatorKey.currentContext!, summary);
    await ready('${code}_7');
    nav().pop();
    nav().push(route(const FishScreen()));
    await ready('${code}_8');
    nav().pop();
  }
  debugPrint('SHOT_DONE');
}
