import 'package:flutter/material.dart';

import '../../data/game_data.dart';
import '../../l10n/l10n.dart';
import '../../l10n/names.dart';
import '../../state/tracker_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'collection_screen.dart';
import 'item_detail.dart';
import 'tracker_widgets.dart';

String _id(Json j) => j['id'].toString();
int _n(Object? v) => (v as num?)?.toInt() ?? 0;

int Function(Json, Json) _byName(String Function(Json) name) => (a, b) => name(a).compareTo(name(b));

String _times(Json f) {
  final t = (f['time'] as List? ?? const []).cast<List>();
  if (t.isEmpty) return tr('Any time');
  return t.map((r) => '${gameTime(_n(r[0]))}–${gameTime(_n(r[1]))}').join(', ');
}

String _weatherName(String? w) => switch (w) {
      'sunny' => tr('Sunny'),
      'rainy' => tr('Rainy'),
      _ => tr('Any'),
    };

/// Bundle list lines ("Spring Crops (Pantry)") in the current language.
List<String> bundleUsage(String id) => [
      for (final u in ItemUsage.i.bundleRefs[id] ?? const <BundleRef>[])
        '${L10n.i.bundleName(u.key, u.name)} (${tr(u.room)}${u.remixed ? ', ${tr('remixed')}' : ''})',
    ];

// ---------------- Fish ----------------
class FishScreen extends StatelessWidget {
  const FishScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final fish = GameData.i.fish;
    return CollectionScreen(
      title: tr('Fish'),
      items: fish,
      idOf: _id,
      nameOf: objectName,
      category: Cat.fish,
      subtitle: (f) => Text(f['type'] == 'crabpot'
          ? '${tr('Crab pot')} · ${tr(cap((f['trapLocation'] ?? '').toString()))}'
          : '${seasonsText(f['seasons'] as List?)} · ${_times(f)}${f['weather'] != null && f['weather'] != 'both' ? ' · ${f['weather'] == 'rainy' ? '🌧' : '☀️'}' : ''}'),
      filters: [
        CollectionFilter(tr('Season'), seasons, (f, v) => (f['seasons'] as List? ?? const []).contains(v), optionLabel: (v) => seasonName(v!)),
        CollectionFilter(tr('Weather'), const ['sunny', 'rainy'],
            (f, v) => f['weather'] == null || f['weather'] == 'both' || f['weather'] == v,
            optionLabel: _weatherName),
        CollectionFilter(tr('Type'), const ['rod', 'crabpot'], (f, v) => f['type'] == v,
            optionLabel: (v) => v == 'crabpot' ? tr('Crab pot') : tr('Fishing rod')),
      ],
      sorts: [
        CollectionSort(tr('In-game'), null),
        CollectionSort(tr('Name'), _byName(objectName)),
        CollectionSort(tr('Price'), (a, b) => _n(b['price']).compareTo(_n(a['price']))),
        CollectionSort(tr('Difficulty'), (a, b) => _n(b['difficulty']).compareTo(_n(a['difficulty']))),
      ],
      detail: (f) => FishDetail(fish: f),
    );
  }
}

class FishDetail extends StatefulWidget {
  const FishDetail({super.key, required this.fish});
  final Json fish;
  @override
  State<FishDetail> createState() => _FishDetailState();
}

class _FishDetailState extends State<FishDetail> {
  double _bonus = 1.0;

  Json get fish => widget.fish;

  @override
  Widget build(BuildContext context) {
    final f = fish;
    final locs = (f['locations'] as List? ?? const []).cast<Map>();
    final usage = ItemUsage.i;
    final name = objectName(f);
    return DetailScaffold(title: name, children: [
      DetailHeader(item: f, category: Cat.fish, id: _id(f), name: name, description: objectDescription(f)),
      PlankHeader(tr('Info')),
      if (f['type'] == 'crabpot') ...[
        InfoRow(tr('Method'), tr('Crab pot')),
        if (f['trapLocation'] != null) InfoRow(tr('Water'), tr(cap(f['trapLocation'].toString()))),
      ] else ...[
        InfoRow(tr('Seasons'), seasonsText(f['seasons'] as List?)),
        InfoRow(tr('Time'), _times(f)),
        InfoRow(tr('Weather'), _weatherName(f['weather']?.toString())),
        if (f['difficulty'] != null) InfoRow(tr('Difficulty'), '${f['difficulty']}'),
        if (f['behavior'] != null)
          InfoRow(tr('Behavior'), L10n.i.app('fish_behavior_${f['behavior']}') ?? tr(cap(f['behavior'].toString()))),
        if (_n(f['fishingLevel']) > 0) InfoRow(tr('Min. level'), '${f['fishingLevel']}'),
      ],
      if (f['minSize'] != null) InfoRow(tr('Size (inches)'), '${f['minSize']}–${f['maxSize']}'),
      if (_n(f['price']) > 0) ...[
        PlankHeader(tr('Sell price')),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SegmentedButton<double>(
            segments: [
              ButtonSegment(value: 1.0, label: Text(tr('Base'))),
              ButtonSegment(value: 1.25, label: Text(tr('Fisher'))),
              ButtonSegment(value: 1.5, label: Text(tr('Angler'))),
            ],
            selected: {_bonus},
            onSelectionChanged: (v) => setState(() => _bonus = v.first),
          ),
        ),
        PriceTable(price: _n(f['price']), edibility: _n(f['edibility']), bonus: _bonus),
      ],
      if (locs.isNotEmpty) ...[PlankHeader(tr('Locations')), for (final l in locs) LocationTile(loc: l)],
      if (bundleUsage(_id(f)).isNotEmpty) ...[
        PlankHeader(tr('Bundles')),
        for (final s in bundleUsage(_id(f))) Text('• $s'),
      ],
      if (usage.cooking[_id(f)] case final r?) ...[
        PlankHeader(tr('Used in recipes')),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final x in r) ItemRefChip(ref: {'name': recipeName(x), 'image': x['image']}),
        ]),
      ],
    ]);
  }
}

// ---------------- Crops ----------------
class CropsScreen extends StatelessWidget {
  const CropsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final crops = GameData.i.crops.where((c) => c['inAllCropsList'] != false).toList();
    return CollectionScreen(
      title: tr('Crops'),
      items: crops,
      idOf: (c) => c['harvest']?['id']?.toString() ?? c['gameId'].toString(),
      nameOf: cropName,
      category: Cat.crops,
      subtitle: (c) => Text(
          '${seasonsText(c['seasons'] as List?)} · ${tr('{n}d', {'n': c['totalGrowDays']})}${_n(c['regrowDays']) > 0 ? ' (${tr('regrow {n}d', {'n': c['regrowDays']})})' : ''}'),
      trailing: (c) => c['goldPerDay'] == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 4),
              child: PixelTag('~${(c['goldPerDay'] as num).toStringAsFixed(1)}g/d'),
            ),
      filters: [
        CollectionFilter(tr('Season'), seasons, (c, v) => (c['seasons'] as List? ?? const []).contains(v),
            optionLabel: (v) => seasonName(v!)),
      ],
      sorts: [
        CollectionSort(tr('In-game'), null),
        CollectionSort(tr('Name'), _byName(cropName)),
        CollectionSort(tr('Profit/day'), (a, b) => ((b['goldPerDay'] as num?) ?? -999).compareTo((a['goldPerDay'] as num?) ?? -999)),
        CollectionSort(tr('Growth time'), (a, b) => _n(a['totalGrowDays']).compareTo(_n(b['totalGrowDays']))),
      ],
      detail: (c) => CropDetail(crop: c),
    );
  }
}

class CropDetail extends StatelessWidget {
  const CropDetail({super.key, required this.crop});
  final Json crop;
  @override
  Widget build(BuildContext context) {
    final c = crop;
    final phases = (c['daysInPhase'] as List? ?? const []).map(_n).where((d) => d > 0).toList();
    final harvestId = c['harvest']?['id']?.toString();
    final name = cropName(c);
    final desc = harvestId == null ? null : (L10n.i.itemDescription(harvestId) ?? GameData.i.itemsById[harvestId]?['description']?.toString());
    return DetailScaffold(title: name, children: [
      DetailHeader(
        item: c,
        name: name,
        description: desc,
        category: Cat.crops,
        id: harvestId ?? c['gameId'].toString(),
        extra: SeasonBadges(c['seasons'] as List?),
      ),
      PlankHeader(tr('Growing')),
      if (c['seed'] != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            SizedBox(width: 110, child: Text(tr('Seed'))),
            Flexible(child: ItemRefChip(ref: c['seed'] as Map)),
          ]),
        ),
      if (c['seedPrice'] != null) InfoRow(tr('Seed price'), '${c['seedPrice']}g'),
      InfoRow(tr('Growth time'), tr('{n} days', {'n': c['totalGrowDays']})),
      if (phases.isNotEmpty) InfoRow(tr('Phases'), phases.join(' + ')),
      if (_n(c['regrowDays']) > 0) InfoRow(tr('Regrowth'), tr('{n} days', {'n': c['regrowDays']})),
      if (c['goldPerDay'] != null) InfoRow(tr('Profit/day'), '~${(c['goldPerDay'] as num).toStringAsFixed(2)}g/${tr('day')}'),
      if (c['isRaised'] == true) InfoRow(tr('Trellis'), tr('Yes – blocks movement')),
      if (c['isPaddyCrop'] == true) InfoRow(tr('Paddy crop'), tr('Grows faster near water')),
      if (_n(c['harvestMaxStack']) > 1)
        InfoRow(tr('Harvest'), tr('{min}–{max} per plant', {'min': c['harvestMinStack'], 'max': c['harvestMaxStack']})),
      if (_n(c['harvestSellPrice']) > 0) ...[
        PlankHeader(tr('Sell price')),
        PriceTable(price: _n(c['harvestSellPrice']), edibility: _n(GameData.i.itemsById[harvestId]?['edibility'])),
      ],
      if (harvestId != null && bundleUsage(harvestId).isNotEmpty) ...[
        PlankHeader(tr('Bundles')),
        for (final s in bundleUsage(harvestId)) Text('• $s'),
      ],
    ]);
  }
}

// ---------------- Cooking ----------------
class CookingScreen extends StatelessWidget {
  const CookingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return CollectionScreen(
      title: tr('Cooking'),
      items: GameData.i.cooking,
      idOf: _id,
      nameOf: recipeName,
      category: Cat.cooked,
      subtitle: (r) => Text((r['ingredients'] as List? ?? const []).map((i) => ItemRefChip.label(i as Map)).join(', '),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      sorts: [
        CollectionSort(tr('In-game'), null),
        CollectionSort(tr('Name'), _byName(recipeName)),
        CollectionSort(tr('Energy/Health'), (a, b) => _n(b['edibility']).compareTo(_n(a['edibility']))),
        CollectionSort(tr('Price'), (a, b) => _n(b['price']).compareTo(_n(a['price']))),
      ],
      detail: (r) => RecipeDetail(recipe: r, category: Cat.cooked, id: _id(r)),
    );
  }
}

class RecipeDetail extends StatelessWidget {
  const RecipeDetail({super.key, required this.recipe, required this.category, required this.id});
  final Json recipe;
  final String category;
  final String id;
  @override
  Widget build(BuildContext context) {
    final r = recipe;
    final p = context.farm;
    final ingredients = (r['ingredients'] as List? ?? const []).cast<Map>();
    final sources = (r['sources'] as List? ?? (r['source'] != null ? [r['source']] : const [])).cast<Map>();
    final out = r['output'] as Map?;
    final buffs = (r['buffs'] as List? ?? const []).cast<Map>();
    final name = recipeName(r);
    final outId = (out?['id'] ?? r['id'])?.toString();
    final outType = (out?['type'] ?? 'O').toString();
    return DetailScaffold(title: name, children: [
      DetailHeader(
        item: r,
        category: category,
        id: id,
        name: name,
        description: outId == null ? null : (L10n.i.itemDescription(outId, outType) ?? r['description']?.toString()),
      ),
      PlankHeader(tr('Ingredients')),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final i in ingredients)
          ItemRefChip(
            ref: i,
            onTap: i['id'] == null
                ? null
                : () {
                    final s = ItemDetailScreen.forId(i['id'].toString());
                    if (s != null) Navigator.push(context, MaterialPageRoute(builder: (_) => s));
                  },
          ),
      ]),
      if (out != null && _n(out['quantity']) > 1)
        Padding(padding: const EdgeInsets.only(top: 6), child: Text(tr('Makes {n}', {'n': out['quantity']}))),
      PlankHeader(tr('Recipe source(s)')),
      for (final s in sources)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            if (s['image'] != null) ...[TImage(s['image'], size: 24), const SizedBox(width: 6)],
            Expanded(child: Text(sourceText(s))),
          ]),
        ),
      if (buffs.isNotEmpty) ...[PlankHeader(tr('Buffs')), for (final b in buffs) BuffView(buff: b)],
      if (_n(r['price']) > 0) ...[
        PlankHeader(tr('Sell price')),
        PriceTable(price: _n(r['price']), edibility: r['edibility'] == null ? null : _n(r['edibility'])),
      ],
      if (r['queenOfSauce'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('📺 ${tr('Queen of Sauce: {recipe}', {'recipe': r['queenOfSauce']})}', style: TextStyle(color: p.textMuted)),
        ),
    ]);
  }

  static String sourceText(Map s) {
    final key = s['textKey']?.toString();
    final localized = key == null ? null : L10n.i.app(key);
    switch (s['kind']) {
      case 'starter':
        return tr('Starter recipe');
      case 'friendship':
        return '${villagerName(s['villager'])} (${s['hearts']}❤️)';
      case 'skill':
        return tr('{skill} level {level}', {'skill': skillName((s['skill'] ?? '').toString().toLowerCase()), 'level': s['level'] ?? ''});
      case 'shop':
        final shop = shopName(s['shop']?.toString());
        return s['price'] != null ? '$shop (${s['price']}g)' : shop;
      case 'queenOfSauce':
        final d = s['date'] as Map?;
        if (d == null) return tr('Queen of Sauce');
        return '${tr('Queen of Sauce')} – ${tr('{season} {day}, Year {year}', {'season': seasonName((d['season'] as num).toInt()), 'day': d['day'], 'year': d['year']})}';
      case 'mail':
        return localized ?? tr('Mail');
      default:
        return localized ?? (s['text'] ?? tr(cap('${s['kind']}'))).toString();
    }
  }

  static String shopName(String? s) => switch (s) {
        'FishShop' => tr("Willy's Fish Shop"),
        'SeedShop' => tr("Pierre's General Store"),
        'Carpenter' => tr("Carpenter's Shop"),
        'Saloon' => tr('Stardrop Saloon'),
        'Sandy' => tr('Oasis'),
        'DesertTrade' => tr('Desert Trader'),
        'IslandTrade' => tr('Island Trader'),
        'Dwarf' => villagerName('Dwarf'),
        'ShadowShop' => villagerName('Krobus'),
        'Traveler' => tr('Traveling Cart'),
        'QiGemShop' => tr("Qi's Walnut Room"),
        'AdventureShop' => tr("Adventurer's Guild"),
        _ => s ?? tr('Shop'),
      };
}

// ---------------- Crafting ----------------
class CraftingScreen extends StatelessWidget {
  const CraftingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final groups = {
      for (final g in GameData.i.craftingGroups)
        g['id'].toString(): L10n.i.app('crafting_group_${g['id']}') ?? tr(g['name'].toString()),
    };
    return CollectionScreen(
      title: tr('Crafting'),
      items: GameData.i.craftingRecipes,
      idOf: (r) => r['key'].toString(),
      nameOf: recipeName,
      category: Cat.crafted,
      groupBy: (r) => groups[r['group']] ?? tr('Other'),
      subtitle: (r) => Text(
          (r['ingredients'] as List? ?? const []).map((i) => '${ItemRefChip.label(i as Map)} ×${i['amount'] ?? 1}').join(', '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      filters: [
        CollectionFilter(tr('Group'), groups.keys.toList(), (r, v) => r['group'] == v, optionLabel: (v) => groups[v] ?? v ?? ''),
      ],
      detail: (r) => RecipeDetail(recipe: r, category: Cat.crafted, id: r['key'].toString()),
    );
  }
}

// ---------------- Museum ----------------
class MuseumScreen extends StatelessWidget {
  const MuseumScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final gd = GameData.i;
    final items = [
      for (final a in gd.artifacts) {...a, '_group': 'Artifacts'},
      for (final m in gd.minerals) {...m, '_group': 'Minerals'},
    ];
    return CollectionScreen(
      title: tr('Museum'),
      items: items,
      idOf: _id,
      nameOf: objectName,
      category: Cat.museum,
      groupBy: (j) => tr(j['_group'].toString()),
      filters: [
        CollectionFilter(tr('Type'), const ['Artifacts', 'Minerals'], (j, v) => j['_group'] == v, optionLabel: (v) => tr(v ?? '')),
      ],
      detail: (j) =>
          ItemDetailScreen.forId(_id(j), category: Cat.museum) ?? ItemDetailScreen(item: j, category: Cat.museum, checkId: _id(j)),
    );
  }
}

// ---------------- Shipping ----------------
class ShippingScreen extends StatelessWidget {
  const ShippingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final names = <int, String>{};
    for (final it in GameData.i.items) {
      if (it['category'] != null && it['categoryName'] != null) names[_n(it['category'])] = tr(it['categoryName'].toString());
    }
    final cats = GameData.i.shipping.map((s) => _n(s['category'])).toSet().toList();
    return CollectionScreen(
      title: tr('Shipping'),
      items: GameData.i.shipping,
      idOf: _id,
      nameOf: objectName,
      category: Cat.shipped,
      subtitle: (s) => Text('${names[_n(s['category'])] ?? ''} · ${s['price']}g'),
      filters: [
        CollectionFilter(tr('Category'), cats.map((c) => '$c').toList(), (s, v) => '${s['category']}' == v,
            optionLabel: (v) => names[int.tryParse(v ?? '')] ?? v ?? ''),
      ],
      detail: (s) =>
          ItemDetailScreen.forId(_id(s), category: Cat.shipped) ?? ItemDetailScreen(item: s, category: Cat.shipped, checkId: _id(s)),
    );
  }
}

// ---------------- Golden walnuts ----------------
class WalnutsScreen extends StatelessWidget {
  const WalnutsScreen({super.key});

  static String typeName(Map w) {
    final kind = (w['type'] as Map)['kind'].toString();
    if (kind == 'journal_scrap') {
      final n = (w['type'] as Map)['scrap'] ?? '';
      return (L10n.i.app('walnut_type_journal_scrap') ?? tr('Journal Scrap #{n}')).replaceAll('{{n}}', '$n').replaceAll('{n}', '$n');
    }
    return L10n.i.app('walnut_type_$kind') ?? tr(cap(kind.replaceAll('_', ' ')));
  }

  static String regionName(Object? r) => L10n.i.app('walnut_region_$r') ?? tr(cap('$r'));

  static String description(Map w) {
    final n = w['id'].toString().split('-').last;
    return L10n.i.app('walnut_desc_$n') ?? w['description'].toString();
  }

  @override
  Widget build(BuildContext context) {
    return CollectionScreen(
      title: tr('Golden Walnuts'),
      items: GameData.i.walnuts,
      idOf: _id,
      category: Cat.walnuts,
      nameOf: (w) => '#${w['number']} · ${typeName(w)}',
      groupBy: (w) => regionName(w['location']),
      subtitle: (w) => Text(description(w), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: (w) => PixelTag('🌰 ${w['quantity']}'),
      filters: [
        CollectionFilter(tr('Region'), const ['general', 'north', 'south', 'east', 'west'], (w, v) => w['location'] == v,
            optionLabel: regionName),
      ],
      detail: (w) => DetailScaffold(title: tr('Golden Walnut #{n}', {'n': w['number']}), children: [
        Center(child: PixelPanel(padding: const EdgeInsets.all(4), child: TImage(w['image'], size: 240))),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          PixelTag(regionName(w['location'])),
          PixelTag(typeName(w)),
          PixelTag('🌰 ×${w['quantity']}'),
        ]),
        const SizedBox(height: 10),
        Text(description(w), style: const TextStyle(fontSize: 16)),
      ]),
    );
  }
}

// ---------------- Stardrops ----------------
class StardropsScreen extends StatelessWidget {
  const StardropsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final img = GameData.i.itemsById['434']?['image'];
    return CollectionScreen(
      title: tr('Stardrops'),
      items: GameData.i.stardrops,
      idOf: _id,
      category: Cat.stardrops,
      imageOf: (_) => img,
      nameOf: (s) => appText(s['textKey']?.toString(), s['text']),
    );
  }
}

// ---------------- Wearables ----------------
String wearableKindName(String kind) => switch (kind) {
      'hat' => tr('Hats'),
      'shirt' => tr('Shirts'),
      'pants' => tr('Pants'),
      'boots' => tr('Boots'),
      'ring' => tr('Rings'),
      'trinket' => tr('Trinkets'),
      _ => kind,
    };

String? wearableEffect(Map w) {
  final kind = w['kind'];
  final key = kind == 'ring' ? 'wearable_effect_ring_${w['id']}' : (kind == 'trinket' ? 'wearable_effect_trinket_${w['id'].toString().replaceAllMapped(RegExp(r'(?<=[a-z])([A-Z])'), (m) => '_${m[1]}').toLowerCase()}' : null);
  return (key == null ? null : L10n.i.app(key)) ?? w['effect']?.toString();
}

class WearablesScreen extends StatelessWidget {
  const WearablesScreen({super.key});
  static const _kinds = ['hat', 'shirt', 'pants', 'boots', 'ring', 'trinket'];
  @override
  Widget build(BuildContext context) {
    return CollectionScreen(
      title: tr('Wearables'),
      items: GameData.i.wearables,
      idOf: (w) => w['qualifiedId']?.toString() ?? _id(w),
      nameOf: wearableName,
      category: Cat.wearables,
      groupBy: (w) => wearableKindName(w['kind'].toString()),
      subtitle: (w) => Text((wearableEffect(w) ?? wearableDescription(w) ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
      filters: [
        CollectionFilter(tr('Kind'), _kinds, (w, v) => w['kind'] == v, optionLabel: (v) => wearableKindName(v ?? '')),
        CollectionFilter(tr('Extra'), const ['dyeable', 'tailoring'],
            (w, v) => v == 'dyeable' ? w['dyeable'] == true : (w['tailoring'] as List? ?? const []).isNotEmpty,
            optionLabel: (v) => v == 'dyeable' ? tr('Dyeable only') : tr('Tailorable only')),
      ],
      detail: (w) => WearableDetail(w: w),
    );
  }
}

class WearableDetail extends StatelessWidget {
  const WearableDetail({super.key, required this.w});
  final Json w;
  @override
  Widget build(BuildContext context) {
    final sources = (w['sources'] as List? ?? const []).cast<Map>();
    final tailoring = (w['tailoring'] as List? ?? const []).cast<Map>();
    final boots = w['boots'] as Map?;
    Map ref(Map? r) {
      final item = r?['item'] as Map?;
      final id = item?['id']?.toString();
      final it = id == null ? null : GameData.i.itemsById[id];
      final tag = r?['tag']?.toString();
      return {
        'name': it != null ? objectName(it) : (tag != null ? (L10n.i.app('tailoring_tag_$tag') ?? tag) : (id ?? '?')),
        'image': it?['image'],
      };
    }

    final name = wearableName(w);
    final effect = wearableEffect(w);
    final yes = tr('Yes');
    return DetailScaffold(title: name, children: [
      DetailHeader(
        item: w,
        category: Cat.wearables,
        id: w['qualifiedId']?.toString() ?? _id(w),
        name: name,
        description: wearableDescription(w),
      ),
      if (effect != null) ...[PlankHeader(tr('Effect')), Text(effect)],
      PlankHeader(tr('Info')),
      InfoRow(tr('Type'), wearableKindName(w['kind'].toString())),
      if (boots != null) ...[InfoRow(tr('Defense'), '${boots['defense']}'), InfoRow(tr('Immunity'), '${boots['immunity']}')],
      if (w['price'] != null) InfoRow(tr('Price'), '${w['price']}g'),
      InfoRow(tr('Dyeable'), w['dyeable'] == true ? yes : tr('No')),
      if (w['prismatic'] == true) InfoRow(tr('Prismatic'), yes),
      if (w['sleeveless'] == true) InfoRow(tr('Sleeveless'), yes),
      if (w['characterCreation'] == true) InfoRow(tr('Character creation'), tr('Available')),
      if (sources.any((s) => s['kind'] != 'tailoring')) ...[
        PlankHeader(tr('How to obtain')),
        for (final s in sources.where((s) => s['kind'] != 'tailoring'))
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• ${_source(s)}')),
      ],
      if (tailoring.isNotEmpty) ...[
        PlankHeader(tr('Tailoring recipe')),
        for (final t in tailoring)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
              ItemRefChip(ref: ref(t['first'] as Map?)),
              const Text('+'),
              ItemRefChip(ref: ref(t['second'] as Map?)),
            ]),
          ),
      ],
    ]);
  }

  static String _source(Map s) {
    String? app(Object? key) => key == null ? null : L10n.i.app(key.toString());
    switch (s['kind']) {
      case 'shop':
        final currency = s['currency'];
        final unit = switch (currency) {
          null || 'gold' => 'g',
          'casino_coins' => ' ${tr('Qi coins')}',
          'star_tokens' => ' ${tr('Star tokens')}',
          {'item': final Map item} => ' ${L10n.i.itemName(item)}',
          _ => ' $currency',
        };
        final price = s['price'] != null ? ' – ${s['price']}$unit' : '';
        return '${app(s['shopNameKey']) ?? s['shopNameText'] ?? s['shop'] ?? tr('Shop')}$price';
      case 'characterCreation':
        return tr('Character creation');
      case 'hatMouse':
        final t = app(s['textKey']) ?? s['textText'];
        return t != null ? '${tr('Hat Mouse')}: $t' : tr('Hat Mouse');
      default:
        return (app(s['textKey']) ?? s['textText'] ?? s['text'] ?? tr(cap('${s['kind']}'))).toString();
    }
  }
}

// ---------------- Monsters ----------------
class MonstersScreen extends StatelessWidget {
  const MonstersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return CollectionScreen(
      title: tr('Monsters'),
      items: GameData.i.monsters,
      idOf: _id,
      nameOf: monsterName,
      category: Cat.monsters,
      imageOf: (m) => ((m['drops'] as List?)?.firstOrNull as Map?)?['image'],
      subtitle: (m) => Text('HP ${m['health']} · ${tr('DMG')} ${m['damage']} · ${tr('DEF')} ${m['defense']} · XP ${m['experience']}'),
      sorts: [
        CollectionSort(tr('In-game'), null),
        CollectionSort(tr('Name'), _byName(monsterName)),
        CollectionSort(tr('Health'), (a, b) => _n(b['health']).compareTo(_n(a['health']))),
      ],
      detail: (m) => DetailScaffold(title: monsterName(m), children: [
        PlankHeader(tr('Stats')),
        InfoRow(tr('Health'), '${m['health']}'),
        InfoRow(tr('Damage'), '${m['damage']}'),
        InfoRow(tr('Defense'), '${m['defense']}'),
        InfoRow(tr('Speed'), '${m['speed']}'),
        InfoRow(tr('Combat XP'), '${m['experience']}'),
        if (m['isGlider'] == true) InfoRow(tr('Movement'), tr('Flying')),
        PlankHeader(tr('Drops')),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final d in (m['drops'] as List? ?? const []).cast<Map>())
            ItemRefChip(ref: {'name': '${ItemRefChip.label(d)} (${((d['chance'] as num) * 100).toStringAsFixed(1)}%)', 'image': d['image']}),
        ]),
      ]),
    );
  }
}

// ---------------- Carpenter / Wizard buildings (reference) ----------------
class BuildingsRefScreen extends StatelessWidget {
  const BuildingsRefScreen({super.key, required this.builder});
  final String builder;
  @override
  Widget build(BuildContext context) {
    final list = GameData.i.buildings.where((b) => b['builder'] == builder && b['buildCost'] != null).toList();
    final p = context.farm;
    return DetailScaffold(
      title: builder == 'Wizard' ? tr("Wizard's Tower") : tr("Carpenter's Shop"),
      children: [
        for (final b in list) ...[
          PixelPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TImage(b['image'], size: 72),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(buildingName(b), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(L10n.i.buildingDescription(b['id'].toString()) ?? b['description']?.toString() ?? '',
                        style: TextStyle(color: p.textMuted, fontSize: 13)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      PixelTag('💰 ${b['buildCost']}g', color: p.wheat),
                      if (b['size'] != null) PixelTag(tr('Size {w}×{h}', {'w': b['size']['X'], 'h': b['size']['Y']})),
                      if (_n(b['buildDays']) > 0) PixelTag(tr('{n} days', {'n': b['buildDays']})),
                      if (b['buildingToUpgrade'] != null)
                        PixelTag(tr('Upgrade of {name}', {'name': L10n.i.buildingName(b['buildingToUpgrade'].toString())})),
                    ]),
                  ]),
                ),
              ]),
              if ((b['buildMaterials'] as List? ?? const []).isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final m in (b['buildMaterials'] as List).cast<Map>()) ItemRefChip(ref: m),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
