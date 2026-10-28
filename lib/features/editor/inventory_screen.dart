import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:provider/provider.dart';


import '../../save/farmer.dart';
import '../../state/editor_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'farmer_preview.dart';
import 'item_widgets.dart';

const _slotLabels = {
  'hat': 'Hat',
  'shirtItem': 'Shirt',
  'pantsItem': 'Pants',
  'boots': 'Boots',
  'leftRing': 'Ring L',
  'rightRing': 'Ring R',
  'trinketItem': 'Trinket',
};

const _slotPickerTypes = {
  'hat': {'Hat'},
  'shirtItem': {'Shirt'},
  'pantsItem': {'Pants'},
  'boots': {'Boots'},
  'leftRing': {'Ring'},
  'rightRing': {'Ring'},
  'trinketItem': {'Trinket'},
};

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final f = state.player;
    if (f == null) return SizedBox();
    final p = context.farm;
    final slots = f.itemSlots.length;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Inventory'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          PlankHeader(tr('Equipment')),
          PixelPanel(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FarmerPreview(farmer: f, scale: 3.5),
              SizedBox(width: 12),
              Expanded(
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final slot in equipmentSlots)
                    if (slot != 'trinketItem' || f.trinketSlots > 0 || f.equipment(slot) != null)
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        ItemSlot(
                          item: f.equipment(slot),
                          label: tr(_slotLabels[slot]!),
                          size: 52,
                          onTap: () => handleSlotTap(
                            context: context,
                            current: f.equipment(slot),
                            set: (item) => f.setEquipment(slot, item),
                            changed: state.changed,
                            tag: slot,
                            allowedTypes: _slotPickerTypes[slot],
                          ),
                        ),
                        Text(tr(_slotLabels[slot]!), style: TextStyle(fontSize: 11, color: p.textMuted)),
                      ]),
                ]),
              ),
            ]),
          ),
          PlankHeader(
            tr('Backpack ({n} slots)', {'n': slots}),
            trailing: PopupMenuButton<int>(
              icon: Icon(Icons.tune, color: Colors.white),
              tooltip: tr('Backpack size'),
              onSelected: (size) {
                f.setBackpackSize(size);
                state.changed();
              },
              itemBuilder: (_) => [
                for (final s in [12, 24, 36]) PopupMenuItem(value: s, child: Text('$s slots')),
              ],
            ),
          ),
          SlotGrid(
            count: slots,
            itemAt: f.itemAt,
            onTap: (i) => handleSlotTap(
              context: context,
              current: f.itemAt(i),
              set: (item) => f.setItemAt(i, item),
              changed: state.changed,
            ),
          ),
          SizedBox(height: 10),
          Text(tr('Tap an empty slot to add an item, or a filled one to edit it.'),
              style: TextStyle(fontSize: 12, color: p.textMuted)),
        ],
      ),
    );
  }
}
