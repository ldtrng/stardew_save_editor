import 'package:xml/xml.dart';

import 'items.dart';
import 'save_file.dart';
import 'xml_ext.dart';

enum CCRoom {
  pantry('Pantry', 'ccPantry', 'jojaPantry'),
  craftsRoom('Crafts Room', 'ccCraftsRoom', 'jojaCraftsRoom'),
  fishTank('Fish Tank', 'ccFishTank', 'jojaFishTank'),
  boilerRoom('Boiler Room', 'ccBoilerRoom', 'jojaBoilerRoom'),
  vault('Vault', 'ccVault', 'jojaVault'),
  bulletinBoard('Bulletin Board', 'ccBulletin', null),
  abandonedJojaMart('Abandoned Joja Mart', 'ccMovieTheater', 'ccMovieTheaterJoja');

  const CCRoom(this.label, this.flag, this.jojaFlag);
  final String label;
  final String flag;
  final String? jojaFlag;

  static CCRoom? byName(String name) {
    for (final r in values) {
      if (r.label == name) return r;
    }
    return null;
  }
}

class BundleRequirement {
  BundleRequirement(this.itemId, this.quantity, this.quality);
  final String itemId;
  final int quantity;
  final int quality;

  bool get isMoney => itemId == '-1';
  ItemInfo? get info => isMoney ? null : ItemDb.instance.objectById(itemId);
  String get label => isMoney ? '${quantity}g' : (info?.name ?? itemId);
}

class Bundle {
  Bundle(this.keyEl, this.valueEl, this.submittedEl);

  final XmlElement keyEl; // <string>Pantry/0</string>
  final XmlElement valueEl; // <string>Spring Crops/O 465 20/.../0/4</string>
  final XmlElement submittedEl; // <ArrayOfBoolean>

  List<String> get _keyParts => keyEl.innerText.split('/');
  String get roomName => _keyParts.first;
  CCRoom? get room => CCRoom.byName(roomName);
  int get spriteIndex => int.tryParse(_keyParts.length > 1 ? _keyParts[1] : '') ?? 0;

  List<String> get _seg => valueEl.innerText.split('/');
  String get name => _seg.first;
  String get reward => _seg.length > 1 ? _seg[1] : '';
  int? get color => _seg.length > 3 ? int.tryParse(_seg[3]) : null;

  String get rewardLabel {
    final p = reward.split(' ');
    if (p.length < 3) return '';
    final info = p[0] == 'BO'
        ? ItemDb.instance.byKey('BigCraftable', p[1])
        : ItemDb.instance.objectById(p[1]);
    return '${info?.name ?? p[1]} ×${p[2]}';
  }

  List<BundleRequirement> get requirements {
    if (_seg.length < 3) return [];
    final tokens = _seg[2].trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final out = <BundleRequirement>[];
    for (var i = 0; i + 2 < tokens.length; i += 3) {
      out.add(BundleRequirement(tokens[i], int.tryParse(tokens[i + 1]) ?? 1, int.tryParse(tokens[i + 2]) ?? 0));
    }
    return out;
  }

  int get requiredCount {
    final c = _seg.length > 4 ? int.tryParse(_seg[4]) : null;
    return c ?? requirements.length;
  }

  List<XmlElement> get _bools => submittedEl.childrenNamed('boolean').toList();

  bool isSubmitted(int i) {
    final b = _bools;
    return i < b.length && b[i].innerText.trim() == 'true';
  }

  void setSubmitted(int i, bool v) {
    var b = _bools;
    while (b.length <= i) {
      submittedEl.children.add(buildElement('boolean', false));
      b = _bools;
    }
    b[i].setOwnText(v ? 'true' : 'false');
  }

  int get submittedCount {
    var n = 0;
    for (var i = 0; i < requirements.length; i++) {
      if (isSubmitted(i)) n++;
    }
    return n;
  }

  bool get completed => submittedCount >= requiredCount;

  /// Marks the first [requiredCount] items submitted (or clears all).
  void setCompleted(bool v) {
    final reqs = requirements;
    for (var i = 0; i < reqs.length; i++) {
      setSubmitted(i, v && i < requiredCount);
    }
  }
}

/// Community Center bundle state plus the mail-flag side effects that make
/// the game treat rooms as restored.
class CommunityCenter {
  CommunityCenter._(this.save, this.cc, this.bundles);

  final SaveFile save;
  final XmlElement cc;
  final List<Bundle> bundles;

  static CommunityCenter? load(SaveFile save) {
    final cc = save.location('CommunityCenter');
    final ccBundles = cc?.child('bundles');
    final data = save.root.child('bundleData');
    if (cc == null || ccBundles == null || data == null) return null;

    final byIndex = <int, (XmlElement, XmlElement)>{};
    for (final item in data.childrenNamed('item')) {
      final k = item.path(['key', 'string']);
      final v = item.path(['value', 'string']);
      if (k == null || v == null) continue;
      final parts = k.innerText.split('/');
      final idx = int.tryParse(parts.length > 1 ? parts[1] : '');
      if (idx != null) byIndex[idx] = (k, v);
    }

    final list = <Bundle>[];
    for (final item in ccBundles.childrenNamed('item')) {
      final idx = int.tryParse(item.path(['key', 'int'])?.innerText ?? '');
      final arr = item.path(['value', 'ArrayOfBoolean']);
      final pair = idx == null ? null : byIndex[idx];
      if (pair == null || arr == null) continue;
      list.add(Bundle(pair.$1, pair.$2, arr));
    }
    list.sort((a, b) {
      final r = (a.room?.index ?? 99).compareTo(b.room?.index ?? 99);
      return r != 0 ? r : a.spriteIndex.compareTo(b.spriteIndex);
    });
    final center = CommunityCenter._(save, cc, list);
    center.sanitizeRewards();
    return center;
  }

  Map<CCRoom, List<Bundle>> get byRoom {
    final m = <CCRoom, List<Bundle>>{};
    for (final b in bundles) {
      final r = b.room;
      if (r != null) m.putIfAbsent(r, () => []).add(b);
    }
    return m;
  }

  bool get isJoja => save.mainPlayer.hasMail('JojaMember');

  void _mailAll(void Function(Set<String> mail) fn) {
    for (final p in save.players) {
      final before = p.mailReceived;
      final set = before.toSet();
      fn(set);
      final ordered = [...before.where(set.contains), ...set.where((f) => !before.contains(f))];
      p.el.setStringList('mailReceived', ordered);
    }
  }

  void _updateArea(CCRoom room, bool done) {
    final container = cc.ensure('areasComplete');
    var arr = container.childrenNamed('boolean').toList();
    final target = room == CCRoom.abandonedJojaMart ? 7 : (arr.length < 6 ? 6 : arr.length);
    while (arr.length < target) {
      container.children.add(buildElement('boolean', false));
      arr = container.childrenNamed('boolean').toList();
    }
    arr[room.index].setOwnText(done ? 'true' : 'false');
    arr = container.childrenNamed('boolean').toList();
    if (arr.length > 7) {
      for (final e in arr.sublist(7)) {
        container.children.remove(e);
      }
    }
    arr = container.childrenNamed('boolean').toList();
    if (arr.length == 7 && arr[6].innerText.trim() == 'false') container.children.remove(arr[6]);
  }

  /// Call after the user changes any bundle.
  void applySideEffects() {
    final rooms = byRoom;
    final done = {for (final e in rooms.entries) e.key: e.value.every((b) => b.completed)};
    done.forEach((room, complete) {
      _mailAll((mail) {
        if (complete) {
          mail.add(room.flag);
          final j = room.jojaFlag;
          if (j != null) {
            mail.contains('JojaMember') ? mail.add(j) : mail.remove(j);
          }
        } else {
          mail.remove(room.flag);
          if (room.jojaFlag != null) mail.remove(room.jojaFlag);
        }
      });
      _updateArea(room, complete);
    });

    final relevant = done.entries.where((e) => isJoja
        ? e.key != CCRoom.abandonedJojaMart && e.key != CCRoom.bulletinBoard
        : e.key != CCRoom.abandonedJojaMart);
    final overall = relevant.every((e) => e.value);
    _mailAll((mail) {
      if (overall) {
        mail.addAll(['ccIsComplete', 'ccBulletinThankYou', 'seenJunimoNote']);
        if (mail.contains('JojaMember')) {
          mail.remove('abandonedJojaMartAccessible');
        } else {
          mail.add('abandonedJojaMartAccessible');
        }
      } else {
        mail.removeAll(['ccIsComplete', 'ccBulletinThankYou', 'abandonedJojaMartAccessible']);
      }
    });
    sanitizeRewards();
  }

  /// Drops reward entries for unknown bundles and forces key 36 to false
  /// (a true value there crashes the game).
  void sanitizeRewards() {
    final rewards = cc.child('bundleRewards');
    final b = cc.child('bundles');
    if (rewards == null || b == null) return;
    final valid = b.childrenNamed('item').map((i) => i.path(['key', 'int'])?.innerText.trim()).toSet();
    for (final item in rewards.childrenNamed('item').toList()) {
      final k = item.path(['key', 'int'])?.innerText.trim();
      if (!valid.contains(k)) {
        rewards.children.remove(item);
      } else if (k == '36') {
        item.path(['value', 'boolean'])?.setOwnText('false');
      }
    }
  }
}
