import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ads/ads_service.dart';
import '../../data/game_data.dart';
import '../../l10n/l10n.dart';
import '../../state/tracker_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'bundles_tracker.dart';
import 'collections.dart';
import 'tracker_widgets.dart';

class _Entry {
  const _Entry(this.title, this.image, this.builder, {this.progress});
  final String title;
  final Object? image;
  final WidgetBuilder builder;
  final (int, int) Function(TrackerState)? progress;
}

class CollectionsHub extends StatelessWidget {
  const CollectionsHub({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TrackerState>();
    final gd = GameData.i;
    String? img(String id) => gd.itemsById[id]?['image'] as String?;
    (int, int) cnt(String cat, int total) => (t.count(cat).clamp(0, total), total);
    final entries = [
      _Entry(tr('Bundles'), 'src_assets_bundles_spring_crops_bundle', (_) => BundlesTrackerScreen(), progress: (t) {
        final all = [for (final r in bundleRooms(t.farm.remixedBundles)) ...(r['bundles'] as List).cast<Map>()];
        return (all.where((b) => bundleComplete(t, b)).length, all.length);
      }),
      _Entry(tr('Fish'), img('128'), (_) => FishScreen(), progress: (_) => cnt(Cat.fish, gd.fish.length)),
      _Entry(tr('Crops'), img('24'), (_) => CropsScreen(),
          progress: (_) => cnt(Cat.crops, gd.crops.where((c) => c['inAllCropsList'] != false).length)),
      _Entry(tr('Cooking'), img('194'), (_) => CookingScreen(), progress: (_) => cnt(Cat.cooked, gd.cooking.length)),
      _Entry(tr('Crafting'), img('286'), (_) => CraftingScreen(), progress: (_) => cnt(Cat.crafted, gd.craftingRecipes.length)),
      _Entry(tr('Museum'), img('96'), (_) => MuseumScreen(),
          progress: (_) => cnt(Cat.museum, gd.artifacts.length + gd.minerals.length)),
      _Entry(tr('Shipping'), 'src_assets_32pxshippingbox', (_) => ShippingScreen(), progress: (_) => cnt(Cat.shipped, gd.shipping.length)),
      _Entry(tr('Golden Walnuts'), img('73'), (_) => WalnutsScreen(), progress: (t) {
        var n = 0;
        for (final w in gd.walnuts) {
          if (t.isChecked(Cat.walnuts, w['id'].toString())) n += (w['quantity'] as num).toInt();
        }
        return (n, gd.walnuts.fold<int>(0, (s, w) => s + (w['quantity'] as num).toInt()));
      }),
      _Entry(tr('Stardrops'), img('434'), (_) => StardropsScreen(), progress: (_) => cnt(Cat.stardrops, gd.stardrops.length)),
      _Entry(tr('Wearables'), gd.wearables.firstWhere((w) => w['kind'] == 'hat')['image'], (_) => WearablesScreen(),
          progress: (_) => cnt(Cat.wearables, gd.wearables.length)),
      _Entry(tr('Monsters'), img('766'), (_) => MonstersScreen(), progress: (_) => cnt(Cat.monsters, gd.monsters.length)),
      _Entry(tr("Carpenter's Shop"), 'src_assets_villagers_robin_icon', (_) => BuildingsRefScreen(builder: 'Robin')),
      _Entry(tr("Wizard's Tower"), 'src_assets_villagers_wizard_icon', (_) => BuildingsRefScreen(builder: 'Wizard')),
    ];
    final p = context.farm;
    return Scaffold(
      appBar: AppBar(title: Text('${tr('Collections')} · ${t.farm.name}')),
      body: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 600 ? 3 : 2;
        return GridView.count(
          padding: EdgeInsets.all(16),
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: [
            for (final e in entries)
              Builder(builder: (context) {
                final prog = e.progress?.call(t);
                return PixelPanel(
                  padding: EdgeInsets.all(10),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: e.builder))
                      .then((_) => AdsService.instance.onCollectionClosed()),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      TImage(e.image, size: 40),
                      Spacer(),
                      if (prog != null && prog.$1 >= prog.$2 && prog.$2 > 0) Icon(Icons.emoji_events, color: p.wheat),
                    ]),
                    Spacer(),
                    Text(e.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    if (prog != null) ...[
                      SizedBox(height: 4),
                      ProgressHeader(done: prog.$1, total: prog.$2),
                    ],
                  ]),
                );
              }),
          ],
        );
      }),
    );
  }
}
