import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../ads/ads_service.dart';
import '../save/farmer.dart';
import '../save/save_file.dart';
import '../services/firebase.dart';
import '../services/saf.dart';
import '../services/review.dart';

class BackupEntry {
  BackupEntry(this.file, this.saveName, this.createdAt, this.size);
  final File file;
  final String saveName;
  final DateTime createdAt;
  final int size;
}

/// Holds the save being edited and handles import/export/backups.
class EditorState extends ChangeNotifier {
  SaveFile? save;
  String fileName = '';
  /// SAF document uri when the save was opened straight from the game folder.
  String? sourceUri;
  int playerIndex = 0;
  bool dirty = false;
  bool busy = false;

  Farmer? get player => save == null ? null : save!.players[playerIndex.clamp(0, save!.players.length - 1)];

  void selectPlayer(int i) {
    playerIndex = i;
    notifyListeners();
  }

  /// Call after any edit so listeners rebuild and the save is marked dirty.
  void changed() {
    dirty = true;
    notifyListeners();
  }

  Future<T> _busy<T>(Future<T> Function() fn) async {
    busy = true;
    notifyListeners();
    try {
      return await fn();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> loadBytes(Uint8List bytes, String name, {String? uri}) => _busy(() async {
        final parsed = await compute(_parseIsolate, (bytes, name));
        save = parsed;
        fileName = name;
        sourceUri = uri;
        playerIndex = 0;
        dirty = false;
        await _backup(bytes, name);
      });

  static SaveFile _parseIsolate((Uint8List, String) args) => SaveFile.parse(args.$1, args.$2);

  /// Opens a save with the system file picker.
  Future<bool> pickFile() async {
    final file = await AdsService.instance.external(() => FilePicker.pickFile(dialogTitle: 'Select your save file'));
    if (file == null) return false;
    final bytes = await file.xFile.readAsBytes();
    await loadBytes(bytes, file.name);
    Analytics.log('save_opened', {'source': 'file_picker'});
    return true;
  }

  Future<void> openFromGameFolder(GameSaveEntry entry) async {
    final bytes = await Saf.read(entry.uri);
    await loadBytes(bytes, entry.folder, uri: entry.uri);
    Analytics.log('save_opened', {'source': 'game_folder'});
  }

  void close() {
    save = null;
    fileName = '';
    sourceUri = null;
    dirty = false;
    notifyListeners();
  }

  Uint8List export() => save!.encode();

  /// Overwrites the original file in the game folder (SAF).
  Future<void> writeBack() => _busy(() async {
        final uri = sourceUri;
        if (uri == null) throw StateError('Save was not opened from the game folder.');
        final current = await Saf.read(uri);
        await _backup(current, fileName, force: true);
        await Saf.write(uri, export());
        dirty = false;
        AdsService.instance.onSaveExported('write_back');
        ReviewPrompt.positiveMoment();
      });

  /// "Save as…" through the system document picker.
  Future<bool> saveAs() async {
    final bytes = export();
    final uri = await AdsService.instance.external(() => Saf.createDocument(fileName, bytes));
    if (uri != null) {
      dirty = false;
      notifyListeners();
      AdsService.instance.onSaveExported('save_as');
      ReviewPrompt.positiveMoment();
    }
    return uri != null;
  }

  Future<void> share() async {
    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/$fileName');
    await out.writeAsBytes(export());
    await AdsService.instance.external(
        () => SharePlus.instance.share(ShareParams(files: [XFile(out.path)], text: 'Stardew Valley save: $fileName')));
  }

  // ---------------- backups ----------------
  static Future<Directory> _backupDir() async {
    final d = Directory('${(await getApplicationDocumentsDirectory()).path}/backups');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static const maxBackups = 30;

  Future<void> _backup(Uint8List bytes, String name, {bool force = false}) async {
    final dir = await _backupDir();
    final existing = await listBackups();
    if (!force) {
      for (final b in existing.where((b) => b.saveName == name && b.size == bytes.length)) {
        if (listEquals(await b.file.readAsBytes(), bytes)) return;
      }
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    await File('${dir.path}/$stamp~$name').writeAsBytes(bytes);
    final all = await listBackups();
    for (final old in all.skip(maxBackups)) {
      await old.file.delete();
    }
  }

  static Future<List<BackupEntry>> listBackups() async {
    final dir = await _backupDir();
    final out = <BackupEntry>[];
    for (final f in dir.listSync().whereType<File>()) {
      final base = f.uri.pathSegments.last;
      final sep = base.indexOf('~');
      if (sep < 0) continue;
      final ts = int.tryParse(base.substring(0, sep));
      if (ts == null) continue;
      out.add(BackupEntry(f, base.substring(sep + 1), DateTime.fromMillisecondsSinceEpoch(ts), f.lengthSync()));
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<void> openBackup(BackupEntry b) async {
    await loadBytes(await b.file.readAsBytes(), b.saveName);
  }

  Future<void> exportBackup(BackupEntry b) async {
    final bytes = await b.file.readAsBytes();
    await AdsService.instance.external(() => Saf.createDocument(b.saveName, bytes));
  }
}
