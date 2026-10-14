import 'dart:convert';

import 'package:flutter/services.dart';

typedef Json = Map<String, dynamic>;

/// Game reference data extracted from the original tracker (game 1.6 content).
class GameData {
  GameData._();
  static late final GameData i;

  late final List<Json> villagers;
  late final Json villagerSchedules;
  late final List<Json> fish;
  late final List<Json> crops;
  late final List<Json> items;
  late final List<Json> shipping;
  late final Json museum;
  late final Json bundles;
  late final List<Json> cooking;
  late final Json crafting;
  late final Json calendar;
  late final List<Json> walnuts;
  late final List<Json> stardrops;
  late final List<Json> wearables;
  late final List<Json> monsters;
  late final Json mining;
  late final Json shops;
  late final List<Json> buildings;
  late final List<Json> bigCraftables;
  late final Json universalGiftTastes;
  late final Json constants;

  late final Map<String, Json> itemsById = {for (final it in items) it['id'].toString(): it};

  /// Maps 1.6 string ids (e.g. "SeaJelly") and numeric ids to the app's ids.
  late final Map<String, String> gameIdToAppId = {
    for (final it in items) ...{
      it['id'].toString(): it['id'].toString(),
      if (it['internalName'] != null) it['internalName'].toString(): it['id'].toString(),
      if (it['gameId'] != null) it['gameId'].toString(): it['id'].toString(),
    }
  };

  static Future<void> load() async {
    final g = GameData._();
    Future<dynamic> read(String name) async =>
        jsonDecode(await rootBundle.loadString('assets/tracker/data/$name.json'));
    List<Json> list(dynamic v) => (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final results = await Future.wait([
      read('villagers'), read('villager_schedules'), read('fish'), read('crops'), read('items'),
      read('shipping'), read('museum'), read('bundles'), read('cooking_recipes'), read('crafting_recipes'),
      read('calendar'), read('golden_walnuts'), read('stardrops'), read('wearables'), read('monsters'),
      read('mining'), read('shops'), read('buildings'), read('big_craftables'), read('universal_gift_tastes'),
      read('constants'),
    ]);
    var k = 0;
    g.villagers = list(results[k++]);
    g.villagerSchedules = results[k++] as Json;
    g.fish = list(results[k++]);
    g.crops = list(results[k++]);
    g.items = list(results[k++]);
    g.shipping = list(results[k++]);
    g.museum = results[k++] as Json;
    g.bundles = results[k++] as Json;
    g.cooking = list(results[k++]);
    g.crafting = results[k++] as Json;
    g.calendar = results[k++] as Json;
    g.walnuts = list(results[k++]);
    g.stardrops = list(results[k++]);
    g.wearables = list(results[k++]);
    g.monsters = list(results[k++]);
    g.mining = results[k++] as Json;
    g.shops = results[k++] as Json;
    g.buildings = list(results[k++]);
    g.bigCraftables = list(results[k++]);
    g.universalGiftTastes = results[k++] as Json;
    g.constants = results[k++] as Json;
    i = g;
  }

  /// Social villagers shown in the villager list (have a portrait/icon).
  late final List<Json> socialVillagers = villagers
      .where((v) => v['inAllVillagers'] == true)
      .toList()
    ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

  Json? villager(String name) {
    for (final v in villagers) {
      if (v['name'] == name || v['id'] == name) return v;
    }
    return null;
  }

  List<Json> get artifacts => (museum['artifacts'] as List).cast<Json>();
  List<Json> get minerals => [
        ...(museum['foragedMinerals'] as List).cast<Json>(),
        ...(museum['gems'] as List).cast<Json>(),
        ...(museum['geodeMinerals'] as List).cast<Json>(),
      ];
  List<Json> get craftingRecipes => (crafting['recipes'] as List).cast<Json>();
  List<Json> get craftingGroups => (crafting['groups'] as List).cast<Json>();
}

String? imagePath(Object? image) {
  if (image == null) return null;
  final s = image.toString();
  if (s.isEmpty) return null;
  return 'assets/tracker/img/$s${s.endsWith('_anim') ? '.gif' : '.png'}';
}

const seasons = ['spring', 'summer', 'fall', 'winter'];

String cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// Game clock int (e.g. 1330) → "1:30 PM".
String gameTime(int t) {
  var h = t ~/ 100;
  final m = t % 100;
  if (h >= 24) h -= 24;
  final ampm = h >= 12 ? 'PM' : 'AM';
  var h12 = h % 12;
  if (h12 == 0) h12 = 12;
  return '$h12:${m.toString().padLeft(2, '0')} $ampm';
}
