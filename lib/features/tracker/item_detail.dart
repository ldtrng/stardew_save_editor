import 'package:flutter/material.dart';

import '../../ads/ads_service.dart';
import '../../l10n/l10n.dart';
import '../../l10n/names.dart';
import 'collections.dart' show bundleUsage;

import '../../data/game_data.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../villagers/villager_detail.dart';
import 'collection_screen.dart';
import 'tracker_widgets.dart';

/// Reverse indexes: where an item is used / who likes it.
class BundleRef {
  const BundleRef(this.key, this.name, this.room, this.remixed);
  final String key, name, room;
  final bool remixed;
}

class ItemUsage {
  ItemUsage._();
  static ItemUsage? _i;
  static ItemUsage get i => _i ??= ItemUsage._().._build();

  final Map<String, List<BundleRef>> bundleRefs = {};
  final Map<String, List<Json>> cooking = {};
  final Map<String, List<Json>> crafting = {};
  final Map<String, Map<String, List<String>>> gifts = {}; // id -> level -> villagers

  void _build() {
    final gd = GameData.i;
    for (final set in ['normal', 'remixed']) {
      for (final room in (gd.bundles[set] as List)) {
        for (final b in ((room as Map)['bundles'] as List)) {
          for (final it in ((b as Map)['items'] as List)) {
            final id = (it as Map)['id']?.toString();
            if (id == null) continue;
            final l = bundleRefs.putIfAbsent(id, () => []);
            if (!l.any((x) => x.key == b['key'])) {
              l.add(BundleRef(b['key'].toString(), b['name'].toString(), room['name'].toString(), set == 'remixed'));
            }
          }
        }
      }
    }
    for (final r in gd.cooking) {
      for (final ing in (r['ingredients'] as List? ?? [])) {
        final id = ((ing as Map)['id'] ?? ing['displayItemId'])?.toString();
        if (id != null) cooking.putIfAbsent(id, () => []).add(r);
      }
    }
    for (final r in gd.craftingRecipes) {
      for (final ing in (r['ingredients'] as List? ?? [])) {
        final id = (ing as Map)['id']?.toString();
        if (id != null) crafting.putIfAbsent(id, () => []).add(r);
      }
    }
    for (final v in gd.villagers) {
      final g = v['gifts'] as Map?;
      if (g == null) continue;
      for (final level in ['love', 'like', 'neutral', 'dislike', 'hate']) {
        for (final it in ((g[level] as Map?)?['items'] as List? ?? [])) {
          final id = (it as Map)['id']?.toString();
          if (id == null) continue;
          gifts.putIfAbsent(id, () => {}).putIfAbsent(level, () => []).add(v['name'] as String);
        }
      }
    }
  }
}

const qualityNames = ['Normal', 'Silver', 'Gold', 'Iridium'];
const _qualityMul = [1.0, 1.25, 1.5, 2.0];
const _energyMul = [1.0, 1.4, 1.8, 2.6];

class PriceTable extends StatelessWidget {
  const PriceTable({super.key, required this.price, this.edibility, this.bonus = 1.0});
  final int price;
  final int? edibility;
  final double bonus;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    final edible = edibility != null && edibility != -300;
    TableRow row(List<String> cells, {bool header = false}) => TableRow(
          decoration: header ? BoxDecoration(color: p.wood) : null,
          children: [
            for (final c in cells)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                child: Text(c,
                    style: TextStyle(
                      color: header ? Colors.white : p.text,
                      fontWeight: header ? FontWeight.w600 : FontWeight.normal,
                    )),
              ),
          ],
        );
    return Table(
      border: TableBorder.all(color: p.outline, width: 1.5),
      children: [
        row([tr('Quality'), tr('Sell'), if (edible) tr('Energy'), if (edible) tr('Health')], header: true),
        for (var q = 0; q < 4; q++)
          row([
            tr(qualityNames[q]),
            '${(price * bonus * _qualityMul[q]).floor()}g',
            if (edible) '${(edibility! * 2.5 * _energyMul[q]).round()}',
            if (edible) '${((edibility! * 2.5 * _energyMul[q]).round() * 0.45).floor()}',
          ]),
      ],
    );
  }
}

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key, required this.item, this.category, this.checkId});
  final Json item;
  final String? category;
  final String? checkId;

  static Widget? forId(String id, {String? category}) {
    final it = GameData.i.itemsById[id];
    if (it == null) return null;
    return ItemDetailScreen(item: it, category: category, checkId: id);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    final id = item['id'].toString();
    final usage = ItemUsage.i;
    final price = (item['price'] as num?)?.toInt() ?? 0;
    final edibility = (item['edibility'] as num?)?.toInt();
    final locs = (item['locations'] as List? ?? []).cast<Map>();
    final buffs = (item['buffs'] as List? ?? []).cast<Map>();
    final name = objectName(item);
    return DetailScaffold(title: name, children: [
      DetailHeader(
        item: item,
        category: category,
        id: checkId,
        name: name,
        description: objectDescription(item),
        extra: item['categoryName'] != null ? PixelTag(tr(item['categoryName'].toString())) : null,
      ),
      if (price > 0) ...[PlankHeader(tr('Sell price')), PriceTable(price: price, edibility: edibility)],
      if (buffs.isNotEmpty) ...[
        PlankHeader(tr('Buffs')),
        for (final b in buffs) BuffView(buff: b),
      ],
      if (locs.isNotEmpty) ...[
        PlankHeader(tr('Where to find')),
        for (final l in locs) LocationTile(loc: l),
      ],
      if (bundleUsage(id).isNotEmpty) ...[
        PlankHeader(tr('Bundles')),
        for (final s in bundleUsage(id)) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• $s')),
      ],
      if ((usage.cooking[id] ?? usage.crafting[id]) != null) ...[
        PlankHeader(tr('Used in recipes')),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final r in [...?usage.cooking[id], ...?usage.crafting[id]])
            ItemRefChip(ref: {'name': recipeName(r), 'image': r['image']}),
        ]),
      ],
      if (usage.gifts[id] case final g?) ...[
        PlankHeader(tr('Gift reactions')),
        for (final level in ['love', 'like', 'neutral', 'dislike', 'hate'])
          if (g[level] case final names?)
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 70, child: Text(tr(cap(level)), style: TextStyle(color: p.textMuted))),
                Expanded(
                  child: Wrap(spacing: 4, runSpacing: 4, children: [
                    for (final n in names)
                      ItemRefChip(
                        ref: {'name': villagerName(n), 'image': GameData.i.villager(n)?['image']},
                        onTap: () {
                          final v = GameData.i.villager(n);
                          if (v != null) {
                            AdsService.instance.onDetailViewed();
                            Navigator.push(context, MaterialPageRoute(builder: (_) => VillagerDetail(villager: v)));
                          }
                        },
                      ),
                  ]),
                ),
              ]),
            ),
      ],
    ]);
  }
}

class BuffView extends StatelessWidget {
  const BuffView({super.key, required this.buff});
  final Map buff;
  @override
  Widget build(BuildContext context) {
    final attrs = (buff['attributes'] as Map? ?? {}).entries.where((e) => (e.value as num) != 0).toList();
    final dur = buff['duration'];
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Wrap(spacing: 6, runSpacing: 4, children: [
        for (final a in attrs) PixelTag('${_buffName(a.key.toString())} ${(a.value as num) > 0 ? '+' : ''}${a.value}'),
        if (dur != null) PixelTag('⏱ ${_duration(dur as num)}'),
      ]),
    );
  }

  static String _buffName(String k) =>
      tr(k.replaceAll('Level', '').replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}'));
  static String _duration(num minutes) {
    final m = minutes.toInt();
    if (m >= 60) return '${m ~/ 60}h ${m % 60}m';
    return '${m}m';
  }
}

class LocationTile extends StatelessWidget {
  const LocationTile({super.key, required this.loc});
  final Map loc;
  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    final seasons = (loc['seasons'] as List? ?? []);
    final times = (loc['time'] as List? ?? []).cast<List>();
    final weather = loc['weather']?.toString();
    final chance = (loc['chance'] as num?)?.toDouble();
    return Container(
      margin: EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(color: p.panelAlt, border: Border.all(color: p.outline.withValues(alpha: 0.5), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(tr((loc['displayLocationName'] ?? loc['location']).toString()),
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (loc['methodName'] != null) PixelTag(tr(cap(loc['methodName'].toString()))),
        ]),
        SizedBox(height: 4),
        Wrap(spacing: 4, runSpacing: 4, children: [
          SeasonBadges(seasons),
          if (weather != null && weather != 'both') PixelTag(weather == 'rainy' ? '🌧 ${tr('Rain')}' : '☀️ ${tr('Sun')}'),
          for (final t in times)
            if (t.length == 2) PixelTag('${gameTime((t[0] as num).toInt())} – ${gameTime((t[1] as num).toInt())}'),
          if (chance != null && chance < 1) PixelTag('${(chance * 100).toStringAsFixed(chance < 0.01 ? 2 : 0)}%'),
          if ((loc['minFishingLevel'] as num? ?? 0) > 0) PixelTag(tr('Fishing Lv {n}', {'n': loc['minFishingLevel']})),
        ]),
      ]),
    );
  }
}
