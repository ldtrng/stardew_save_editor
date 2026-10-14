import 'package:xml/xml.dart';

import 'items.dart';
import 'save_file.dart';
import 'xml_ext.dart';

enum ChestKind { chest, fridge, machine, building }

/// An item container found somewhere in the world. Chests store a compact item
/// list (no nil slots), so edits rewrite only that chest's `items` element.
class ChestRef {
  ChestRef(this.el, {required this.label, required this.kind, required this.location});

  final XmlElement el;
  final String label;
  final ChestKind kind;
  final String location;

  int get capacity {
    final name = el.str('name')?.toLowerCase();
    final special = el.str('specialChestType')?.toLowerCase();
    if (name == 'big chest' || special == 'bigchest') return 70;
    if (name == 'mini-shipping bin' || special == 'minishippingbin') return 9;
    return 36;
  }

  List<XmlElement> get _rawItems {
    final items = el.child('items');
    if (items == null) return [];
    return items.childrenNamed('Item').where((e) => !e.isNil).toList();
  }

  int get slotCount {
    final n = _rawItems.length;
    return n > capacity ? n : capacity;
  }

  int get usedSlots => _rawItems.length;

  List<ItemView?> get slots {
    final raw = _rawItems;
    return List.generate(slotCount, (i) => i < raw.length ? ItemView(raw[i]) : null);
  }

  /// Replaces slot [index] and compacts the list the way the game stores it.
  void setSlot(int index, XmlElement? item) {
    final current = slots.map((v) => v?.el).toList();
    while (current.length <= index) {
      current.add(null);
    }
    current[index] = item == null ? null : ItemFactory.retag(item, 'Item');
    final items = el.ensure('items');
    items.children.clear();
    for (final e in current.whereType<XmlElement>()) {
      items.children.add(e.parent == null ? e : e.copy());
    }
  }

  static bool _isChest(XmlElement? e) {
    if (e == null || e.isNil) return false;
    if (e.xsiType == 'Chest') return true;
    return e.child('items') != null &&
        (e.child('playerChest') != null || e.child('fridge') != null || e.child('specialChestType') != null);
  }

  static List<ChestRef> discover(SaveFile save) {
    final result = <ChestRef>[];
    final seen = <XmlElement>{};

    void add(XmlElement? chest, String label, ChestKind kind, String location) {
      if (!_isChest(chest) || seen.contains(chest)) return;
      seen.add(chest!);
      result.add(ChestRef(chest, label: label, kind: kind, location: location));
    }

    void visit(XmlElement loc, String area) {
      final name = loc.str('uniqueName') ?? loc.str('name') ?? area;
      add(loc.child('fridge'), '$area – Fridge', ChestKind.fridge, name);

      final objects = loc.child('objects');
      if (objects != null) {
        for (final entry in objects.childrenNamed('item')) {
          final obj = entry.path(['value', 'Object']);
          if (obj == null) continue;
          final v = entry.path(['key', 'Vector2']);
          final tile = v == null ? '' : ' (${v.str('X')}, ${v.str('Y')})';
          final objName = obj.str('name') ?? 'Chest';
          add(obj, '$area – $objName$tile', ChestKind.chest, name);
          add(obj.child('heldObject'), '$area – $objName$tile', ChestKind.machine, name);
        }
      }

      final buildings = loc.child('buildings');
      if (buildings != null) {
        for (final b in buildings.childrenNamed('Building')) {
          final bName = b.str('buildingType') ?? 'Building';
          final chests = b.child('buildingChests');
          if (chests != null) {
            var i = 0;
            for (final c in chests.childrenNamed('Chest')) {
              i++;
              add(c, '$area / $bName – ${c.str('name') ?? 'Chest $i'}', ChestKind.building, name);
            }
          }
          final indoors = b.child('indoors');
          if (indoors != null && !indoors.isNil) visit(indoors, '$area / $bName');
        }
      }
    }

    for (final loc in save.locations) {
      visit(loc, loc.str('uniqueName') ?? loc.str('name') ?? 'Location');
    }
    return result;
  }
}
