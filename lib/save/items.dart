import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import 'color.dart';
import 'xml_ext.dart';

/// Static metadata for one game item (generated from the game's content files
/// by the stardew-save-editor project, see assets/editor/data/iteminfo.json).
class ItemInfo {
  ItemInfo(this.raw);
  final Map<String, dynamic> raw;

  String get type => raw['_type'] as String;
  String get key => raw['_key'].toString();
  String get name => raw['name'] as String;
  int? get category => raw['category'] as int?;
  String? get objectType => raw['type']?.toString();
  int? get price => (raw['price'] as num?)?.toInt();
  int? get edibility => (raw['edibility'] as num?)?.toInt();
  int? get spriteIndex => (raw['spriteIndex'] as num?)?.toInt();
  int? get menuSpriteIndex => (raw['menuSpriteIndex'] as num?)?.toInt();
  String? get texture => raw['texture'] as String?;
  bool get canBeDyed => raw['canBeDyed'] == true;
  String? get color => raw['color'] as String?;
  String? get description {
    final d = raw['description'] as String?;
    if (d == null || d.startsWith('[LocalizedText')) return null;
    return d;
  }

  bool get isRing => type == 'Object' && objectType == 'Ring';

  /// Category used to group items in the picker.
  String get group {
    switch (type) {
      case 'Object':
        if (isRing) return 'Ring';
        return 'Object';
      case 'Shirt':
      case 'Pants':
        return 'Clothing';
      default:
        return type;
    }
  }

  late final SpriteRef? sprite = SpriteRef.forInfo(this);
}

/// A rectangle inside one of the sprite sheets in assets/editor/sheets.
class SpriteRef {
  const SpriteRef(this.sheet, this.src, {this.tint});
  final String sheet;
  final Rect src;
  final Color? tint;

  String get assetPath => 'assets/editor/sheets/$sheet';

  static const _defaultSheets = {
    'Object': 'springobjects.png',
    'Boots': 'springobjects.png',
    'BigCraftable': 'Craftables.png',
    'Pants': 'pants.png',
    'Shirt': 'shirts.png',
    'Hat': 'hats.png',
    'Furniture': 'furniture.png',
    'Weapon': 'weapons.png',
    'Tool': 'tools.png',
  };

  static const _furnitureSizes = <String, Size>{
    'chair': Size(16, 32),
    'bench': Size(32, 32),
    'couch': Size(48, 32),
    'armchair': Size(32, 32),
    'dresser': Size(32, 32),
    'long table': Size(80, 48),
    'painting': Size(32, 32),
    'lamp': Size(16, 32),
    'decor': Size(16, 32),
    'other': Size(16, 16),
    'bookcase': Size(32, 48),
    'table': Size(32, 48),
    'rug': Size(48, 32),
    'window': Size(16, 32),
    'fireplace': Size(32, 80),
    'bed': Size(48, 64),
    'torch': Size(16, 32),
    'sconce': Size(16, 16),
  };

  static SpriteRef? forInfo(ItemInfo info, {bool female = false}) {
    final sheet = info.texture ?? _defaultSheets[info.type] ?? 'springobjects.png';
    final sheetSize = SheetSizes.of(sheet);
    if (sheetSize == null) return null;
    final menu = info.menuSpriteIndex;
    final index = (menu != null && menu >= 0)
        ? menu
        : (info.spriteIndex ?? int.tryParse(info.key));
    if (index == null) return null;

    switch (info.type) {
      case 'Hat':
        return SpriteRef(sheet, _cell(index, 20, 80, 240, w: 20, h: 20));
      case 'Pants':
        final left = (index * 192) % 1920 + (female ? 96 : 0);
        final top = (index * 192 ~/ 1920) * 688 + 672;
        return SpriteRef(sheet, Rect.fromLTWH(left.toDouble(), top.toDouble(), 16, 16));
      case 'Shirt':
        final left = (index * 8) % 128 + (info.canBeDyed ? 128 : 0);
        final top = (index * 8 ~/ 128) * 32;
        return SpriteRef(sheet, Rect.fromLTWH(left.toDouble(), top.toDouble(), 8, 8));
    }

    Size size;
    if (info.type == 'Furniture') {
      final ts = info.raw['tilesheetSize'] as Map<String, dynamic>?;
      size = ts != null
          ? Size((ts['width'] as num) * 16.0, (ts['height'] as num) * 16.0)
          : (_furnitureSizes[info.objectType] ?? const Size(16, 16));
    } else if (info.type == 'Mannequin') {
      size = const Size(16, 32);
    } else if (info.type == 'BigCraftable') {
      size = const Size(16, 32);
    } else {
      size = const Size(16, 16);
    }
    final isFurnitureSheet = sheet.contains('furniture');
    final stepW = isFurnitureSheet ? 16 : size.width.toInt();
    final stepH = isFurnitureSheet ? 16 : size.height.toInt();
    final left = (index * stepW) % sheetSize.width.toInt();
    final top = (index * stepW ~/ sheetSize.width.toInt()) * stepH;
    final rect = Rect.fromLTWH(left.toDouble(), top.toDouble(), size.width, size.height);
    if (rect.bottom > sheetSize.height || rect.right > sheetSize.width) return null;
    return SpriteRef(sheet, rect);
  }

  static Rect _cell(int index, int itemW, int itemH, int sheetW,
      {required int w, required int h}) {
    final left = (index * itemW) % sheetW;
    final top = (index * itemW ~/ sheetW) * itemH;
    return Rect.fromLTWH(left.toDouble(), top.toDouble(), w.toDouble(), h.toDouble());
  }
}

class SheetSizes {
  static final Map<String, Size> _sizes = {};
  static Size? of(String sheet) => _sizes[sheet];
  static Future<void> load() async {
    final list = jsonDecode(
        await rootBundle.loadString('assets/editor/data/dimensions.json')) as List;
    for (final e in list) {
      final m = e[1] as Map<String, dynamic>;
      _sizes[e[0] as String] =
          Size((m['width'] as num).toDouble(), (m['height'] as num).toDouble());
    }
  }
}

/// Index over every known item.
class ItemDb {
  ItemDb._(this.all);
  static ItemDb? _instance;
  static ItemDb get instance => _instance!;
  static bool get loaded => _instance != null;

  final List<ItemInfo> all;
  late final Map<String, ItemInfo> byName = {for (final i in all) i.name: i};
  late final Map<String, ItemInfo> _byTypeKey = {
    for (final i in all) '${i.type}|${i.key}': i
  };
  late final Map<String, ItemInfo> shirtsByKey = {
    for (final i in all.where((i) => i.type == 'Shirt')) i.key: i
  };

  static Future<void> load() async {
    if (_instance != null) return;
    await SheetSizes.load();
    final list = jsonDecode(
        await rootBundle.loadString('assets/editor/data/iteminfo.json')) as List;
    _instance = ItemDb._([
      for (final e in list) ItemInfo(Map<String, dynamic>.from(e[1] as Map)),
    ]);
  }

  ItemInfo? byKey(String type, String key) => _byTypeKey['$type|$key'];

  /// Looks up an object by its qualified/unqualified id, e.g. "(O)24" or "24".
  ItemInfo? objectById(String id) {
    final m = RegExp(r'^\((\w+)\)(.*)$').firstMatch(id);
    if (m != null) {
      final type = switch (m.group(1)) {
        'O' => 'Object',
        'BC' => 'BigCraftable',
        'F' => 'Furniture',
        'H' => 'Hat',
        'S' => 'Shirt',
        'P' => 'Pants',
        'B' => 'Boots',
        'W' => 'Weapon',
        'T' => 'Tool',
        'TR' => 'Trinket',
        _ => 'Object',
      };
      return byKey(type, m.group(2)!);
    }
    return byKey('Object', id);
  }

  static const _qualityCategories = {-4, -5, -6, -7, -17, -18, -26, -27, -75, -79, -80, -81};
  static bool categoryHasQuality(int? category) =>
      category != null && _qualityCategories.contains(category);

  List<String> _expectedTypes(String? xsiType) {
    switch (xsiType) {
      case 'Hat':
        return ['Hat'];
      case 'Boots':
        return ['Boots'];
      case 'Clothing':
        return ['Shirt', 'Pants'];
      case 'Ring':
      case 'CombinedRing':
      case 'ColoredObject':
      case 'Object':
      case 'Cask':
        return ['Object'];
      case 'Furniture':
        return ['Furniture'];
      case 'Mannequin':
        return ['Mannequin'];
      case 'Trinket':
        return ['Trinket'];
      case 'MeleeWeapon':
        return ['Weapon'];
      case 'Tool':
      case 'FishingRod':
      case 'WateringCan':
      case 'Slingshot':
      case 'Pickaxe':
      case 'Axe':
      case 'Pan':
      case 'Hoe':
      case 'MilkPail':
      case 'Shears':
      case 'Wand':
        return ['Tool'];
      default:
        return [];
    }
  }

  /// Resolves metadata for an item element from a save, mirroring the web
  /// editor's lookup order (direct id match, display-name helper, preserves).
  ItemInfo? resolve(XmlElement item, {String? slotType}) {
    final name = item.str('name');
    final rawId = item.str('itemId')?.replaceFirst(RegExp(r'^\([^)]*\)'), '');
    if (name == 'Shirt' && rawId != null) return shirtsByKey[rawId];
    final xsi = item.xsiType ?? slotType;
    if (rawId != null) {
      for (final t in _expectedTypes(xsi)) {
        final hit = byKey(t, rawId);
        if (hit != null) {
          // BigCraftables share numeric ids with Objects.
          if (t == 'Object' && item.boolean('bigCraftable') == true) {
            return byKey('BigCraftable', rawId) ?? hit;
          }
          return hit;
        }
      }
    }
    final helper = ItemView.displayNameFor(item);
    if (helper != null && byName[helper] != null) return byName[helper];
    if (rawId != null && item.str('preserve') != null) return byKey('Object', rawId);
    return null;
  }
}

/// Live view over an `<Item>` element (inventory slot, equipment or chest).
class ItemView {
  ItemView(this.el, {this.slotType}) : info = ItemDb.instance.resolve(el, slotType: slotType);

  final XmlElement el;
  final String? slotType;
  final ItemInfo? info;

  static String? displayNameFor(XmlElement item) {
    final name = item.str('name');
    final level = item.integer('upgradeLevel');
    if (name == 'Fishing Rod' && level != null) {
      return const ['Bamboo Pole', 'Training Rod', 'Fiberglass Rod', 'Iridium Rod', 'Advanced Iridium Rod']
          [level.clamp(0, 4)];
    }
    for (final tool in const ['Pickaxe', 'Axe', 'Hoe', 'Watering Can']) {
      if ((name ?? '').endsWith(tool) && level != null) {
        return switch (level) {
          4 => 'Iridium $tool',
          3 => 'Gold $tool',
          2 => 'Steel $tool',
          1 => 'Copper $tool',
          _ => tool,
        };
      }
    }
    return name;
  }

  String get name => displayNameFor(el) ?? info?.name ?? 'Unknown item';
  String? get xsiType => el.xsiType ?? slotType;

  bool get hasQuality => ItemDb.categoryHasQuality(el.integer('category'));
  int get quality => el.integer('quality') ?? 0;
  set quality(int q) {
    var v = q.clamp(0, 4);
    if (v == 3) v = 2;
    el.setInt('quality', v);
  }

  bool get isStackable {
    final t = info?.type;
    if (t == null) return true;
    return !const ['Boots', 'Hat', 'Weapon', 'Pants', 'Shirt', 'Tool', 'Trinket'].contains(t) &&
        !(info?.isRing ?? false);
  }

  int get stack => el.integer('stack') ?? 1;
  set stack(int v) => el.setInt('stack', max(1, v));

  bool get isObject => info?.type == 'Object' && !(info?.isRing ?? false);
  int? get price => el.integer('price');
  set price(int? v) {
    if (v != null) el.setInt('price', v.clamp(0, 99999));
  }

  int? get edibility {
    final e = el.integer('edibility');
    return e == -300 ? null : e;
  }

  set edibility(int? v) {
    if (v != null) el.setInt('edibility', v);
  }

  bool get isWeapon => el.xsiType == 'MeleeWeapon';
  bool get isTool =>
      info?.type == 'Tool' || const ['Axe', 'Pickaxe', 'Hoe', 'WateringCan', 'FishingRod', 'Pan'].contains(el.xsiType);

  int? get upgradeLevel => el.integer('upgradeLevel');
  set upgradeLevel(int? v) {
    if (v != null) el.setInt('upgradeLevel', v);
  }

  num? stat(String name) => el.number(name);
  void setStat(String name, num v) => el.setNum(name, v);

  bool get isDyeable => el.child('clothesColor') != null || info?.canBeDyed == true;
  SdvColor? get clothesColor {
    final c = el.child('clothesColor');
    return c == null ? null : SdvColor.fromElement(c);
  }

  set clothesColor(SdvColor? c) {
    if (c == null) return;
    c.writeTo(el.ensure('clothesColor'));
  }

  SpriteRef? get sprite {
    final i = info;
    if (i == null) return null;
    return i.sprite;
  }

  Color? get tint {
    final c = el.child('color') ?? (info?.type == 'Shirt' || info?.type == 'Pants' ? el.child('clothesColor') : null);
    if (c == null) return null;
    final sc = SdvColor.fromElement(c);
    return Color.fromARGB(255, sc.r, sc.g, sc.b);
  }
}

/// Builds new item elements from metadata, mirroring `Item.fromName` in the
/// web editor.
class ItemFactory {
  static const _typeToXsi = {
    'Object': 'Object',
    'BigCraftable': 'Object',
    'Furniture': 'Furniture',
    'Weapon': 'MeleeWeapon',
    'Hat': 'Hat',
    'Shirt': 'Clothing',
    'Pants': 'Clothing',
    'Boots': 'Boots',
    'Trinket': 'Trinket',
    'Mannequin': 'Mannequin',
  };
  static const _toolTypes = {
    'Pail': 'MilkPail',
    'Pickaxe': 'Pickaxe',
    'Axe': 'Axe',
    'Hoe': 'Hoe',
    'Can': 'WateringCan',
    'Rod': 'FishingRod',
    'Pan': 'Pan',
    'Wand': 'Wand',
    'Shears': 'Shears',
  };
  static const _toolNames = {'Can': 'Watering Can', 'Rod': 'Fishing Rod', 'Pan': 'Copper Pan'};
  static const _upgrade = {'Copper': 1, 'Steel': 2, 'Gold': 3, 'Iridium': 4};
  static const _typeCategory = {
    'BigCraftable': -9,
    'Boots': -97,
    'Pants': -100,
    'Shirt': -100,
    'Furniture': -24,
    'Hat': -95,
    'Weapon': -98,
    'Tool': -99,
    'Trinket': -101,
    'Mannequin': -24,
  };
  static const _fishingRodLevel = {
    'Bamboo Pole': 0,
    'Training Rod': 1,
    'Fiberglass Rod': 2,
    'Iridium Rod': 3,
    'Advanced Iridium Rod': 4,
  };
  static const _fishingRodSprite = {
    'Bamboo Pole': 8,
    'Training Rod': 9,
    'Fiberglass Rod': 10,
    'Iridium Rod': 11,
    'Advanced Iridium Rod': 12,
  };
  static const _furnitureType = {
    'chair': 0, 'bench': 1, 'couch': 2, 'armchair': 3, 'dresser': 4, 'long table': 5,
    'painting': 6, 'lamp': 7, 'decor': 8, 'other': 9, 'bookcase': 10, 'table': 11,
    'rug': 12, 'window': 13, 'fireplace': 14, 'bed': 15, 'torch': 16, 'sconce': 17,
  };
  static const _ringIds = {
    'Small Glow Ring': 1267, 'Glow Ring': 1238, 'Small Magnet Ring': 1269,
    'Magnet Ring': 1270, 'Slime Charmer Ring': 1271, 'Warrior Ring': 1272,
    'Vampire Ring': 1273, 'Savage Ring': 1274, 'Ring of Yoba': 1275,
    'Sturdy Ring': 1276, "Burglar's Ring": 1247, 'Iridium Band': 1248,
    'Jukebox Ring': 1249, 'Amethyst Ring': 1169, 'Topaz Ring': 1281,
    'Aquamarine Ring': 1191, 'Jade Ring': 1253, 'Emerald Ring': 1254,
    'Ruby Ring': 1285, 'Crabshell Ring': 1531, 'Napalm Ring': 1562,
    'Thorns Ring': 1590, 'Lucky Ring': 1580, 'Hot Java Ring': 1581,
    'Protection Ring': 1612, 'Soul Sapper Ring': 1613, 'Phoenix Ring': 1614,
    'Combined Ring': 1601, 'Glowstone Ring': 1609,
  };
  static const _preserve = {
    'Pickles': 'Pickle', 'Aged Roe': 'AgedRoe', 'Smoked': 'SmokedFish',
    'Wine': 'Wine', 'Jelly': 'Jelly', 'Juice': 'Juice', 'Roe': 'Roe',
    'Honey': 'Honey', 'Bait': 'Bait',
  };

  /// Creates an element named [tag] (`Item` for inventory/chests, or the
  /// equipment slot name, in which case no xsi:type is written for the
  /// default slot type).
  static XmlElement create(ItemInfo data, {String tag = 'Item', int stack = 1}) {
    final category = data.category ?? _typeCategory[data.type];
    final m = <String, Object?>{
      'isLostItem': false,
      'category': category,
      'hasBeenInInventory': true,
      'name': data.name,
      'itemId': data.key,
      'specialItem': false,
      'isRecipe': false,
      'quality': 0,
      'stack': stack,
      'SpecialVariable': 0,
    };
    if (data.spriteIndex != null && data.spriteIndex != 0) {
      m['parentSheetIndex'] = data.spriteIndex;
      m['indexInTileSheet'] = data.spriteIndex;
    }
    String? xsi = _typeToXsi[data.type];

    if (data.type == 'Object' || data.type == 'BigCraftable') {
      m['tileLocation'] = {'X': 0, 'Y': 0};
      m['type'] = data.type == 'Object' ? data.objectType : 'Crafting';
      m['canBeSetDown'] = true;
      m['canBeGrabbed'] = true;
      m['price'] = data.price ?? 0;
      m['edibility'] = data.edibility ?? -300;
      m['bigCraftable'] = data.type == 'BigCraftable';
      m['boundingBox'] = _rect(0, 0, 64, 64);
    }

    if (data.type == 'Tool') {
      final suffix = data.name.split(' ').last;
      xsi = _toolTypes[suffix];
      if (xsi != null && const ['Pickaxe', 'Axe', 'Hoe', 'WateringCan'].contains(xsi)) {
        m['upgradeLevel'] = 0;
        for (final e in _upgrade.entries) {
          if (data.name.startsWith(e.key)) {
            m['upgradeLevel'] = e.value;
            m['name'] = _toolNames[suffix] ?? suffix;
            break;
          }
        }
        m['initialParentTileIndex'] = data.spriteIndex ?? 0;
        m['indexOfMenuItemView'] = data.menuSpriteIndex ?? 0;
      }
      if (xsi == 'FishingRod' || _fishingRodLevel.containsKey(data.name)) {
        xsi = 'FishingRod';
        m['name'] = 'Fishing Rod';
        m['upgradeLevel'] = _fishingRodLevel[data.name] ?? 0;
        m['parentSheetIndex'] = 685;
        m['initialParentTileIndex'] = _fishingRodSprite[data.name] ?? 8;
        m['indexOfMenuItemView'] = _fishingRodSprite[data.name] ?? 8;
        m['numAttachmentSlots'] = data.raw['attachmentSlots'] ?? 0;
      }
      if (xsi == 'WateringCan') {
        m['IsBottomless'] = false;
        m['isBottomless'] = false;
      }
      xsi ??= _toolTypes[data.raw['class']] ?? 'Tool';
      if (data.raw['class'] == 'Slingshot') xsi = 'Slingshot';
    }

    if (data.type == 'Weapon') {
      m['minDamage'] = data.raw['minDamage'];
      m['maxDamage'] = data.raw['maxDamage'];
      m['speed'] = data.raw['speed'];
      m['addedPrecision'] = data.raw['precision'];
      m['addedDefense'] = data.raw['defense'];
      m['addedAreaOfEffect'] = data.raw['areaOfEffect'];
      m['knockback'] = data.raw['knockback'];
      m['critChance'] = data.raw['critChance'];
      m['critMultiplier'] = data.raw['critMultiplier'];
      m['type'] = data.raw['type'];
    }

    if (data.type == 'Trinket') {
      m['generationSeed'] = Random().nextInt(9999999);
    }

    if (data.isRing) {
      xsi = 'Ring';
      m['uniqueID'] = _ringIds[data.name] ?? Random().nextInt(1 << 30);
    }

    if (data.type == 'Hat') {
      m['which'] = null;
      m['skipHairDraw'] = data.raw['showRealHair'];
      m['ignoreHairstyleOffset'] = data.raw['skipHairstyleOffset'];
    }

    if (data.type == 'Furniture') {
      m['type'] = _furnitureType[data.objectType] ?? 9;
      m['canBeGrabbed'] = true;
      final sprite = data.sprite;
      final ts = data.raw['tilesheetSize'] as Map<String, dynamic>?;
      if (ts != null && sprite != null) {
        final w = (ts['width'] as num).toInt() * 16;
        final h = (ts['height'] as num).toInt() * 16;
        final r = _rect(sprite.src.left.toInt(), sprite.src.top.toInt(), w, h);
        m['sourceRect'] = r;
        m['defaultSourceRect'] = r;
      }
      final bb = data.raw['boundingBoxSize'] as Map<String, dynamic>?;
      if (bb != null) {
        final r = _rect(0, 0, (bb['width'] as num).toInt(), (bb['height'] as num).toInt());
        m['boundingBox'] = r;
        m['defaultBoundingBox'] = r;
      }
      if (data.objectType == 'lamp') m['isLamp'] = true;
    }

    if (data.type == 'Shirt' || data.type == 'Pants') {
      m['price'] = data.price ?? 0;
      m['clothesType'] = data.type == 'Shirt' ? 'SHIRT' : 'PANTS';
      m['dyeable'] = data.canBeDyed;
      m['isPrismatic'] = data.raw['isPrismatic'] ?? false;
      final def = data.raw['defaultColor'] as String?;
      m['clothesColor'] = (def != null ? SdvColor.parse(def) : SdvColor(255, 255, 255)).toMap();
    }

    if (data.type == 'Boots') {
      m['defenseBonus'] = data.raw['defense'] ?? 0;
      m['immunityBonus'] = data.raw['immunity'] ?? 0;
      m['indexInTileSheet'] = int.tryParse(data.key) ?? 0;
      m['indexInColorSheet'] = data.raw['colorIndex'] ?? 0;
      m['price'] = data.price ?? 0;
    }

    final unpreserved = data.raw['unpreservedItemId'] as String?;
    final preserveLabel = data.raw['preservedItemName'] as String?;
    if (unpreserved != null && preserveLabel != null) {
      m['preservedParentSheetIndex'] = int.tryParse(unpreserved) ?? unpreserved;
      m['preserve'] = preserveLabel == 'Dried'
          ? (data.key == 'DriedMushrooms' ? 'DriedMushroom' : 'DriedFruit')
          : (_preserve[preserveLabel] ?? preserveLabel);
    }

    if (data.color != null) {
      m['color'] = SdvColor.parse(data.color!).toMap();
      if (data.type == 'Object') xsi = 'ColoredObject';
    }

    // Equipment slots carry no xsi:type for their default type.
    const slotDefaults = {
      'hat': 'Hat',
      'shirtItem': 'Clothing',
      'pantsItem': 'Clothing',
      'boots': 'Boots',
      'leftRing': 'Ring',
      'rightRing': 'Ring',
      'trinketItem': 'Trinket',
    };
    final attrs = <String, Object?>{};
    if (xsi != null && slotDefaults[tag] != xsi) attrs['@xsi:type'] = xsi;
    return buildElement(tag, {...attrs, ...m});
  }

  static Map<String, Object?> _rect(int x, int y, int w, int h) => {
        'X': x,
        'Y': y,
        'Width': w,
        'Height': h,
        'Location': {'X': x, 'Y': y},
        'Size': {'X': w, 'Y': h},
      };

  /// Re-tags an existing item element for a different container (e.g. moving
  /// from a chest `Item` to the `hat` slot).
  static XmlElement retag(XmlElement source, String tag) {
    const slotDefaults = {
      'hat': 'Hat',
      'shirtItem': 'Clothing',
      'pantsItem': 'Clothing',
      'boots': 'Boots',
      'leftRing': 'Ring',
      'rightRing': 'Ring',
      'trinketItem': 'Trinket',
    };
    final copy = XmlElement(XmlName(tag),
        source.attributes.map((a) => a.copy()), source.children.map((c) => c.copy()));
    final xsi = copy.xsiType;
    if (tag == 'Item' && xsi == null && slotDefaults[source.tag] != null) {
      copy.xsiType = slotDefaults[source.tag];
    } else if (slotDefaults[tag] != null && xsi == slotDefaults[tag]) {
      copy.xsiType = null;
    }
    return copy;
  }
}
