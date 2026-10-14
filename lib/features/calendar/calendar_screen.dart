import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../l10n/names.dart';
import 'package:provider/provider.dart';

import '../../ads/banner_ad.dart';
import '../../data/game_data.dart';
import '../../state/tracker_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../settings/farms_sheet.dart';
import '../tracker/collections.dart';
import '../tracker/tracker_widgets.dart';
import '../villagers/villager_detail.dart';

const seasonColors = [Color(0xFF7BC67B), Color(0xFFF0B84A), Color(0xFFE07B39), Color(0xFF7FA7D9)];

class DayEvents {
  DayEvents(this.season, this.day, this.year);
  final int season, day, year;

  String get weekday => weekdays[(day - 1) % 7];

  List<Json> get birthdays => GameData.i.socialVillagers.where((v) {
        final b = v['birthday'] as Map?;
        return b != null && seasons.indexOf(b['season'].toString()) == season && b['day'] == day;
      }).toList();

  List<String> get festivals {
    final cal = GameData.i.calendar;
    final out = <String>[];
    for (final f in (cal['festivals'] as List).cast<Map>()) {
      if (seasons.indexOf(f['season'].toString()) == season && f['day'] == day) out.add(L10n.i.festival(f['key'].toString()) ?? f['name'].toString());
    }
    for (final r in (cal['calendarRanges'] as List).cast<Map>()) {
      final hit = (r['dates'] as List).cast<Map>().any((d) => seasons.indexOf(d['season'].toString()) == season && d['day'] == day);
      if (hit) out.add(appText(r['textKey']?.toString(), r['text']));
    }
    return out;
  }

  bool get isFestival {
    final cal = GameData.i.calendar;
    return (cal['festivals'] as List).cast<Map>().any((f) => seasons.indexOf(f['season'].toString()) == season && f['day'] == day);
  }

  List<String> get recurring => [
        if (weekday == 'Fri' || weekday == 'Sun') tr('Visit the Traveling Cart in Cindersap Forest'),
        if (weekday == 'Fri') tr('You can buy an Iridium Sprinkler from Krobus (Fridays)'),
        if (weekday == 'Sun') tr('Queen of Sauce airs on TV today (re-runs on Wednesday)'),
      ];

  Json? get queenOfSauce {
    if (weekday != 'Sun') return null;
    final y = ((year - 1) % 2) + 1;
    for (final q in (GameData.i.calendar['queenOfSauce'] as List).cast<Map>()) {
      if (q['season'] == season && q['day'] == day && q['year'] == y) return Map<String, dynamic>.from(q);
    }
    return null;
  }

  /// Crops whose last planting day (to harvest before season end) is today.
  List<Json> get lastDayToPlant => GameData.i.crops.where((c) {
        final ss = (c['seasons'] as List? ?? []);
        if (!ss.contains(seasons[season])) return false;
        if (c['inAllCropsList'] == false) return false;
        // Multi-season crops can be planted later if the next season also fits.
        final next = seasons[(season + 1) % 4];
        if (ss.contains(next) && season != 3) return false;
        final grow = (c['totalGrowDays'] as num?)?.toInt() ?? 0;
        return grow > 0 && 28 - grow == day;
      }).toList();
}

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TrackerState>();
    final f = t.farm;
    final p = context.farm;
    final ev = DayEvents(f.season, f.day, f.year);
    final notes = t.notesOn(f.year, f.season, f.day);
    final qos = ev.queenOfSauce;
    final plant = ev.lastDayToPlant;
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => showFarmsSheet(context),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(f.name, overflow: TextOverflow.ellipsis)),
            Icon(Icons.arrow_drop_down),
          ]),
        ),
        actions: [
          IconButton(
            tooltip: tr('Season calendar'),
            icon: Icon(Icons.calendar_month),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SeasonCalendarScreen())),
          ),
        ],
      ),
      bottomNavigationBar: AdBanner(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: p.grassDark,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(side: BorderSide(color: p.outline, width: 2)),
        onPressed: () => showNoteEditor(context),
        icon: Icon(Icons.add),
        label: Text(tr('New note')),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          _DateBar(),
          if (ev.birthdays.isNotEmpty) ...[
            PlankHeader(tr('🎂 Birthdays')),
            for (final v in ev.birthdays)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: TImage(v['image'], size: 36),
                title: Text(villagerName(v['name'])),
                subtitle: _bestGifts(v),
                trailing: Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VillagerDetail(villager: v))),
              ),
          ],
          if (ev.festivals.isNotEmpty || ev.recurring.isNotEmpty || qos != null) ...[
            PlankHeader(tr('🚩 Events')),
            for (final e in ev.festivals) _Bullet(icon: Icons.flag, text: e, color: p.berry),
            for (final e in ev.recurring) _Bullet(icon: Icons.event_repeat, text: e, color: p.woodDark),
            if (qos != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: TImage((qos['item'] as Map?)?['image'], size: 32),
                title: Text(tr('Queen of Sauce: {recipe}', {'recipe': L10n.i.itemName(qos['item'] as Map, qos['recipe']?.toString())})),
                subtitle: Text(tr('Watch TV to learn this recipe')),
              ),
          ],
          if (plant.isNotEmpty) ...[
            PlankHeader(tr('🌱 Last day to plant')),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in plant)
                ItemRefChip(
                  ref: {'name': cropName(c), 'image': c['image']},
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CropDetail(crop: c))),
                ),
            ]),
          ],
          if (f.day == 1) ...[
            PlankHeader(tr('🌾 Best crops for {season}', {'season': seasonName(f.season)})),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in (GameData.i.crops
                      .where((c) =>
                          (c['seasons'] as List? ?? []).contains(seasons[f.season]) &&
                          c['goldPerDay'] != null &&
                          _pierreSeeds.contains(c['seed']?['id']?.toString()))
                      .toList()
                    ..sort((a, b) => (b['goldPerDay'] as num).compareTo(a['goldPerDay'] as num)))
                  .take(6))
                ItemRefChip(ref: {'name': '${cropName(c)} ~${(c['goldPerDay'] as num).toStringAsFixed(0)}g/d', 'image': c['image']}),
            ]),
          ],
          PlankHeader(tr('📝 To-do')),
          if (notes.isEmpty)
            Text(tr('Nothing planned. Tap "New note" to add one.'), style: TextStyle(color: p.textMuted))
          else
            for (final n in notes)
              _NoteTile(note: n, year: f.year, season: f.season, day: f.day),
        ],
      ),
    );
  }

  Widget? _bestGifts(Json v) {
    final loves = ((v['gifts'] as Map?)?['love']?['items'] as List? ?? []).cast<Map>().where((i) => i['name'] != null).take(3);
    if (loves.isEmpty) return null;
    return Text(tr('Loves: {items}', {'items': loves.map((i) => L10n.i.itemName(i)).join(', ')}), maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: color),
          SizedBox(width: 8),
          Expanded(child: Text(text)),
        ]),
      );
}

class _DateBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.watch<TrackerState>();
    final f = t.farm;
    final p = context.farm;
    final sc = seasonColors[f.season];
    return PixelPanel(
      color: sc.withValues(alpha: 0.35),
      child: Column(children: [
        Row(children: [
          IconButton(
            onPressed: () => t.setDate((f.season + 3) % 4, f.day),
            icon: Icon(Icons.keyboard_double_arrow_left),
          ),
          Expanded(
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(color: sc, border: Border.all(color: p.outline, width: 2)),
                child: Text('${seasonEmoji[seasons[f.season]]} ${tr('{season} · Year {year}', {'season': seasonName(f.season), 'year': f.year})}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: p.outline)),
              ),
            ),
          ),
          IconButton(
            onPressed: () => t.setDate((f.season + 1) % 4, f.day),
            icon: Icon(Icons.keyboard_double_arrow_right),
          ),
        ]),
        Row(children: [
          IconButton(onPressed: t.prevDay, icon: Icon(Icons.chevron_left, size: 32)),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SeasonCalendarScreen())),
              child: Column(children: [
                Text('${f.day}', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, height: 1)),
                Text(weekdayLong(f.day - 1), style: TextStyle(color: p.textMuted)),
              ]),
            ),
          ),
          IconButton(onPressed: t.nextDay, icon: Icon(Icons.chevron_right, size: 32)),
        ]),
      ]),
    );
  }
}

/// Seeds sold year-round at Pierre's / JojaMart.
final Set<String> _pierreSeeds = {
  for (final k in ['generalStoreItems', 'jojaMartItems'])
    for (final it in (GameData.i.shops[k] as List).cast<Map>()) it['id'].toString(),
};


class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note, required this.year, required this.season, required this.day});
  final FarmNote note;
  final int year, season, day;

  @override
  Widget build(BuildContext context) {
    final t = context.read<TrackerState>();
    final p = context.farm;
    final done = note.done.contains(FarmNote.occurrence(year, season, day));
    return Container(
      margin: EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: p.panel, border: Border.all(color: p.outline.withValues(alpha: 0.5), width: 1.5)),
      child: Row(children: [
        PixelCheck(value: done, onChanged: (_) => t.toggleNoteDone(note, year, season, day)),
        Expanded(
          child: GestureDetector(
            onTap: () => showNoteEditor(context, note: note),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(note.text, style: TextStyle(decoration: done ? TextDecoration.lineThrough : null)),
              if (note.frequency != NoteFrequency.once)
                Text(_freqLabel(note.frequency), style: TextStyle(fontSize: 11, color: p.textMuted)),
            ]),
          ),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: p.berry),
          onPressed: () => t.deleteNote(note),
        ),
      ]),
    );
  }
}

String _freqLabel(NoteFrequency f) => switch (f) {
      NoteFrequency.once => tr('Once'),
      NoteFrequency.daily => tr('Repeats every day'),
      NoteFrequency.weekly => tr('Repeats every week'),
      NoteFrequency.seasonly => tr('Repeats every season'),
    };

Future<void> showNoteEditor(BuildContext context, {FarmNote? note}) async {
  final t = context.read<TrackerState>();
  final f = t.farm;
  final ctrl = TextEditingController(text: note?.text ?? '');
  var freq = note?.frequency ?? NoteFrequency.once;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(note == null ? tr('New note · {season} {day}', {'season': seasonName(f.season), 'day': f.day}) : tr('Edit note'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          SizedBox(height: 10),
          TextField(controller: ctrl, autofocus: true, maxLines: 3, decoration: InputDecoration(hintText: tr('e.g. Water the crops, buy seeds…'))),
          SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final fr in NoteFrequency.values)
              ChoiceChip(label: Text(_freqLabel(fr)), selected: freq == fr, onSelected: (_) => setS(() => freq = fr)),
          ]),
          SizedBox(height: 14),
          FilledButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              if (note == null) {
                t.addNote(t.newNote(text, f.season, f.day, f.year, freq));
              } else {
                note
                  ..text = text
                  ..frequency = freq;
                t.updateNote();
              }
              Navigator.pop(c);
            },
            child: Text(tr('Save')),
          ),
        ]),
      ),
    ),
  );
}

/// Month grid for one season.
class SeasonCalendarScreen extends StatelessWidget {
  const SeasonCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TrackerState>();
    final f = t.farm;
    final p = context.farm;
    final sc = seasonColors[f.season];
    return Scaffold(
      appBar: AppBar(title: Text(tr('{season} · Year {year}', {'season': seasonName(f.season), 'year': f.year}))),
      body: ListView(padding: EdgeInsets.all(12), children: [
        Row(children: [
          for (var s = 0; s < 4; s++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: ChoiceChip(
                  label: Center(child: Text(seasonName(s))),
                  selected: f.season == s,
                  onSelected: (_) => t.setDate(s, f.day),
                ),
              ),
            ),
        ]),
        SizedBox(height: 10),
        Row(children: [
          for (final w in weekdays)
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 4),
                color: sc,
                alignment: Alignment.center,
                child: Text(weekdayShort(weekdays.indexOf(w)), style: TextStyle(fontWeight: FontWeight.w700, color: p.outline)),
              ),
            ),
        ]),
        for (var week = 0; week < 4; week++)
          Row(children: [
            for (var wd = 0; wd < 7; wd++)
              Expanded(child: _DayCell(day: week * 7 + wd + 1)),
          ]),
        SizedBox(height: 12),
        Text(tr('Tap a day to jump to it.'), style: TextStyle(color: p.textMuted, fontSize: 12)),
      ]),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day});
  final int day;
  @override
  Widget build(BuildContext context) {
    final t = context.watch<TrackerState>();
    final f = t.farm;
    final p = context.farm;
    final ev = DayEvents(f.season, day, f.year);
    final selected = f.day == day;
    final bdays = ev.birthdays;
    final hasNotes = t.notesOn(f.year, f.season, day).isNotEmpty;
    return GestureDetector(
      onTap: () {
        t.setDate(f.season, day);
        Navigator.pop(context);
      },
      child: AspectRatio(
        aspectRatio: 0.8,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? seasonColors[f.season].withValues(alpha: 0.6) : p.panel,
            border: Border.all(color: p.outline.withValues(alpha: 0.6), width: 1),
          ),
          padding: EdgeInsets.all(2),
          child: Stack(children: [
            Text('$day', style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
            if (bdays.isNotEmpty) Positioned(right: 0, bottom: 0, child: TImage(bdays.first['image'], size: 22)),
            if (ev.isFestival) Positioned(left: 0, bottom: 0, child: Icon(Icons.flag, size: 16, color: p.berry)),
            if (hasNotes) Positioned(right: 0, top: 0, child: Icon(Icons.sticky_note_2, size: 12, color: p.woodDark)),
          ]),
        ),
      ),
    );
  }
}
