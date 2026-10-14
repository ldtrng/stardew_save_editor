import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../l10n/names.dart';
import 'package:provider/provider.dart';

import '../../data/game_data.dart';
import '../../state/tracker_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../tracker/collection_screen.dart';
import '../tracker/item_detail.dart';
import '../tracker/tracker_widgets.dart';

const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class VillagerDetail extends StatelessWidget {
  const VillagerDetail({super.key, required this.villager});
  final Json villager;

  @override
  Widget build(BuildContext context) {
    final v = villager;
    final t = context.watch<TrackerState>();
    final p = context.farm;
    final name = v['name'].toString();
    final bday = v['birthday'] as Map?;
    final datable = v['datable'] == true;
    final hearts = t.hearts(name);
    final rels = (v['relationships'] as List? ?? []).cast<Map>();
    final display = villagerName(name);
    return DetailScaffold(title: display, children: [
      PixelPanel(
        color: p.panelAlt,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PixelPanel(padding: EdgeInsets.all(4), shadow: false, child: TImage(v['portrait'] ?? v['image'], size: 96)),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              if (bday != null) InfoRow(tr('Birthday'), '${seasonName(bday['season'].toString())} ${bday['day']}', icon: Icons.cake_outlined),
              InfoRow(tr('Region'), tr((v['homeRegionText'] ?? v['homeRegion'] ?? 'Unknown').toString()), icon: Icons.map_outlined),
              if (v['homeLocationText'] != null) InfoRow(tr('Address'), tr(v['homeLocationText'].toString()), icon: Icons.home_outlined),
              InfoRow(tr('Dateable'), datable ? tr('Yes') : tr('No'), icon: Icons.favorite_border),
            ]),
          ),
        ]),
      ),
      PlankHeader('${tr('Friendship')}  ♥ $hearts'),
      HeartRow(hearts: hearts, max: datable ? 14 : 10, size: 24, onTap: (h) => t.setHearts(name, h)),
      if (rels.isNotEmpty) ...[
        PlankHeader(tr('Relationships')),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final r in rels)
            ItemRefChip(
              ref: {'name': _relationLabel(name, r), 'image': GameData.i.villager(r['npc'].toString())?['image']},
              onTap: () {
                final other = GameData.i.villager(r['npc'].toString());
                if (other != null) Navigator.push(context, MaterialPageRoute(builder: (_) => VillagerDetail(villager: other)));
              },
            ),
        ]),
      ],
      if (v['gifts'] != null) ...[PlankHeader(tr('Gifts')), _Gifts(villager: name, gifts: v['gifts'] as Map)],
      if (v['hasSchedule'] == true || GameData.i.villagerSchedules['schedules'][name] != null) ...[
        PlankHeader(tr('Schedule')),
        ScheduleView(villager: name),
      ],
    ]);
  }
}

String _relationLabel(String villager, Map r) {
  final rel = L10n.i.relationship(villager, r['npc'].toString()) ?? (r['text'].toString().isEmpty ? '' : tr(r['text'].toString()));
  return rel.isEmpty ? villagerName(r['npc']) : '${villagerName(r['npc'])} ($rel)';
}

class _Gifts extends StatefulWidget {
  const _Gifts({required this.villager, required this.gifts});
  final String villager;
  final Map gifts;
  @override
  State<_Gifts> createState() => _GiftsState();
}

class _GiftsState extends State<_Gifts> {
  String _level = 'love';
  static const _levels = {'love': '🥰', 'like': '🙂', 'neutral': '😐', 'dislike': '🙁', 'hate': '😡'};

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    final g = widget.gifts[_level] as Map?;
    // Some entries point at item ids missing from the data set; skip them.
    final items = (g?['items'] as List? ?? []).cast<Map>().where((it) => it['name'] != null || it['anyName'] != null || it['category'] != null).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final e in _levels.entries)
          ChoiceChip(label: Text('${e.value} ${tr(cap(e.key))}'), selected: _level == e.key, onSelected: (_) => setState(() => _level = e.key)),
      ]),
      SizedBox(height: 8),
      if (g?['reaction'] != null)
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('"${(L10n.i.giftReaction(widget.villager, _level) ?? g!['reaction']).toString().replaceAll('@', tr('Farmer'))}"', style: TextStyle(fontStyle: FontStyle.italic, color: p.textMuted)),
        ),
      if (items.isEmpty) Text(tr('Nothing specific.'), style: TextStyle(color: p.textMuted)),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final it in items)
          ItemRefChip(
            ref: it,
            onTap: it['id'] == null
                ? null
                : () {
                    final s = ItemDetailScreen.forId(it['id'].toString());
                    if (s != null) Navigator.push(context, MaterialPageRoute(builder: (_) => s));
                  },
          ),
      ]),
    ]);
  }
}

/// Resolves which schedule a villager follows on a given day, following the
/// game's lookup order (date → day of month → bus → rain → weekday → season).
class ScheduleResolver {
  ScheduleResolver(this.villager);
  final String villager;

  static const _special = ['DesertFestival', 'GreenRain', 'TroutDerby', 'SquidFest', 'Replacement'];

  List<Map> get entries =>
      ((GameData.i.villagerSchedules['schedules'] as Map)[villager] as List? ?? []).cast<Map>();

  Map? resolve({
    required int season,
    required int day,
    required bool rain,
    required bool bus,
    required bool married,
    required int hearts,
    required Set<String> friendsAbove,
  }) {
    final s = seasons[season];
    final wd = weekdays[(day - 1) % 7];
    bool special(Map e) => _special.any((k) => e['key'].toString().contains(k));
    bool ok(Map e) {
      final mh = int.tryParse('${e['minHeartLevel']}');
      if (mh != null && hearts < mh) return false;
      for (final f in (e['friendships'] as List? ?? []).cast<Map>()) {
        if (friendsAbove.contains(f['villager'])) return false;
      }
      return true;
    }

    Map? pick(bool Function(Map) pred, List<Map> pool) {
      final hits = pool.where((e) => pred(e) && ok(e)).toList();
      if (hits.isEmpty) return null;
      hits.sort((a, b) => (int.tryParse('${b['minHeartLevel']}') ?? 0).compareTo(int.tryParse('${a['minHeartLevel']}') ?? 0));
      return hits.first;
    }

    if (married) {
      final m = entries.where((e) => (e['isMarriage'] == true || e['isMarriageJob'] == true) && !special(e)).toList();
      return pick((e) => e['season'] == s && e['day'] == day, m) ??
          pick((e) => e['weekday'] == wd && e['season'] == null, m) ??
          GameData.i.villagerSchedules['marriageSchedule'] as Map?;
    }
    final n = entries.where((e) => e['isMarriage'] != true && e['isMarriageJob'] != true && !special(e)).toList();
    bool plain(Map e) => e['isRain'] != true && e['isBus'] != true;
    return pick((e) => e['season'] == s && e['day'] == day && plain(e), n) ??
        pick((e) => e['season'] == null && e['day'] == day && e['weekday'] == null && plain(e), n) ??
        (bus ? pick((e) => e['isBus'] == true, n) : null) ??
        (rain ? (pick((e) => e['key'] == 'rain', n) ?? pick((e) => e['isRain'] == true, n)) : null) ??
        pick((e) => e['season'] == s && e['weekday'] == wd && e['day'] == null && plain(e), n) ??
        pick((e) => e['season'] == null && e['weekday'] == wd && e['day'] == null && plain(e), n) ??
        pick((e) => e['key'] == s, n) ??
        pick((e) => e['key'] == 'spring', n) ??
        pick((e) => e['key'] == 'default', n);
  }
}

class ScheduleView extends StatefulWidget {
  const ScheduleView({super.key, required this.villager});
  final String villager;
  @override
  State<ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<ScheduleView> {
  int? _season;
  int? _day;
  bool _rain = false;
  bool _bus = true;
  bool _married = false;
  Set<String>? _friendsAbove;

  String _describe(Map row) {
    final loc = L10n.i.scheduleStop(widget.villager, row['location']?.toString() ?? '', row['cords']?.toString() ?? '');
    if (loc != null) return loc;
    if (row['description'] != null) return row['description'].toString();
    final texts = (GameData.i.villagerSchedules['locationText'] as Map)[widget.villager] as Map?;
    final byLoc = texts?[row['location']] as Map?;
    final t = byLoc?[row['cords']];
    if (t != null) return t.toString();
    final home = (GameData.i.villagerSchedules['villagerHomeDisplayKeys'] as Map)[row['location']] as Map?;
    return tr((home?['text'] ?? row['location'] ?? '').toString());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TrackerState>();
    final p = context.farm;
    final season = _season ?? t.farm.season;
    final day = _day ?? t.farm.day;
    final resolver = ScheduleResolver(widget.villager);
    final friends = <String, int>{};
    for (final e in resolver.entries) {
      for (final f in (e['friendships'] as List? ?? []).cast<Map>()) {
        friends[f['villager'].toString()] = (f['maxFriendship'] as num?)?.toInt() ?? 6;
      }
    }
    final above = _friendsAbove ??= {
      for (final f in friends.entries)
        if (t.hearts(f.key) >= f.value) f.key,
    };
    final dateable = GameData.i.villager(widget.villager)?['datable'] == true;
    final sched = resolver.resolve(
      season: season,
      day: day,
      rain: _rain,
      bus: _bus,
      married: _married,
      hearts: t.hearts(widget.villager),
      friendsAbove: above,
    );
    final rows = (sched?['schedule'] as List? ?? []).cast<Map>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        DropdownButton<int>(
          value: season,
          items: [for (var i = 0; i < 4; i++) DropdownMenuItem(value: i, child: Text(seasonName(i)))],
          onChanged: (v) => setState(() => _season = v),
        ),
        SizedBox(width: 12),
        IconButton(onPressed: () => setState(() => _day = day <= 1 ? 28 : day - 1), icon: Icon(Icons.chevron_left)),
        Text('${tr('Day {n}', {'n': day})} · ${weekdayShort(day - 1)}', style: TextStyle(fontWeight: FontWeight.w600)),
        IconButton(onPressed: () => setState(() => _day = day >= 28 ? 1 : day + 1), icon: Icon(Icons.chevron_right)),
      ]),
      Wrap(spacing: 6, runSpacing: 6, children: [
        FilterChip(label: Text(tr('🌧️ Raining')), selected: _rain, onSelected: (v) => setState(() => _rain = v)),
        FilterChip(label: Text(tr('🚌 Bus')), selected: _bus, onSelected: (v) => setState(() => _bus = v)),
        if (dateable) FilterChip(label: Text(tr('💍 Married')), selected: _married, onSelected: (v) => setState(() => _married = v)),
        for (final f in friends.entries)
          FilterChip(
            label: Text('${f.value}♥ ${f.key}'),
            selected: above.contains(f.key),
            onSelected: (v) => setState(() => v ? above.add(f.key) : above.remove(f.key)),
          ),
      ]),
      SizedBox(height: 8),
      if (rows.isEmpty)
        Text(tr('No schedule data for this day.'), style: TextStyle(color: p.textMuted))
      else
        for (final r in rows)
          Container(
            margin: EdgeInsets.only(bottom: 4),
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(color: p.panelAlt, border: Border(left: BorderSide(color: p.grassDark, width: 4))),
            child: Row(children: [
              SizedBox(
                width: 76,
                child: Text(gameTime(int.tryParse('${r['time']}') ?? 600), style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              Expanded(child: Text(_describe(r))),
            ]),
          ),
      if (sched?['key'] != null)
        Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(tr('Schedule: {key}', {'key': sched!['key']}), style: TextStyle(fontSize: 11, color: p.textMuted)),
        ),
    ]);
  }
}
