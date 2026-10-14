import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ads/ads_service.dart';
import '../../services/saf.dart';
import '../../state/editor_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'backups_screen.dart';
import 'save_guide_screen.dart';

const _treePrefKey = 'saf_tree_uri';

class LoadSaveScreen extends StatefulWidget {
  const LoadSaveScreen({super.key});

  @override
  State<LoadSaveScreen> createState() => _LoadSaveScreenState();
}

class _LoadSaveScreenState extends State<LoadSaveScreen> {
  int? _sdk;
  bool _gameInstalled = false;
  String? _treeUri;
  List<GameSaveEntry>? _saves;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final sdk = await Saf.sdkInt();
      final installed = await Saf.isGameInstalled();
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_treePrefKey);
      final persisted = await Saf.persistedTrees();
      setState(() {
        _sdk = sdk;
        _gameInstalled = installed;
        _treeUri = (stored != null && persisted.contains(stored)) ? stored : null;
      });
      if (_treeUri != null) await _refresh();
    } catch (e) {
      setState(() => _sdk = 0);
    }
  }

  Future<void> _refresh() async {
    final uri = _treeUri;
    if (uri == null) return;
    try {
      final saves = await Saf.listSaves(uri);
      setState(() {
        _saves = saves;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = tr('Could not read the folder: {error}', {'error': e}));
    }
  }

  Future<void> _grantFolder() async {
    final uri = await AdsService.instance.external(() => Saf.pickTree());
    if (uri == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_treePrefKey, uri);
    setState(() => _treeUri = uri);
    await _refresh();
    if ((_saves ?? []).isEmpty && mounted) {
      showToast(context, tr('No saves found there. Pick the "Saves" folder of Stardew Valley.'));
    }
  }

  Future<void> _forgetFolder() async {
    final uri = _treeUri;
    if (uri != null) await Saf.releaseTree(uri);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_treePrefKey);
    setState(() {
      _treeUri = null;
      _saves = null;
    });
  }

  Future<void> _run(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(tr("Couldn't open save")),
            content: Text('$e'),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('OK')))],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final p = context.farm;
    final folderSupported = (_sdk ?? 99) <= 32;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Save Editor')),
        actions: [
          IconButton(
            tooltip: tr('Backups'),
            icon: Icon(Icons.history),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BackupsScreen())),
          ),
        ],
      ),
      body: state.busy
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(tr('Reading save…')),
            ]))
          : ListView(
              padding: EdgeInsets.all(16),
              children: [
                PixelPanel(
                  color: p.panelAlt,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Edit your farm'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text(
                      tr('Change money, skills, items, relationships, bundles and more. '
                      'A backup of every save you open is kept automatically.'),
                      style: TextStyle(color: p.textMuted),
                    ),
                    if (_sdk != null && !_gameInstalled) ...[
                      SizedBox(height: 8),
                      PixelTag(tr('Stardew Valley is not installed on this device'), color: p.wheat),
                    ],
                  ]),
                ),
                if (folderSupported) ...[
                  PlankHeader(tr('Game folder')),
                  if (_treeUri == null)
                    PixelPanel(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('Open saves directly from the game and write changes back with one tap.')),
                        SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _grantFolder,
                          icon: Icon(Icons.folder_open),
                          label: Text(tr('Allow access to Saves folder')),
                        ),
                        SizedBox(height: 6),
                        Text(tr('In the picker that opens, tap "Use this folder" then "Allow".'),
                            style: TextStyle(fontSize: 12, color: p.textMuted)),
                      ]),
                    )
                  else ...[
                    if (_error != null) Text(_error!, style: TextStyle(color: p.berry)),
                    if (_saves == null)
                      Center(child: CircularProgressIndicator())
                    else if (_saves!.isEmpty)
                      Text(tr('No saves found in the selected folder.'))
                    else
                      for (final s in _saves!)
                        Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: PixelPanel(
                            onTap: () => _run(() => state.openFromGameFolder(s)),
                            child: Row(children: [
                              Icon(Icons.home_work_outlined, color: p.woodDark, size: 32),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(s.farmName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                  Text('${s.folder} · ${DateFormat.yMMMd().add_Hm().format(s.modified)}',
                                      style: TextStyle(fontSize: 12, color: p.textMuted)),
                                ]),
                              ),
                              Icon(Icons.chevron_right),
                            ]),
                          ),
                        ),
                    Row(children: [
                      TextButton.icon(onPressed: _refresh, icon: Icon(Icons.refresh), label: Text(tr('Refresh'))),
                      Spacer(),
                      TextButton(onPressed: _forgetFolder, child: Text(tr('Change folder'))),
                    ]),
                  ],
                ],
                PlankHeader(tr('Open a save file')),
                PixelPanel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(folderSupported
                        ? tr('Or pick a save file you copied somewhere else (Download, PC, cloud…).')
                        : tr('Android {version} blocks apps from reading the game folder. Copy your save out first (see the guide), then pick it here.',
                            {'version': _androidVersion(_sdk)})),
                    SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () => _run(() async {
                        await state.pickFile();
                      }),
                      icon: Icon(Icons.file_open_outlined),
                      label: Text(tr('Pick save file')),
                    ),
                    SizedBox(height: 6),
                    Text(tr('Choose the file named like YourFarm_123456789 (not SaveGameInfo).'),
                        style: TextStyle(fontSize: 12, color: p.textMuted)),
                  ]),
                ),
                SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SaveGuideScreen(sdk: _sdk))),
                  icon: Icon(Icons.help_outline),
                  label: Text(tr('How do I get my save file?')),
                ),
              ],
            ),
    );
  }
}

String _androidVersion(int? sdk) {
  if (sdk == null) return '';
  if (sdk >= 36) return '16';
  if (sdk >= 35) return '15';
  if (sdk >= 34) return '14';
  if (sdk >= 33) return '13';
  return 'this version';
}
