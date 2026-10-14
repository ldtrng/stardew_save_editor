import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'buildings.dart';
import 'bundles.dart';
import 'chests.dart';
import 'farmer.dart';
import 'qi_quests.dart';
import 'xml_ext.dart';

class SaveFormatException implements Exception {
  SaveFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A loaded Stardew Valley 1.6 save. All views edit the underlying XML DOM in
/// place; [encode] serializes it back with the UTF-8 BOM the game writes.
class SaveFile {
  SaveFile._(this.doc, this.fileName) {
    players = _buildPlayers();
  }

  final XmlDocument doc;
  final String fileName;
  late final List<Farmer> players;

  XmlElement get root => doc.rootElement;

  static SaveFile parse(Uint8List bytes, String fileName) {
    String text;
    if (bytes.isNotEmpty && bytes[0] == 0x78) {
      // zlib-compressed save (same check the game uses).
      text = utf8.decode(const ZLibDecoder().decodeBytes(bytes), allowMalformed: true);
    } else {
      text = utf8.decode(bytes, allowMalformed: true);
    }
    if (text.startsWith('﻿')) text = text.substring(1);
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(text);
    } on XmlException catch (e) {
      throw SaveFormatException('Not a valid save file (${e.message}).');
    }
    if (doc.rootElement.name.local != 'SaveGame') {
      if (doc.rootElement.name.local == 'Farmer') {
        throw SaveFormatException(
            'This is the "SaveGameInfo" file. Pick the other file in the save folder (named like Farm_123456789).');
      }
      throw SaveFormatException('Not a Stardew Valley save file.');
    }
    final version = doc.rootElement.str('gameVersion') ?? '';
    if (!version.startsWith('1.6')) {
      throw SaveFormatException('Unsupported game version "$version". Only 1.6.x saves are supported.');
    }
    return SaveFile._(doc, fileName);
  }

  Uint8List encode() {
    final xml = SdvXmlWriter.write(doc);
    final body = utf8.encode(xml);
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...body]);
  }

  String get gameVersion => root.str('gameVersion') ?? '';
  Farmer get mainPlayer => players.first;

  List<Farmer> _buildPlayers() {
    final list = <Farmer>[Farmer(root.child('player')!)];
    final farmhands = root.child('farmhands');
    if (farmhands != null) {
      for (final f in farmhands.childrenNamed('Farmer')) {
        if ((f.str('name') ?? '').trim().isNotEmpty) list.add(Farmer(f));
      }
    }
    return list;
  }

  // ---- world ----
  int get year => root.integer('year') ?? 1;
  String get season => root.str('currentSeason') ?? 'spring';
  int get dayOfMonth => root.integer('dayOfMonth') ?? 1;

  int get goldenWalnuts => root.integer('goldenWalnuts') ?? 0;
  set goldenWalnuts(int v) => root.setInt('goldenWalnuts', v);

  List<XmlElement> get locations =>
      root.child('locations')?.childrenNamed('GameLocation').toList() ?? [];

  XmlElement? location(String name) {
    for (final l in locations) {
      if (l.str('name') == name) return l;
    }
    return null;
  }

  XmlElement? get farm => location('Farm');

  int get hay => farm?.integer('piecesOfHay') ?? 0;
  set hay(int v) => farm?.setInt('piecesOfHay', v);

  bool get greenhouseUnlocked => farm?.boolean('greenhouseUnlocked') ?? false;
  set greenhouseUnlocked(bool v) => farm?.setBool('greenhouseUnlocked', v);

  List<ChestRef> discoverChests() => ChestRef.discover(this);
  List<BuildingView> buildings() => BuildingView.all(this);
  CommunityCenter? communityCenter() => CommunityCenter.load(this);
  QiQuests qiQuests() => QiQuests(this);

  /// Museum donations (item ids) from LibraryMuseum.museumPieces.
  Set<String> get museumDonations {
    final museum = location('ArchaeologyHouse');
    final pieces = museum?.child('museumPieces');
    if (pieces == null) return {};
    return pieces
        .childrenNamed('item')
        .map((i) => i.child('value')?.childElements.firstOrNull?.innerText ?? '')
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  /// Golden walnut / buried-nut tracker flags (team-wide).
  List<String> get collectedNutTracker => root.stringList('collectedNutTracker');
  List<String> get foundBuriedNuts => root.stringList('foundBuriedNuts');
  List<String> get completedSpecialOrders => root.stringList('completedSpecialOrders');
}
