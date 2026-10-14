import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase.dart';

/// Lightweight localization.
///
/// * UI strings are keyed by their English text: `tr('Search...')`, with
///   `{name}` placeholders filled from [args]. Files: assets/i18n/<code>.json.
/// * Game text (item names, villager lines, schedules…) comes from the packs
///   extracted from the original tracker: assets/tracker/i18n/<code>.json.
class L10n extends ChangeNotifier {
  L10n._();
  static final L10n i = L10n._();

  static const languages = <String, String>{
    'en': 'English',
    'vi': 'Tiếng Việt',
    'de': 'Deutsch',
    'es': 'Español',
    'fr': 'Français',
    'hu': 'Magyar',
    'it': 'Italiano',
    'ja': '日本語',
    'ko': '한국어',
    'pt': 'Português (Brasil)',
    'ru': 'Русский',
    'tr': 'Türkçe',
    'zh': '简体中文',
  };
  static const _gameText = {'de', 'es', 'fr', 'hu', 'it', 'ja', 'ko', 'pt', 'ru', 'tr', 'zh'};
  static const _prefKey = 'app_language';

  /// User choice; null = follow the system language.
  String? preference;
  String code = 'en';
  Map<String, String> _ui = const {};
  Map<String, dynamic> _game = const {};

  Locale get locale => localeFor(code);

  Locale localeFor(String c) => switch (c) {
        'pt' => const Locale('pt', 'BR'),
        'zh' => const Locale('zh', 'CN'),
        _ => Locale(c),
      };

  /// Font for the current language (Pixelify lacks Vietnamese and CJK).
  String get fontFamily => switch (code) {
        'vi' => 'Tiny5',
        'ja' => 'DotGothic16',
        _ => 'Pixelify',
      };

  static String systemCode() {
    final l = PlatformDispatcher.instance.locale.languageCode;
    return languages.containsKey(l) ? l : 'en';
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    preference = p.getString(_prefKey);
    await _apply(preference ?? systemCode());
  }

  Future<void> setLanguage(String? pref) async {
    preference = pref;
    final p = await SharedPreferences.getInstance();
    if (pref == null) {
      await p.remove(_prefKey);
    } else {
      await p.setString(_prefKey, pref);
    }
    await _apply(pref ?? systemCode());
    Analytics.setLanguage(code);
    Analytics.log('language_changed', {'language': code});
    notifyListeners();
  }

  Future<void> _apply(String c) async {
    code = c;
    _ui = const {};
    _game = const {};
    if (c != 'en') {
      try {
        final raw = jsonDecode(await rootBundle.loadString('assets/i18n/$c.json')) as Map<String, dynamic>;
        _ui = raw.map((k, v) => MapEntry(k, v.toString()));
      } catch (e) {
        debugPrint('Missing UI translations for $c: $e');
      }
    }
    if (_gameText.contains(c)) {
      try {
        _game = jsonDecode(await rootBundle.loadString('assets/tracker/i18n/$c.json')) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Missing game text for $c: $e');
      }
    }
  }

  String tr(String en, [Map<String, Object?>? args]) {
    var s = _ui[en];
    if (s == null || s.isEmpty) s = en;
    if (args != null) {
      args.forEach((k, v) => s = s!.replaceAll('{$k}', '$v'));
    }
    return s!;
  }

  // ---------------- game text ----------------
  String? text(String key) => (_game['text'] as Map?)?[key] as String?;
  String? app(String key) => (_game['app'] as Map?)?[key] as String?;
  String? festival(String key) => (_game['festivals'] as Map?)?[key] as String?;

  /// Localized schedule stop description, if the pack has one.
  String? scheduleStop(String villager, String location, String cords) {
    final v = (_game['schedules'] as Map?)?[villager] as Map?;
    final l = v?[location] as Map?;
    return l?[cords] as String?;
  }

  /// Name of an item reference `{id, type}` (type O, BO/BC, F, H, S, P, B, TR).
  String itemName(Map ref, [String? fallback]) {
    final id = ref['id']?.toString();
    final type = (ref['type'] ?? 'O').toString();
    if (id != null) {
      final key = switch (type) {
        'BO' || 'BC' => 'bigCraftables.$id.name',
        'F' => 'furniture.$id.name',
        'H' || 'S' || 'P' || 'B' || 'TR' => 'wearables.($type)$id.name',
        _ => 'objects.$id.name',
      };
      final t = text(key);
      if (t != null) return t;
    }
    final any = ref['anyName'] ?? ref['name'];
    final base = (fallback ?? any ?? id ?? '?').toString();
    return ref['anyName'] != null || ref['category'] != null ? tr(base) : base;
  }

  String? itemDescription(String id, [String type = 'O']) =>
      text(type == 'BO' || type == 'BC' ? 'bigCraftables.$id.description' : 'objects.$id.description');

  String villagerName(String name) => text('villagers.$name.name') ?? name;
  String? relationship(String villager, String other) => text('villagers.$villager.relationships.$other');
  String? giftReaction(String villager, String level) => text('giftTastes.$villager.$level');
  String wearableName(String qid, String fallback) => text('wearables.$qid.name') ?? fallback;
  String? wearableDescription(String qid) => text('wearables.$qid.description');
  String monsterName(String id) => text('monsters.$id.name') ?? id;
  String buildingName(String id) => text('buildings.$id.name') ?? id;
  String? buildingDescription(String id) => text('buildings.$id.description');
  String bundleName(String key, String fallback) => text('bundles.$key.name') ?? fallback;
}

/// Translates an English UI string.
String tr(String en, [Map<String, Object?>? args]) => L10n.i.tr(en, args);
