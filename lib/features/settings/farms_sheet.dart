import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../ads/ads_service.dart';
import '../../state/tracker_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

Future<void> showFarmsSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => FarmsSheet(),
    );

class FarmsSheet extends StatelessWidget {
  const FarmsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TrackerState>();
    final p = context.farm;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('Farms'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        Text(tr('Each farm keeps its own checklists, notes and date.'), style: TextStyle(color: p.textMuted)),
        SizedBox(height: 10),
        for (final f in t.farms)
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: PixelPanel(
              padding: EdgeInsets.fromLTRB(10, 4, 4, 4),
              color: f.id == t.farm.id ? p.wheat.withValues(alpha: 0.45) : null,
              onTap: () {
                final changed = f.id != t.farm.id;
                t.selectFarm(f.id);
                Navigator.pop(context);
                if (changed) AdsService.instance.onTaskDone('farm_switched');
              },
              child: Row(children: [
                Icon(f.id == t.farm.id ? Icons.radio_button_checked : Icons.radio_button_off, color: p.woodDark),
                SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    Text('${tr('Year {n}', {'n': f.year})}${f.remixedBundles ? ' · ${tr('Remixed bundles')}' : ''}',
                        style: TextStyle(fontSize: 12, color: p.textMuted)),
                  ]),
                ),
                IconButton(icon: Icon(Icons.edit_outlined), onPressed: () => editFarmDialog(context, f)),
              ]),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => editFarmDialog(context, null),
          icon: Icon(Icons.add),
          label: Text(tr('Create new farm')),
        ),
      ]),
    );
  }
}

Future<void> editFarmDialog(BuildContext context, FarmProfile? farm) async {
  final t = context.read<TrackerState>();
  final ctrl = TextEditingController(text: farm?.name ?? '');
  var remixed = farm?.remixedBundles ?? false;
  await showDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => AlertDialog(
        title: Text(farm == null ? tr('New farm') : tr('Edit farm')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ctrl, autofocus: true, maxLength: 30, decoration: InputDecoration(labelText: tr('Farm name'))),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('Remixed Bundles')),
            value: remixed,
            onChanged: (v) => setS(() => remixed = v),
          ),
          if (farm != null && t.farms.length > 1)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: context.farm.berry),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: c,
                  builder: (d) => AlertDialog(
                    title: Text(tr('Delete this farm')),
                    content: Text(tr('This will remove all your progress for this farm. This action is irreversible.')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Cancel'))),
                      FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Delete'))),
                    ],
                  ),
                );
                if (ok == true) {
                  t.deleteFarm(farm);
                  if (c.mounted) Navigator.pop(c);
                }
              },
              icon: Icon(Icons.delete_outline),
              label: Text(tr('Delete this farm')),
            ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Cancel'))),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              if (farm == null) {
                final f = t.addFarm(name);
                if (remixed) t.setRemixed(true);
                t.selectFarm(f.id);
                AdsService.instance.onTaskDone('farm_created');
              } else {
                t.renameFarm(farm, name);
                if (farm.remixedBundles != remixed) {
                  farm.remixedBundles = remixed;
                  t.updateNote();
                }
              }
              Navigator.pop(c);
            },
            child: Text(tr('Save')),
          ),
        ],
      ),
    ),
  );
}
