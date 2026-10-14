import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Checklist categories stored per farm.
class Cat {
  static const fish = 'fish';
  static const cooked = 'cooked';
  static const crafted = 'crafted';
  static const museum = 'museum';
  static const shipped = 'shipped';
  static const walnuts = 'walnuts';
  static const stardrops = 'stardrops';
  static const bundleItems = 'bundleItems';
  static const crops = 'crops';
  static const wearables = 'wearables';
  static const monsters = 'monsters';
}

enum NoteFrequency { once, daily, weekly, seasonly }

class FarmNote {
  FarmNote({
    required this.id,
    required this.text,
    required this.season,
    required this.day,
    required this.year,
    this.frequency = NoteFrequency.once,
    Set<String>? done,
  }) : done = done ?? {};

  final String id;
  String text;
  int season; // 0..3
  int day; // 1..28
  int year;
  NoteFrequency frequency;
  final Set<String> done; // occurrence keys "y-s-d"

  static int absDay(int year, int season, int day) => (year - 1) * 112 + season * 28 + day - 1;

  bool occursOn(int y, int s, int d) {
    final start = absDay(year, season, day);
    final t = absDay(y, s, d);
    if (t < start) return false;
    switch (frequency) {
      case NoteFrequency.once:
        return t == start;
      case NoteFrequency.daily:
        return true;
      case NoteFrequency.weekly:
        return (t - start) % 7 == 0;
      case NoteFrequency.seasonly:
        return d == day;
    }
  }

  static String occurrence(int y, int s, int d) => '$y-$s-$d';

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'season': season,
        'day': day,
        'year': year,
        'frequency': frequency.name,
        'done': done.toList(),
      };

  factory FarmNote.fromJson(Map<String, dynamic> j) => FarmNote(
        id: j['id'] as String,
        text: j['text'] as String,
        season: j['season'] as int,
        day: j['day'] as int,
        year: j['year'] as int? ?? 1,
        frequency: NoteFrequency.values.firstWhere((f) => f.name == j['frequency'], orElse: () => NoteFrequency.once),
        done: ((j['done'] as List?) ?? []).cast<String>().toSet(),
      );
}

class FarmProfile {
  FarmProfile({
    required this.id,
    required this.name,
    this.season = 0,
    this.day = 1,
    this.year = 1,
    this.remixedBundles = false,
    Map<String, Set<String>>? checks,
    Map<String, int>? hearts,
    List<FarmNote>? notes,
  })  : checks = checks ?? {},
        hearts = hearts ?? {},
        notes = notes ?? [];

  final String id;
  String name;
  int season;
  int day;
  int year;
  bool remixedBundles;
  final Map<String, Set<String>> checks;
  final Map<String, int> hearts;
  final List<FarmNote> notes;

  Set<String> set(String cat) => checks.putIfAbsent(cat, () => <String>{});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'season': season,
        'day': day,
        'year': year,
        'remixedBundles': remixedBundles,
        'checks': {for (final e in checks.entries) e.key: e.value.toList()},
        'hearts': hearts,
        'notes': notes.map((n) => n.toJson()).toList(),
      };

  factory FarmProfile.fromJson(Map<String, dynamic> j) => FarmProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        season: j['season'] as int? ?? 0,
        day: j['day'] as int? ?? 1,
        year: j['year'] as int? ?? 1,
        remixedBundles: j['remixedBundles'] as bool? ?? false,
        checks: {
          for (final e in ((j['checks'] as Map?) ?? {}).entries)
            e.key as String: (e.value as List).cast<String>().toSet(),
        },
        hearts: {
          for (final e in ((j['hearts'] as Map?) ?? {}).entries) e.key as String: (e.value as num).toInt(),
        },
        notes: ((j['notes'] as List?) ?? []).map((n) => FarmNote.fromJson(Map<String, dynamic>.from(n as Map))).toList(),
      );
}

/// All tracker progress, persisted locally as JSON.
class TrackerState extends ChangeNotifier {
  static const _key = 'tracker_v1';
  final List<FarmProfile> farms = [];
  String? _activeId;

  FarmProfile get farm => farms.firstWhere((f) => f.id == _activeId, orElse: () => farms.first);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw != null) {
      try {
        _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    if (farms.isEmpty) farms.add(FarmProfile(id: _newId(), name: 'My Farm'));
    _activeId ??= farms.first.id;
  }

  void _fromJson(Map<String, dynamic> j) {
    farms
      ..clear()
      ..addAll(((j['farms'] as List?) ?? []).map((f) => FarmProfile.fromJson(Map<String, dynamic>.from(f as Map))));
    _activeId = j['active'] as String?;
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'active': _activeId,
        'farms': farms.map((f) => f.toJson()).toList(),
      };

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(toJson()));
  }

  void _commit() {
    notifyListeners();
    _save();
  }

  static String _newId() => '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(999)}';

  // ---- farms ----
  void selectFarm(String id) {
    _activeId = id;
    _commit();
  }

  FarmProfile addFarm(String name) {
    final f = FarmProfile(id: _newId(), name: name);
    farms.add(f);
    _activeId = f.id;
    _commit();
    return f;
  }

  void renameFarm(FarmProfile f, String name) {
    f.name = name;
    _commit();
  }

  void deleteFarm(FarmProfile f) {
    farms.remove(f);
    if (farms.isEmpty) farms.add(FarmProfile(id: _newId(), name: 'My Farm'));
    if (_activeId == f.id) _activeId = farms.first.id;
    _commit();
  }

  void resetAll() {
    farms
      ..clear()
      ..add(FarmProfile(id: _newId(), name: 'My Farm'));
    _activeId = farms.first.id;
    _commit();
  }

  // ---- checks ----
  bool isChecked(String cat, String id) => farm.checks[cat]?.contains(id) ?? false;
  int count(String cat) => farm.checks[cat]?.length ?? 0;

  void toggle(String cat, String id, [bool? value]) {
    final s = farm.set(cat);
    final v = value ?? !s.contains(id);
    v ? s.add(id) : s.remove(id);
    _commit();
  }

  void setMany(String cat, Iterable<String> ids, bool value) {
    final s = farm.set(cat);
    value ? s.addAll(ids) : s.removeAll(ids);
    _commit();
  }

  // ---- date ----
  void setDate(int season, int day, [int? year]) {
    farm.season = season.clamp(0, 3);
    farm.day = day.clamp(1, 28);
    if (year != null) farm.year = max(1, year);
    _commit();
  }

  void nextDay() {
    var d = farm.day + 1, s = farm.season, y = farm.year;
    if (d > 28) {
      d = 1;
      s++;
      if (s > 3) {
        s = 0;
        y++;
      }
    }
    setDate(s, d, y);
  }

  void prevDay() {
    var d = farm.day - 1, s = farm.season, y = farm.year;
    if (d < 1) {
      d = 28;
      s--;
      if (s < 0) {
        s = 3;
        y = max(1, y - 1);
      }
    }
    setDate(s, d, y);
  }

  // ---- hearts ----
  int hearts(String villager) => farm.hearts[villager] ?? 0;
  void setHearts(String villager, int h) {
    farm.hearts[villager] = h;
    _commit();
  }

  void setRemixed(bool v) {
    farm.remixedBundles = v;
    _commit();
  }

  // ---- notes ----
  void addNote(FarmNote n) {
    farm.notes.add(n);
    _commit();
  }

  FarmNote newNote(String text, int season, int day, int year, NoteFrequency f) =>
      FarmNote(id: _newId(), text: text, season: season, day: day, year: year, frequency: f);

  void updateNote() => _commit();

  void deleteNote(FarmNote n) {
    farm.notes.remove(n);
    _commit();
  }

  void toggleNoteDone(FarmNote n, int y, int s, int d) {
    final k = FarmNote.occurrence(y, s, d);
    n.done.contains(k) ? n.done.remove(k) : n.done.add(k);
    _commit();
  }

  List<FarmNote> notesOn(int y, int s, int d) => farm.notes.where((n) => n.occursOn(y, s, d)).toList();

  /// Applies imported progress (from a save) to the active farm.
  void applyImport(void Function(FarmProfile f) fn) {
    fn(farm);
    _commit();
  }

  // ---- backup ----
  String exportJson() => const JsonEncoder.withIndent(' ').convert(toJson());

  void importJson(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['farms'] is! List) throw const FormatException('Not a tracker backup');
    _fromJson(j);
    if (farms.isEmpty) farms.add(FarmProfile(id: _newId(), name: 'My Farm'));
    _activeId ??= farms.first.id;
    _commit();
  }
}
