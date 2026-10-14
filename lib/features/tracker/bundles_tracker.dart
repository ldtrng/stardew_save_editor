import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../l10n/names.dart';
import 'package:provider/provider.dart';

import '../../ads/banner_ad.dart';
import '../../data/game_data.dart';
import '../../state/tracker_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'item_detail.dart';
import 'tracker_widgets.dart';

List<Json> bundleRooms(bool remixed) =>
    (GameData.i.bundles[remixed ? 'remixed' : 'normal'] as List).cast<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

int bundleDone(TrackerState t, Map b) {
  final items = (b['items'] as List).length;
  var n = 0;
  for (var i = 0; i < items; i++) {
    if (t.isChecked(Cat.bundleItems, '${b['key']}#$i')) n++;
  }
  return n;
}

bool bundleComplete(TrackerState t, Map b) => bundleDone(t, b) >= ((b['numOfItems'] as num?)?.toInt() ?? (b['items'] as List).length);

class BundlesTrackerScreen extends StatelessWidget {
  const BundlesTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TrackerState>();
    final remixed = t.farm.remixedBundles;
    final rooms = bundleRooms(remixed);
    final all = [for (final r in rooms) ...(r['bundles'] as List).cast<Map>()];
    final done = all.where((b) => bundleComplete(t, b)).length;
    final p = context.farm;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Bundles'))),
      bottomNavigationBar: SafeArea(child: AdBanner()),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          ProgressHeader(done: done, total: all.length, label: '${tr('Bundles')} '),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('Remixed Bundles')),
            subtitle: Text(tr('Use if you picked "Remixed" bundles when creating the farm.'), style: TextStyle(color: p.textMuted, fontSize: 12)),
            value: remixed,
            onChanged: t.setRemixed,
          ),
          for (final room in rooms) ...[
            PlankHeader(
              '${tr(room['name'].toString())}  ${(room['bundles'] as List).where((b) => bundleComplete(t, b as Map)).length}/${(room['bundles'] as List).length}',
            ),
            if (room['reward'] != null)
              Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(tr(room['reward'].toString()), style: TextStyle(color: p.textMuted, fontSize: 13)),
              ),
            for (final b in (room['bundles'] as List).cast<Map>()) ...[
              _BundleCard(bundle: b),
              SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _BundleCard extends StatelessWidget {
  const _BundleCard({required this.bundle});
  final Map bundle;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TrackerState>();
    final p = context.farm;
    final items = (bundle['items'] as List).cast<Map>();
    final need = (bundle['numOfItems'] as num?)?.toInt() ?? items.length;
    final got = bundleDone(t, bundle);
    final complete = got >= need;
    final reward = bundle['reward'] as Map?;
    return PixelPanel(
      padding: EdgeInsets.zero,
      color: complete ? p.grass.withValues(alpha: 0.18) : null,
      child: ExpansionTile(
        shape: Border(),
        collapsedShape: Border(),
        leading: TImage(bundle['image'], size: 40),
        title: Text(bundleName(bundle), style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$got/$need${reward != null ? ' · ${tr('Reward: {item}', {'item': ItemRefChip.label(reward)})}${(reward['amount'] as num? ?? 1) > 1 ? ' ×${reward['amount']}' : ''}' : ''}',
            style: TextStyle(fontSize: 12, color: p.textMuted)),
        trailing: complete ? Icon(Icons.check_circle, color: p.grassDark) : null,
        children: [
          if (items.length > need)
            Padding(
              padding: EdgeInsets.only(left: 16, bottom: 4),
              child: Text(tr('Any {need} of {total}', {'need': need, 'total': items.length}), style: TextStyle(color: p.textMuted, fontSize: 12)),
            ),
          for (var i = 0; i < items.length; i++)
            InkWell(
              onTap: items[i]['id'] == null
                  ? null
                  : () {
                      final s = ItemDetailScreen.forId(items[i]['id'].toString());
                      if (s != null) Navigator.push(context, MaterialPageRoute(builder: (_) => s));
                    },
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 2, 4, 2),
                child: Row(children: [
                  if (items[i]['gold'] != null)
                    Icon(Icons.monetization_on, color: p.wheat, size: 30)
                  else
                    TImage(items[i]['image'], size: 30),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${ItemRefChip.label(items[i])}${(items[i]['amount'] as num? ?? 1) > 1 ? ' ×${items[i]['amount']}' : ''}'),
                      if ((items[i]['quality'] as num? ?? 0) > 0)
                        Text(tr('{quality} quality or better', {'quality': tr(qualityNames[(items[i]['quality'] as num).toInt().clamp(0, 3)])}),
                            style: TextStyle(fontSize: 11, color: p.textMuted)),
                    ]),
                  ),
                  PixelCheck(
                    value: t.isChecked(Cat.bundleItems, '${bundle['key']}#$i'),
                    onChanged: (v) => t.toggle(Cat.bundleItems, '${bundle['key']}#$i', v),
                  ),
                ]),
              ),
            ),
          SizedBox(height: 6),
        ],
      ),
    );
  }
}
