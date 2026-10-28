import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:provider/provider.dart';


import '../../save/chests.dart';
import '../../state/editor_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'item_widgets.dart';

const _kindIcons = {
  ChestKind.chest: Icons.inventory_2_outlined,
  ChestKind.fridge: Icons.kitchen_outlined,
  ChestKind.machine: Icons.precision_manufacturing_outlined,
  ChestKind.building: Icons.warehouse_outlined,
};

class ChestsScreen extends StatefulWidget {
  const ChestsScreen({super.key});
  @override
  State<ChestsScreen> createState() => _ChestsScreenState();
}

class _ChestsScreenState extends State<ChestsScreen> {
  List<ChestRef>? _chests;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final save = state.save;
    if (save == null) return SizedBox();
    final chests = _chests ??= save.discoverChests();
    final p = context.farm;
    final q = _query.toLowerCase();
    final filtered = chests.where((c) => q.isEmpty || c.label.toLowerCase().contains(q)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Chests ({n})', {'n': chests.length}))),
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(prefixIcon: Icon(Icons.search), hintText: tr('Filter by location or name')),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(icon: Icons.inventory_2_outlined, title: tr('No chests found'))
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = filtered[i];
                    return PixelPanel(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ChestDetail(chest: c))),
                      child: Row(children: [
                        Icon(_kindIcons[c.kind], color: p.woodDark, size: 30),
                        SizedBox(width: 10),
                        Expanded(child: Text(c.label)),
                        PixelTag('${c.usedSlots}/${c.capacity}'),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _ChestDetail extends StatelessWidget {
  const _ChestDetail({required this.chest});
  final ChestRef chest;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final slots = chest.slots;
    return Scaffold(
      appBar: AppBar(title: Text(chest.label, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          SlotGrid(
            count: slots.length,
            itemAt: (i) => slots[i],
            onTap: (i) => handleSlotTap(
              context: context,
              current: slots[i],
              set: (item) => chest.setSlot(i, item),
              changed: state.changed,
            ),
          ),
        ],
      ),
    );
  }
}
