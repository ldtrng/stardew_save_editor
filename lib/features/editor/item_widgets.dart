import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../l10n/names.dart';
import 'package:xml/xml.dart';

import '../../save/items.dart';
import '../../save/xml_ext.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

const _qualityLabels = {0: 'Normal', 1: 'Silver', 2: 'Gold', 4: 'Iridium'};
const _qualityColors = {1: Color(0xFFB8C4CC), 2: Color(0xFFF2C14E), 4: Color(0xFFB57EDC)};

/// One inventory / chest slot.
class ItemSlot extends StatelessWidget {
  const ItemSlot({super.key, required this.item, required this.onTap, this.label, this.size = 56});
  final ItemView? item;
  final VoidCallback onTap;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    final it = item;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: p.panelAlt,
          border: Border.all(color: p.woodDark, width: 2),
        ),
        child: Stack(children: [
          if (it != null) Center(child: ItemIcon(info: it.info, size: size * 0.7, tint: it.tint)),
          if (it == null && label != null)
            Center(
              child: Text(label!, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: p.textMuted)),
            ),
          if (it != null && it.isStackable && it.stack > 1)
            Positioned(
              right: 2,
              bottom: 0,
              child: Text('${it.stack}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: [Shadow(color: p.outline, offset: Offset(1, 1))],
                  )),
            ),
          if (it != null && it.hasQuality && it.quality > 0)
            Positioned(
              left: 2,
              bottom: 2,
              child: Icon(Icons.star, size: 14, color: _qualityColors[it.quality]),
            ),
        ]),
      ),
    );
  }
}

/// Grid of slots that wraps in rows of [perRow].
class SlotGrid extends StatelessWidget {
  const SlotGrid({super.key, required this.count, required this.itemAt, required this.onTap});
  final int count;
  final ItemView? Function(int) itemAt;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth > 700 ? 12 : 6;
      final size = (c.maxWidth - (perRow - 1) * 4) / perRow;
      return Wrap(spacing: 4, runSpacing: 4, children: [
        for (var i = 0; i < count; i++) ItemSlot(item: itemAt(i), size: size, onTap: () => onTap(i)),
      ]);
    });
  }
}

/// Searchable picker over every known item.
class ItemPickerSheet extends StatefulWidget {
  const ItemPickerSheet({super.key, this.allowedTypes, this.title = 'Add item'});
  final Set<String>? allowedTypes;
  final String title;

  static Future<ItemInfo?> show(BuildContext context, {Set<String>? allowedTypes, String title = 'Add item'}) =>
      showModalBottomSheet<ItemInfo>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ItemPickerSheet(allowedTypes: allowedTypes, title: title),
      );

  @override
  State<ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<ItemPickerSheet> {
  String _query = '';
  String _group = 'All';

  static const _groups = ['All', 'Object', 'BigCraftable', 'Furniture', 'Weapon', 'Tool', 'Hat', 'Clothing', 'Boots', 'Ring', 'Trinket'];
  static const _groupLabels = {'BigCraftable': 'Craftable', 'Object': 'Objects'};

  bool _allowed(ItemInfo i) {
    final a = widget.allowedTypes;
    if (a == null) return true;
    if (a.contains('Ring')) return i.isRing;
    return a.contains(i.type);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    final q = _query.toLowerCase();
    final items = ItemDb.instance.all
        .where((i) => _allowed(i) && i.sprite != null)
        .where((i) => _group == 'All' || i.group == _group)
        .where((i) => q.isEmpty || i.name.toLowerCase().contains(q) || editorItemName(i).toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => editorItemName(a).compareTo(editorItemName(b)));
    final groups = widget.allowedTypes == null ? _groups : <String>[];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      builder: (context, scroll) => Column(children: [
        Container(
          color: p.wood,
          padding: EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(children: [
            Expanded(child: Text(tr(widget.title), style: TextStyle(color: Colors.white, fontSize: 20))),
            IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: Colors.white)),
          ]),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            autofocus: false,
            decoration: InputDecoration(prefixIcon: Icon(Icons.search), hintText: tr('Search items')),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (groups.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final g in groups)
                  Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(tr(_groupLabels[g] ?? g)),
                      selected: _group == g,
                      onSelected: (_) => setState(() => _group = g),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: scroll,
            itemCount: items.length,
            itemBuilder: (context, i) {
              final it = items[i];
              return ListTile(
                leading: ItemIcon(info: it, size: 36),
                title: Text(editorItemName(it)),
                subtitle: Text(tr(_groupLabels[it.group] ?? it.group), style: TextStyle(color: p.textMuted, fontSize: 12)),
                onTap: () => Navigator.pop(context, it),
              );
            },
          ),
        ),
      ]),
    );
  }
}

enum ItemAction { replace, delete }

/// Bottom sheet that edits an item element in place.
class ItemEditorSheet extends StatefulWidget {
  const ItemEditorSheet({super.key, required this.item, required this.onChanged});
  final ItemView item;
  final VoidCallback onChanged;

  static Future<ItemAction?> show(BuildContext context, ItemView item, VoidCallback onChanged) =>
      showModalBottomSheet<ItemAction>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ItemEditorSheet(item: item, onChanged: onChanged),
      );

  @override
  State<ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<ItemEditorSheet> {
  ItemView get it => widget.item;

  void _edit(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    final info = it.info;
    final weaponStats = [
      ('minDamage', 'Min damage'),
      ('maxDamage', 'Max damage'),
      ('speed', 'Speed'),
      ('knockback', 'Knockback'),
      ('critChance', 'Crit chance'),
      ('critMultiplier', 'Crit power'),
      ('addedPrecision', 'Precision'),
      ('addedDefense', 'Defense'),
      ('addedAreaOfEffect', 'Area of effect'),
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            PixelPanel(padding: EdgeInsets.all(6), child: ItemIcon(info: info, size: 48, tint: it.tint)),
            SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.info != null && it.name == it.info!.name ? editorItemName(it.info!) : it.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                if (info?.description != null)
                  Text(info!.description!, style: TextStyle(color: p.textMuted, fontSize: 13)),
              ]),
            ),
          ]),
          if (it.hasQuality) ...[
            PlankHeader(tr('Quality')),
            Wrap(spacing: 6, children: [
              for (final q in _qualityLabels.entries)
                ChoiceChip(
                  avatar: q.key == 0 ? null : Icon(Icons.star, color: _qualityColors[q.key], size: 16),
                  label: Text(tr(q.value)),
                  selected: it.quality == q.key,
                  onSelected: (_) => _edit(() => it.quality = q.key),
                ),
            ]),
          ],
          if (it.isStackable) ...[
            PlankHeader(tr('Amount')),
            Row(children: [
              for (final n in [1, 10, 100, 999])
                Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: OutlinedButton(onPressed: () => _edit(() => it.stack = n), child: Text('$n')),
                ),
              SizedBox(width: 4),
              Expanded(child: NumberField(label: tr('Stack'), value: it.stack, min: 1, max: 999999, onChanged: (v) => _edit(() => it.stack = v))),
            ]),
          ],
          if (it.isObject && it.price != null) ...[
            PlankHeader(tr('Value')),
            Row(children: [
              Expanded(child: NumberField(label: tr('Sell price'), value: it.price ?? 0, max: 99999, onChanged: (v) => _edit(() => it.price = v))),
              SizedBox(width: 10),
              if (it.edibility != null)
                Expanded(
                    child: NumberField(label: tr('Edibility'), value: it.edibility!, min: -300, max: 9999, onChanged: (v) => _edit(() => it.edibility = v))),
            ]),
          ],
          if (it.isWeapon) ...[
            PlankHeader(tr('Weapon stats')),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final (key, label) in weaponStats)
                SizedBox(
                  width: 150,
                  child: _NumField(
                    label: label,
                    value: it.stat(key) ?? 0,
                    onChanged: (v) => _edit(() => it.setStat(key, v)),
                  ),
                ),
            ]),
          ],
          if (it.upgradeLevel != null && ['Pickaxe', 'Axe', 'Hoe', 'WateringCan', 'FishingRod', 'Pan'].contains(it.xsiType)) ...[
            PlankHeader(tr('Upgrade level')),
            Wrap(spacing: 6, children: [
              for (final (lvl, name) in it.xsiType == 'FishingRod'
                  ? [(0, 'Bamboo'), (1, 'Training'), (2, 'Fiberglass'), (3, 'Iridium'), (4, 'Adv. Iridium')]
                  : [(0, 'Basic'), (1, 'Copper'), (2, 'Steel'), (3, 'Gold'), (4, 'Iridium')])
                ChoiceChip(
                  label: Text(tr(name)),
                  selected: it.upgradeLevel == lvl,
                  onSelected: (_) => _edit(() {
                    it.upgradeLevel = lvl;
                    if (it.xsiType == 'FishingRod') {
                      it.el.setInt('numAttachmentSlots', lvl >= 3 ? 2 : (lvl == 2 ? 1 : 0));
                    }
                  }),
                ),
            ]),
          ],
          SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, ItemAction.replace),
                icon: Icon(Icons.swap_horiz),
                label: Text(tr('Replace')),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: p.berry),
                onPressed: () => Navigator.pop(context, ItemAction.delete),
                icon: Icon(Icons.delete_outline),
                label: Text(tr('Remove')),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _NumField extends StatefulWidget {
  const _NumField({required this.label, required this.value, required this.onChanged});
  final String label;
  final num value;
  final ValueChanged<num> onChanged;
  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final _c = TextEditingController(text: '${widget.value}');
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(labelText: widget.label),
        onChanged: (v) {
          final n = num.tryParse(v);
          if (n != null) widget.onChanged(n);
        },
      );
}

/// Shared flow: tap a slot → edit existing item or pick a new one.
Future<void> handleSlotTap({
  required BuildContext context,
  required ItemView? current,
  required void Function(XmlElement? item) set,
  required VoidCallback changed,
  String tag = 'Item',
  Set<String>? allowedTypes,
}) async {
  if (current == null) {
    final info = await ItemPickerSheet.show(context, allowedTypes: allowedTypes);
    if (info == null) return;
    set(ItemFactory.create(info, tag: tag));
    changed();
    return;
  }
  final action = await ItemEditorSheet.show(context, current, changed);
  if (!context.mounted) return;
  if (action == ItemAction.delete) {
    set(null);
    changed();
  } else if (action == ItemAction.replace) {
    final info = await ItemPickerSheet.show(context, allowedTypes: allowedTypes, title: tr('Replace with…'));
    if (info == null) return;
    set(ItemFactory.create(info, tag: tag));
    changed();
  }
}
