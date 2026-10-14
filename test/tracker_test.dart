import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stardew_save_editor/data/game_data.dart';
import 'package:stardew_save_editor/features/calendar/calendar_screen.dart';
import 'package:stardew_save_editor/features/villagers/villager_detail.dart';
import 'package:stardew_save_editor/save/items.dart';
import 'package:stardew_save_editor/save/save_file.dart';
import 'package:stardew_save_editor/services/save_import.dart';
import 'package:stardew_save_editor/state/tracker_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ItemDb.load();
    await GameData.load();
  });

  test('game data loads', () {
    final gd = GameData.i;
    expect(gd.fish.length, greaterThan(60));
    expect(gd.socialVillagers.length, greaterThanOrEqualTo(30));
    expect(gd.cooking.length, 81);
    expect(gd.walnuts.fold<int>(0, (s, w) => s + (w['quantity'] as num).toInt()), 130);
  });

  test('every referenced tracker image exists', () {
    final missing = <String>[];
    void check(Object? img) {
      final p = imagePath(img);
      if (p != null && !File(p).existsSync()) missing.add(p);
    }

    for (final list in [GameData.i.fish, GameData.i.crops, GameData.i.items, GameData.i.villagers, GameData.i.walnuts, GameData.i.wearables]) {
      for (final j in list) {
        check(j['image']);
      }
    }
    expect(missing, isEmpty);
  });

  test('importer marks progress from a save', () async {
    final save = SaveFile.parse(File('test/fixtures/TestSave').readAsBytesSync(), 'TestSave');
    final tracker = TrackerState();
    await tracker.load();
    final summary = SaveImporter(save).apply(tracker);
    expect(tracker.farm.name, save.mainPlayer.farmName);
    expect(tracker.farm.day, save.dayOfMonth);
    expect(summary.counts['Villager hearts'], greaterThan(0));
    // TestSave has caught fish and shipped items.
    expect(tracker.count(Cat.fish), greaterThan(0));
    expect(tracker.count(Cat.shipped), greaterThan(0));
  });

  test('schedule resolver picks a schedule for every villager', () {
    final none = <String>[];
    for (final v in GameData.i.socialVillagers) {
      final name = v['name'] as String;
      final r = ScheduleResolver(name);
      if (r.entries.isEmpty) continue;
      final s = r.resolve(season: 0, day: 3, rain: false, bus: true, married: false, hearts: 0, friendsAbove: {});
      if (s == null) none.add(name);
    }
    expect(none, isEmpty);
  });

  test('calendar events', () {
    // Egg Festival is Spring 13.
    expect(DayEvents(0, 13, 1).festivals.join(), contains('Egg'));
    // Abigail's birthday is Fall 13.
    expect(DayEvents(2, 13, 1).birthdays.map((v) => v['name']), contains('Abigail'));
  });

  test('notes recurrence', () {
    final n = FarmNote(id: '1', text: 'x', season: 0, day: 3, year: 1, frequency: NoteFrequency.weekly);
    expect(n.occursOn(1, 0, 10), isTrue);
    expect(n.occursOn(1, 0, 11), isFalse);
    expect(n.occursOn(1, 0, 2), isFalse);
    final s = FarmNote(id: '2', text: 'x', season: 0, day: 5, year: 1, frequency: NoteFrequency.seasonly);
    expect(s.occursOn(1, 2, 5), isTrue);
  });
}
