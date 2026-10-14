import '../save/items.dart';
import 'l10n.dart';

const _seasons = ['spring', 'summer', 'fall', 'winter'];

/// "Spring" … "Winter" in the current language. Accepts an index or a key.
String seasonName(Object s) {
  final i = s is int ? s : _seasons.indexOf(s.toString().toLowerCase());
  return switch (i) {
    0 => tr('Spring'),
    1 => tr('Summer'),
    2 => tr('Fall'),
    3 => tr('Winter'),
    _ => s.toString(),
  };
}

/// Monday-based weekday index 0..6.
String weekdayShort(int i) => [tr('Mon'), tr('Tue'), tr('Wed'), tr('Thu'), tr('Fri'), tr('Sat'), tr('Sun')][i % 7];
String weekdayLong(int i) =>
    [tr('Monday'), tr('Tuesday'), tr('Wednesday'), tr('Thursday'), tr('Friday'), tr('Saturday'), tr('Sunday')][i % 7];

String seasonsText(List? list) {
  final l = (list ?? const []).map((e) => e.toString()).toList();
  if (l.length >= 4) return tr('All seasons');
  return l.map(seasonName).join(', ');
}

String skillName(String skill) => switch (skill) {
      'farming' => tr('Farming'),
      'fishing' => tr('Fishing'),
      'foraging' => tr('Foraging'),
      'mining' => tr('Mining'),
      'combat' => tr('Combat'),
      _ => skill,
    };

final _l = L10n.i;

/// Localized display name for tracker data records.
String objectName(Map j) => _l.itemName({'id': j['id'], 'type': j['type'] ?? 'O'}, j['name']?.toString());

String villagerName(Object? name) => _l.villagerName(name.toString());

String cropName(Map c) {
  final h = c['harvest'] as Map?;
  return h == null ? c['name'].toString() : _l.itemName(h, c['name']?.toString());
}

String recipeName(Map r) {
  final out = r['output'] as Map?;
  if (out != null) return _l.itemName(out, r['name']?.toString());
  return _l.itemName({'id': r['id'], 'type': 'O'}, r['name']?.toString());
}

String wearableName(Map w) {
  final qid = (w['qualifiedId'] ?? '').toString();
  if (w['kind'] == 'ring') return _l.itemName({'id': w['id'], 'type': 'O'}, w['name']?.toString());
  return _l.wearableName(qid, w['name'].toString());
}

String? wearableDescription(Map w) {
  final qid = (w['qualifiedId'] ?? '').toString();
  if (w['kind'] == 'ring') return _l.itemDescription(w['id'].toString()) ?? w['description']?.toString();
  return _l.wearableDescription(qid) ?? w['description']?.toString();
}

String? objectDescription(Map j) => _l.itemDescription(j['id'].toString()) ?? j['description']?.toString();

String monsterName(Map m) => _l.monsterName(m['id'].toString());
String bundleName(Map b) => _l.bundleName(b['key'].toString(), b['name'].toString());
String buildingName(Map b) => _l.buildingName(b['id']?.toString() ?? b['name'].toString());

/// Text stored under an app i18n key (walnut descriptions, stardrops…).
String appText(String? key, Object? fallback) => (key == null ? null : _l.app(key)) ?? (fallback ?? '').toString();

/// Localized name for an item from the editor's item database.
String editorItemName(ItemInfo info) {
  final type = switch (info.type) {
    'BigCraftable' => 'BO',
    'Furniture' => 'F',
    'Hat' => 'H',
    'Shirt' => 'S',
    'Pants' => 'P',
    'Boots' => 'B',
    'Trinket' => 'TR',
    'Object' => 'O',
    _ => null,
  };
  if (type == null) return info.name;
  return _l.itemName({'id': info.key, 'type': type}, info.name);
}
