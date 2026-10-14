import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import 'save_file.dart';
import 'xml_ext.dart';

class QiQuestTemplate {
  QiQuestTemplate(this.raw);
  final Map<String, dynamic> raw;
  String get key => raw['questKey'] as String;
  String get name => raw['name'] as String;
  String get description => raw['description'] as String;
  int get rewardGems => (raw['rewardGems'] as num).toInt();
  String get duration => raw['duration'] as String;
  int get durationDays => (raw['durationDays'] as num).toInt();
  List<Map<String, dynamic>> get objectives =>
      (raw['objectives'] as List).cast<Map<String, dynamic>>();

  static List<QiQuestTemplate> all = [];
  static Future<void> load() async {
    if (all.isNotEmpty) return;
    final list = jsonDecode(await rootBundle.loadString('assets/editor/data/qiquests.json')) as List;
    all = list.map((e) => QiQuestTemplate(Map<String, dynamic>.from(e as Map))).toList();
  }
}

/// Mr. Qi's Walnut Room special orders: which are offered on the board and
/// which are already accepted.
class QiQuests {
  QiQuests(this.save);
  final SaveFile save;
  static const maxOffered = 2;

  Map<String, QiQuestTemplate> get _templates => {for (final t in QiQuestTemplate.all) t.key: t};

  XmlElement get _available => save.root.ensure('availableSpecialOrders');
  XmlElement get _active => save.root.ensure('specialOrders');

  Set<String> get offered => _available
      .childrenNamed('SpecialOrder')
      .map((o) => o.str('questKey') ?? '')
      .where(_templates.containsKey)
      .toSet();

  Set<String> get inProgress => _active
      .childrenNamed('SpecialOrder')
      .where((o) => o.str('questState') == 'InProgress')
      .map((o) => o.str('questKey') ?? '')
      .where(_templates.containsKey)
      .toSet();

  bool get boardFull => offered.length >= maxOffered;

  XmlElement _buildEntry(QiQuestTemplate t) {
    final seasonIndex = ['spring', 'summer', 'fall', 'winter'].indexOf(save.season);
    final totalDays = (save.year - 1) * 112 + max(0, seasonIndex) * 28 + save.dayOfMonth - 1;
    Map<String, Object?> objective(Map<String, dynamic> o) {
      final m = <String, Object?>{
        '@xsi:type': '${o['type']}Objective',
        'currentCount': 0,
        'maxCount': o['maxCount'],
        'description': o['description'],
        'failOnCompletion': false,
        'acceptableContextTagSets': o['acceptableContextTagSets'],
      };
      if (o['dropBox'] != null) {
        m['dropBox'] = o['dropBox'];
        m['dropBoxGameLocation'] = o['dropBoxGameLocation'];
        final xy = (o['dropBoxTileLocation'] as String?)?.split(' ');
        if (xy != null && xy.length == 2) m['dropBoxTileLocation'] = {'X': xy[0], 'Y': xy[1]};
        m['confirmed'] = false;
      }
      if (o['minimumCapacity'] != null) m['minimumCapacity'] = o['minimumCapacity'];
      if (o['useShipmentValue'] != null) m['useShipmentValue'] = o['useShipmentValue'];
      if (o['skullCave'] != null) m['skullCave'] = o['skullCave'];
      return m;
    }

    return buildElement('SpecialOrder', {
      'preSelectedItems': '',
      'selectedRandomElements': '',
      'objectives': t.objectives.map(objective).toList(),
      'generationSeed': Random().nextInt(2147483647),
      'seenParticipantsIDs': '',
      'participantsIDs': '',
      'unclaimedRewardsIDs': '',
      'appliedSpecialRules': false,
      'rewards': [
        {'@xsi:type': 'GemsReward', 'amount': {'int': t.rewardGems}}
      ],
      'questKey': t.key,
      'questName': t.raw['nameToken'],
      'questDescription': t.raw['descriptionToken'],
      'requester': 'Qi',
      'orderType': 'Qi',
      'specialRule': t.raw['specialRule'],
      'readyForRemoval': false,
      'itemToRemoveOnEnd': -1,
      'dueDate': totalDays + t.durationDays,
      'duration': t.duration,
      'questState': 'InProgress',
    });
  }

  void offer(String key) {
    final t = _templates[key];
    if (t == null || offered.contains(key)) return;
    _available.children.add(_buildEntry(t));
  }

  void unoffer(String key) {
    for (final o in _available.childrenNamed('SpecialOrder').toList()) {
      if (o.str('questKey') == key) _available.children.remove(o);
    }
  }

  /// Accepts the quest directly (skipping the board's weekly cooldown).
  void accept(String key) {
    final t = _templates[key];
    if (t == null || inProgress.contains(key)) return;
    unoffer(key);
    _active.children.add(_buildEntry(t));
  }

  /// Cancels an in-progress quest and undoes its persistent difficulty bumps.
  void cancel(String key) {
    final orders = _active.childrenNamed('SpecialOrder').toList();
    final cancelled = orders
        .where((o) => o.str('questKey') == key && o.str('questState') == 'InProgress')
        .toList();
    if (cancelled.isEmpty) return;
    for (final o in cancelled) {
      _active.children.remove(o);
    }
    Set<String> rules(Iterable<XmlElement> list) => list
        .where((o) => o.boolean('appliedSpecialRules') == true)
        .expand((o) => (o.str('specialRule') ?? '').split(',').map((r) => r.trim()))
        .toSet();
    final removed = rules(cancelled);
    final retained = rules(_active.childrenNamed('SpecialOrder').where((o) => o.str('questState') == 'InProgress'));
    final root = save.root;
    if (removed.contains('MINE_HARD') && !retained.contains('MINE_HARD')) {
      root.setInt('minesDifficulty', max(0, (root.integer('minesDifficulty') ?? 0) - 1));
      root.setInt('mine_lowestLevelReachedForOrder', -1);
    }
    if (removed.contains('SC_HARD') && !retained.contains('SC_HARD')) {
      root.setInt('skullCavesDifficulty', max(0, (root.integer('skullCavesDifficulty') ?? 0) - 1));
    }
  }
}
