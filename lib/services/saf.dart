import 'package:flutter/services.dart';

class GameSaveEntry {
  GameSaveEntry({required this.folder, required this.uri, required this.modified, required this.size, this.infoUri});
  final String folder;
  final String uri;
  final String? infoUri;
  final DateTime modified;
  final int size;

  /// Folder names look like "Farmname_123456789".
  String get farmName {
    final i = folder.lastIndexOf('_');
    return i > 0 ? folder.substring(0, i) : folder;
  }
}

/// Bridge to MainActivity.kt (Storage Access Framework).
class Saf {
  static const _ch = MethodChannel('sdv/saf');

  static int? _sdk;
  static Future<int> sdkInt() async => _sdk ??= await _ch.invokeMethod<int>('sdkInt') ?? 0;

  /// Folder access to Android/data is only possible up to Android 12 (API 32).
  static Future<bool> folderAccessSupported() async => (await sdkInt()) <= 32;

  static Future<bool> isGameInstalled() async =>
      await _ch.invokeMethod<bool>('isGameInstalled') ?? false;

  static Future<String?> pickTree({bool gameFolder = true}) =>
      _ch.invokeMethod<String>('pickTree', {'gameFolder': gameFolder});

  static Future<List<String>> persistedTrees() async =>
      (await _ch.invokeListMethod<String>('persistedTrees')) ?? [];

  static Future<void> releaseTree(String uri) => _ch.invokeMethod('releaseTree', {'uri': uri});

  static Future<List<GameSaveEntry>> listSaves(String treeUri) async {
    final list = await _ch.invokeListMethod<Map>('listSaves', {'uri': treeUri}) ?? [];
    return [
      for (final m in list)
        GameSaveEntry(
          folder: m['folder'] as String,
          uri: m['uri'] as String,
          infoUri: m['infoUri'] as String?,
          modified: DateTime.fromMillisecondsSinceEpoch((m['modified'] as num).toInt()),
          size: (m['size'] as num).toInt(),
        ),
    ];
  }

  static Future<Uint8List> read(String uri) async =>
      (await _ch.invokeMethod<Uint8List>('readDoc', {'uri': uri}))!;

  /// System "save as" dialog; returns the created document uri or null.
  static Future<String?> createDocument(String name, Uint8List bytes) =>
      _ch.invokeMethod<String>('createDocument', {'name': name, 'bytes': bytes});

  static Future<void> write(String uri, Uint8List bytes) =>
      _ch.invokeMethod('writeDoc', {'uri': uri, 'bytes': bytes});
}
