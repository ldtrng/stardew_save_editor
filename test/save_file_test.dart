import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stardew_save_editor/save/farmer.dart';
import 'package:stardew_save_editor/save/items.dart';
import 'package:stardew_save_editor/save/qi_quests.dart';
import 'package:stardew_save_editor/save/save_file.dart';
import 'package:stardew_save_editor/save/xml_ext.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SaveFile save;

  setUpAll(() async {
    await ItemDb.load();
    await QiQuestTemplate.load();
  });

  setUp(() {
    save = SaveFile.parse(File('test/fixtures/TestSave').readAsBytesSync(), 'TestSave');
  });

  test('parses players and basic fields', () {
    expect(save.mainPlayer.name, 'Test');
    expect(save.gameVersion, startsWith('1.6'));
    expect(save.locations, isNotEmpty);
  });

  test('round-trip without edits keeps the document intact', () {
    final bytes = save.encode();
    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    final again = SaveFile.parse(bytes, 'x');
    expect(again.doc.toXmlString(), save.doc.toXmlString());
  });

  test('edits persist through encode', () {
    save.mainPlayer.money = 123456;
    save.mainPlayer.setExperience('farming', 15000);
    save.goldenWalnuts = 42;
    final again = SaveFile.parse(save.encode(), 'x');
    expect(again.mainPlayer.money, 123456);
    expect(again.mainPlayer.level('farming'), 10);
    expect(again.mainPlayer.el.integer('farmingLevel'), 10);
    expect(again.goldenWalnuts, 42);
  });

  test('inventory items resolve metadata', () {
    final p = save.mainPlayer;
    var resolved = 0, total = 0;
    for (var i = 0; i < p.itemSlots.length; i++) {
      final item = p.itemAt(i);
      if (item == null) continue;
      total++;
      if (item.info != null) resolved++;
    }
    expect(total, greaterThan(0));
    expect(resolved, total);
    expect(p.equipment('shirtItem')?.info, isNotNull);
  });

  test('item factory creates items in slots', () {
    final p = save.mainPlayer;
    final empty = List.generate(p.itemSlots.length, (i) => i).firstWhere((i) => p.itemAt(i) == null);
    p.setItemAt(empty, ItemFactory.create(ItemDb.instance.byName['Prismatic Shard']!, stack: 5));
    p.setEquipment('hat', ItemFactory.create(ItemDb.instance.byName['Cowboy Hat']!, tag: 'hat'));
    final again = SaveFile.parse(save.encode(), 'x');
    final item = again.mainPlayer.itemAt(empty)!;
    expect(item.name, 'Prismatic Shard');
    expect(item.stack, 5);
    expect(again.mainPlayer.equipment('hat')?.name, 'Cowboy Hat');
    expect(again.mainPlayer.el.child('hat')?.getAttribute('xsi:type'), isNull);
  });

  test('sprites exist for most items', () {
    final missing = ItemDb.instance.all.where((i) => i.sprite == null).map((i) => '${i.type}:${i.name}').toList();
    expect(missing.length, lessThan(40), reason: missing.take(40).join(', '));
  });

  test('community center bundles load and side effects apply', () {
    final cc = save.communityCenter()!;
    expect(cc.bundles.length, greaterThan(20));
    for (final b in cc.byRoom.values.first) {
      b.setCompleted(true);
    }
    cc.applySideEffects();
    expect(save.mainPlayer.hasMail('ccPantry'), isTrue);
  });

  test('chests, buildings, qi quests', () {
    expect(save.discoverChests(), isNotEmpty);
    expect(save.buildings(), isNotEmpty);
    final qi = save.qiQuests();
    final key = QiQuestTemplate.all.first.key;
    qi.accept(key);
    expect(qi.inProgress, contains(key));
    qi.cancel(key);
    expect(qi.inProgress, isNot(contains(key)));
  });

  test('professions enforce parents', () {
    final p = save.mainPlayer;
    p.setProfession(4, true); // Artisan -> Tiller
    expect(p.professions, containsAll([1, 4]));
    p.setProfession(1, false);
    expect(p.professions.contains(4), isFalse);
  });

  test('friendships', () {
    final p = save.mainPlayer;
    final added = p.addMissingFriendships();
    expect(p.friendships.length, greaterThanOrEqualTo(added));
    final f = p.friendships.first;
    f.hearts = 5;
    expect(f.points, 1250);
  });

  test('rejects SaveGameInfo', () {
    expect(() => SaveFile.parse(Uint8List.fromList('<?xml version="1.0"?><Farmer/>'.codeUnits), 'SaveGameInfo'),
        throwsA(isA<SaveFormatException>()));
  });

  test('Farmer equipment constant', () {
    expect(equipmentSlots, contains('hat'));
  });
}
