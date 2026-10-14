import 'package:xml/xml.dart';

import 'color.dart';
import 'game_constants.dart';
import 'items.dart';
import 'xml_ext.dart';

const equipmentSlots = ['hat', 'shirtItem', 'pantsItem', 'boots', 'leftRing', 'rightRing', 'trinketItem'];

const equipmentSlotTypes = {
  'hat': 'Hat',
  'shirtItem': 'Clothing',
  'pantsItem': 'Clothing',
  'boots': 'Boots',
  'leftRing': 'Ring',
  'rightRing': 'Ring',
  'trinketItem': 'Trinket',
};

const _legacyWalletFields = {
  'canUnderstandDwarves': 'HasDwarvishTranslationGuide',
  'hasRustyKey': 'HasRustyKey',
  'hasClubCard': 'HasClubCard',
  'hasSpecialCharm': 'HasSpecialCharm',
  'hasSkullKey': 'HasSkullKey',
  'hasMagnifyingGlass': 'HasMagnifyingGlass',
  'hasDarkTalisman': 'HasDarkTalisman',
  'hasMagicInk': 'HasMagicInk',
  'HasTownKey': 'HasTownKey',
  'hasUnlockedSkullDoor': 'HasUnlockedSkullDoor',
};

/// View over a `<player>` or `<Farmer>` element.
class Farmer {
  Farmer(this.el) {
    _migrateLegacyWalletFlags();
  }

  final XmlElement el;

  // ---- basic fields ----
  String get name => el.str('name') ?? '';
  set name(String v) => el.setStr('name', v);
  String get farmName => el.str('farmName') ?? '';
  set farmName(String v) => el.setStr('farmName', v);
  String get favoriteThing => el.str('favoriteThing') ?? '';
  set favoriteThing(String v) => el.setStr('favoriteThing', v);

  int get money => el.integer('money') ?? 0;
  set money(int v) => el.setInt('money', v);
  int get totalMoneyEarned => el.integer('totalMoneyEarned') ?? 0;
  set totalMoneyEarned(int v) => el.setInt('totalMoneyEarned', v);
  int get qiGems => el.integer('qiGems') ?? 0;
  set qiGems(int v) => el.setInt('qiGems', v);
  int get clubCoins => el.integer('clubCoins') ?? 0;
  set clubCoins(int v) => el.setInt('clubCoins', v);
  int get maxHealth => el.integer('maxHealth') ?? 100;
  set maxHealth(int v) => el.setInt('maxHealth', v);
  int get maxStamina => el.integer('maxStamina') ?? 270;
  set maxStamina(int v) => el.setInt('maxStamina', v);
  int get maxItems => el.integer('maxItems') ?? 12;
  int get deepestMineLevel => el.integer('deepestMineLevel') ?? 0;
  set deepestMineLevel(int v) => el.setInt('deepestMineLevel', v);
  String get uniqueId => el.str('UniqueMultiplayerID') ?? '0';
  String get homeLocation => el.str('homeLocation') ?? '';

  // ---- appearance ----
  bool get isMale => (el.str('Gender') ?? el.str('gender') ?? 'Male') != 'Female';
  set isMale(bool v) {
    final s = v ? 'Male' : 'Female';
    el.setStr('Gender', s);
    if (el.child('gender') != null) el.setStr('gender', s);
    if (el.child('isMale') != null) el.setBool('isMale', v);
  }

  int get skin => el.integer('skin') ?? 0;
  set skin(int v) => el.setInt('skin', v);
  int get accessory => el.integer('accessory') ?? -1;
  set accessory(int v) => el.setInt('accessory', v);

  /// UI hairstyle index: raw values >= 100 are the 1.6 extra styles mapped
  /// after the 56 classic ones.
  int get hairstyle {
    final h = el.integer('hair') ?? 0;
    return h >= 100 ? h - 100 + 56 : h;
  }

  set hairstyle(int v) => el.setInt('hair', v >= 56 ? v + 100 - 56 : v);

  SdvColor get hairColor => SdvColor.fromElement(el.ensure('hairstyleColor'));
  set hairColor(SdvColor c) => c.writeTo(el.ensure('hairstyleColor'));
  SdvColor get eyeColor => SdvColor.fromElement(el.ensure('newEyeColor'));
  set eyeColor(SdvColor c) => c.writeTo(el.ensure('newEyeColor'));

  // ---- skills ----
  static const skillOrder = ['farming', 'fishing', 'foraging', 'mining', 'combat'];
  static const xpForLevel = [0, 100, 380, 770, 1300, 2150, 3300, 4800, 6900, 10000, 15000];

  static int levelForXp(int xp) {
    var level = 0;
    for (var i = 0; i < xpForLevel.length; i++) {
      if (xp < xpForLevel[i]) break;
      level = i;
    }
    return level;
  }

  int experience(String skill) {
    final list = el.intList('experiencePoints');
    final i = skillOrder.indexOf(skill);
    return i < list.length ? list[i] : 0;
  }

  void setExperience(String skill, int xp) {
    final list = el.intList('experiencePoints');
    final i = skillOrder.indexOf(skill);
    while (list.length < 6) {
      list.add(0);
    }
    list[i] = xp.clamp(0, 99999);
    el.setIntList('experiencePoints', list);
    el.setInt('${skill}Level', levelForXp(xp));
  }

  int level(String skill) => levelForXp(experience(skill));

  // ---- professions ----
  Set<int> get professions => el.intList('professions').toSet();

  bool hasProfession(int p) => professions.contains(p);

  void setProfession(int p, bool enabled) {
    final set = professions;
    if (enabled) {
      final parent = Professions.parentOf(p);
      if (parent != null) set.add(parent);
      set.add(p);
    } else {
      set.remove(p);
      if (Professions.isPrimary(p)) set.removeAll(Professions.secondariesOf(p));
    }
    el.setIntList('professions', set.toList()..sort());
  }

  // ---- mail flags ----
  List<String> get mailReceived => el.stringList('mailReceived');
  bool hasMail(String flag) => mailReceived.contains(flag);
  void setMail(String flag, bool on) {
    final list = mailReceived;
    if (on && !list.contains(flag)) list.add(flag);
    if (!on) list.remove(flag);
    el.setStringList('mailReceived', list);
  }

  void _migrateLegacyWalletFlags() {
    final list = mailReceived;
    var changed = false;
    _legacyWalletFields.forEach((field, flag) {
      final node = el.child(field);
      if (node == null) return;
      final present = !node.isNil && node.innerText.trim() != 'false';
      if (present && !list.contains(flag)) {
        list.add(flag);
        changed = true;
      }
      el.children.remove(node);
    });
    if (changed) el.setStringList('mailReceived', list);
  }

  // ---- friendships ----
  List<Friendship> get friendships {
    final data = el.child('friendshipData');
    if (data == null) return [];
    final list = data.childrenNamed('item').map(Friendship.new).toList();
    list.sort((a, b) {
      final c = b.points.compareTo(a.points);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return list;
  }

  /// Adds a zero-heart entry for every social NPC missing from the save.
  int addMissingFriendships() {
    final data = el.ensure('friendshipData');
    final existing = data.childrenNamed('item').map((e) => e.path(['key', 'string'])?.innerText).toSet();
    var added = 0;
    for (final npc in socialNpcs) {
      if (existing.contains(npc)) continue;
      data.children.add(buildElement('item', {
        'key': {'string': npc},
        'value': {
          'Friendship': {
            'Points': 0,
            'GiftsThisWeek': 0,
            'GiftsToday': 0,
            'TalkedToToday': false,
            'ProposalRejected': false,
            'Status': 'Friendly',
            'Proposer': 0,
            'RoommateMarriage': false,
          }
        }
      }));
      added++;
    }
    return added;
  }

  // ---- recipes ----
  /// Recipe name -> times crafted, only for unlocked recipes.
  Map<String, int> recipes(String container) {
    final c = el.child(container);
    if (c == null) return {};
    return {
      for (final item in c.childrenNamed('item'))
        item.path(['key', 'string'])?.innerText ?? '': item.path(['value', 'int'])?.innerText.trim().let(int.tryParse) ?? 0,
    };
  }

  void setRecipe(String container, String recipe, bool unlocked) {
    final c = el.ensure(container);
    final existing = c.childrenNamed('item').where((i) => i.path(['key', 'string'])?.innerText == recipe).toList();
    if (!unlocked) {
      for (final e in existing) {
        c.children.remove(e);
      }
    } else if (existing.isEmpty) {
      c.children.add(buildElement('item', {
        'key': {'string': recipe},
        'value': {'int': 0},
      }));
    }
  }

  // ---- inventory ----
  XmlElement get _items => el.ensure('items');
  List<XmlElement> get itemSlots => _items.childrenNamed('Item').toList();

  ItemView? itemAt(int index) {
    final slots = itemSlots;
    if (index >= slots.length) return null;
    final e = slots[index];
    if (e.isNil || (e.str('name') ?? '').startsWith('Secret Note')) return null;
    return ItemView(e);
  }

  void setItemAt(int index, XmlElement? item) {
    final slots = itemSlots;
    if (index >= slots.length) return;
    final replacement = item ?? buildElement('Item', {'@xsi:nil': 'true'});
    slots[index].replace(replacement);
  }

  /// Grows or shrinks the backpack (12, 24 or 36 slots).
  void setBackpackSize(int size) {
    final slots = itemSlots;
    if (size > slots.length) {
      for (var i = slots.length; i < size; i++) {
        _items.children.add(buildElement('Item', {'@xsi:nil': 'true'}));
      }
    } else {
      for (var i = size; i < slots.length; i++) {
        _items.children.remove(slots[i]);
      }
    }
    el.setInt('maxItems', size);
  }

  ItemView? equipment(String slot) {
    final e = el.child(slot);
    if (e == null || e.isNil) return null;
    return ItemView(e, slotType: equipmentSlotTypes[slot]);
  }

  void setEquipment(String slot, XmlElement? item) {
    final existing = el.child(slot);
    if (item == null) {
      if (existing != null) el.children.remove(existing);
      return;
    }
    final tagged = ItemFactory.retag(item, slot);
    if (existing != null) {
      existing.replace(tagged);
    } else {
      // Keep equipment near the other equipment fields when possible.
      final anchor = el.child('items');
      if (anchor != null) {
        final idx = el.children.indexOf(anchor);
        el.children.insert(idx + 1, tagged);
      } else {
        el.children.add(tagged);
      }
    }
  }

  int get trinketSlots {
    final values = el.path(['stats', 'Values']);
    if (values == null) return 0;
    for (final item in values.childrenNamed('item')) {
      if (item.path(['key', 'string'])?.innerText == 'trinketSlots') {
        return int.tryParse(item.path(['value', 'unsignedInt'])?.innerText ?? '') ?? 0;
      }
    }
    return 0;
  }

  // ---- collection progress, read-only (used by the tracker sync) ----
  /// Keys of `<item><key><string|int>..` dictionaries such as basicShipped.
  Map<String, int> dictionary(String container) {
    final c = el.child(container);
    if (c == null) return {};
    final out = <String, int>{};
    for (final item in c.childrenNamed('item')) {
      final key = item.child('key')?.childElements.firstOrNull?.innerText;
      if (key == null) continue;
      final valueEl = item.child('value')?.childElements.firstOrNull;
      int v = 1;
      if (valueEl != null) {
        if (valueEl.tag == 'ArrayOfInt') {
          v = int.tryParse(valueEl.childElements.firstOrNull?.innerText ?? '') ?? 1;
        } else {
          v = int.tryParse(valueEl.innerText.trim()) ?? 1;
        }
      }
      out[key] = v;
    }
    return out;
  }

  List<String> get eventsSeen => el.stringList('eventsSeen', 'int');
  List<int> get secretNotesSeen => el.intList('secretNotesSeen');
  List<int> get achievements => el.intList('achievements');
}

class Friendship {
  Friendship(this.el);
  final XmlElement el;

  XmlElement get _f => el.path(['value', 'Friendship'])!;
  String get name => el.path(['key', 'string'])?.innerText ?? '';
  int get points => _f.integer('Points') ?? 0;
  set points(int v) => _f.setInt('Points', v.clamp(0, maxPoints));
  String get status => _f.str('Status') ?? 'Friendly';
  set status(String v) => _f.setStr('Status', v);
  int get giftsThisWeek => _f.integer('GiftsThisWeek') ?? 0;
  set giftsThisWeek(int v) => _f.setInt('GiftsThisWeek', v);
  bool get talkedToToday => _f.boolean('TalkedToToday') ?? false;
  set talkedToToday(bool v) => _f.setBool('TalkedToToday', v);

  bool get dateable => dateableNpcs.contains(name);
  int get maxHearts => dateable
      ? (status == 'Married' ? 14 : (status == 'Dating' ? 10 : 8))
      : 10;
  int get maxPoints => maxHearts * 250 + 249;
  int get hearts => points ~/ 250;
  set hearts(int v) => points = v * 250;
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
