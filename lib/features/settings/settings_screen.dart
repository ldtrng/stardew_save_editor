import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ads/ads_service.dart';
import '../../save/save_file.dart';
import '../../services/save_import.dart';
import '../../services/review.dart';
import '../../state/editor_state.dart';
import '../../state/settings_state.dart';
import '../../state/tracker_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../editor/save_guide_screen.dart';
import 'farms_sheet.dart';
import 'language_picker.dart';
import 'privacy_screen.dart';

const playStoreUrl = 'https://play.google.com/store/apps/details?id=io.ld2t.stardew_save_editor';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TrackerState>();
    final s = context.watch<SettingsState>();
    final ads = context.watch<AdsService>();
    final p = context.farm;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Settings'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          PlankHeader(tr('Farm')),
          _Tile(
            icon: Icons.home_work_outlined,
            title: t.farm.name,
            subtitle: tr('{n} farm(s) · tap to switch or add', {'n': t.farms.length}),
            onTap: () => showFarmsSheet(context),
          ),
          _Tile(
            icon: Icons.download_for_offline_outlined,
            title: tr('Import progress from a save file'),
            subtitle: tr('Fills fish, shipping, cooking, crafting, museum, bundles, hearts and date'),
            onTap: () => importFromSave(context),
          ),
          FutureBuilder<bool>(
            future: ads.privacyOptionsRequired(),
            builder: (context, snap) => snap.data == true
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    PlankHeader(tr('Ads')),
                    _Tile(icon: Icons.privacy_tip_outlined, title: tr('Ad privacy choices'), onTap: ads.showPrivacyOptions),
                  ])
                : SizedBox.shrink(),
          ),
          PlankHeader(tr('Language')),
          const LanguagePicker(),
          PlankHeader(tr('App settings')),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(value: ThemeMode.system, label: Text(tr('System')), icon: Icon(Icons.brightness_auto)),
                ButtonSegment(value: ThemeMode.light, label: Text(tr('Day')), icon: Icon(Icons.wb_sunny_outlined)),
                ButtonSegment(value: ThemeMode.dark, label: Text(tr('Night')), icon: Icon(Icons.nightlight_outlined)),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => s.setThemeMode(v.first),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('Hide completed in lists')),
            value: s.hideCompleted,
            onChanged: s.setHideCompleted,
          ),
          PlankHeader(tr('Backup')),
          _Tile(
            icon: Icons.upload_file,
            title: tr('Export tracker data'),
            subtitle: tr('Save all farms, checklists and notes to a file'),
            onTap: () => _exportTracker(context),
          ),
          _Tile(
            icon: Icons.file_download_outlined,
            title: tr('Restore tracker data'),
            subtitle: tr('Replace local data with a backup file'),
            onTap: () => _importTracker(context),
          ),
          PlankHeader(tr('Help & support')),
          _Tile(
            icon: Icons.help_outline,
            title: tr('How to get your save file'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SaveGuideScreen())),
          ),
          _Tile(
            icon: Icons.star_outline,
            title: tr('Rate the app'),
            onTap: () => launchUrl(Uri.parse(playStoreUrl), mode: LaunchMode.externalApplication),
          ),
          _Tile(
            icon: Icons.mail_outline,
            title: tr('Contact support'),
            subtitle: supportEmail,
            onTap: () => launchUrl(Uri.parse('mailto:$supportEmail?subject=SV%20Tracker')),
          ),
          PlankHeader(tr('Legal')),
          _Tile(
            icon: Icons.policy_outlined,
            title: tr('Privacy policy'),
            onTap: () async {
              final ok = await launchUrl(Uri.parse(privacyPolicyUrl), mode: LaunchMode.externalApplication);
              if (!ok && context.mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => PrivacyScreen()));
              }
            },
          ),
          _Tile(
            icon: Icons.gavel_outlined,
            title: tr('Terms of use'),
            onTap: () => launchUrl(Uri.parse(termsUrl), mode: LaunchMode.externalApplication),
          ),
          _Tile(
            icon: Icons.code,
            title: tr('Open-source licenses'),
            onTap: () => showLicensePage(context: context, applicationName: 'Tracker & Save Editor: Stardew Valley'),
          ),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) => _Tile(
              icon: Icons.info_outline,
              title: tr('Version'),
              subtitle: snap.data == null ? '' : '${snap.data!.version} (${snap.data!.buildNumber})',
            ),
          ),
          SizedBox(height: 12),
          Text(
            tr('Unofficial fan-made companion. Not affiliated with or endorsed by ConcernedApe. '
            'Stardew Valley content and artwork are owned and copyrighted by ConcernedApe LLC. '
            'Save editing is done at your own risk; a backup is kept for every save you open.'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: p.textMuted),
          ),
          SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: p.berry),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(tr('Remove all data')),
                  content: Text(tr('This removes every farm, checklist and note. This action is irreversible.')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Cancel'))),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Delete'))),
                  ],
                ),
              );
              if (ok == true) t.resetAll();
            },
            icon: Icon(Icons.delete_forever),
            label: Text(tr('Remove all data')),
          ),
        ],
      ),
    );
  }

  Future<void> _exportTracker(BuildContext context) async {
    final t = context.read<TrackerState>();
    final bytes = utf8.encode(t.exportJson());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sv_tracker_backup.json');
    await file.writeAsBytes(bytes);
    await AdsService.instance.external(
        () => SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'SV Tracker backup')));
    AdsService.instance.onTaskDone('tracker_export');
  }

  Future<void> _importTracker(BuildContext context) async {
    final t = context.read<TrackerState>();
    final f = await AdsService.instance.external(() => FilePicker.pickFile(dialogTitle: tr('Select backup file')));
    if (f == null) return;
    try {
      t.importJson(utf8.decode(await f.xFile.readAsBytes()));
      if (context.mounted) showToast(context, tr('Tracker data restored'));
      AdsService.instance.onTaskDone('tracker_import');
    } catch (e) {
      if (context.mounted) showToast(context, tr('Not a valid backup file'));
    }
  }
}

/// Imports checklist progress from the save open in the editor, or asks the
/// user to pick one.
Future<void> importFromSave(BuildContext context) async {
  final editor = context.read<EditorState>();
  final tracker = context.read<TrackerState>();
  SaveFile? save = editor.save;
  if (save == null) {
    try {
      if (!await editor.pickFile(showAd: false)) return;
      save = editor.save;
    } catch (e) {
      if (context.mounted) showToast(context, tr('Could not read save: {error}', {'error': e}));
      return;
    }
  }
  if (save == null || !context.mounted) return;
  var index = editor.playerIndex;
  if (save.players.length > 1) {
    final picked = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(tr('Import which farmer?')),
        children: [
          for (var i = 0; i < save!.players.length; i++)
            SimpleDialogOption(onPressed: () => Navigator.pop(c, i), child: Text(save.players[i].name)),
        ],
      ),
    );
    if (picked == null) return;
    index = picked;
  }
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(tr('Import progress')),
      content: Text(tr('Mark everything already done in "{save}" on the tracker farm "{farm}"? Existing checks are kept.',
          {'save': save!.players[index].farmName, 'farm': tracker.farm.name})),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Import'))),
      ],
    ),
  );
  if (ok != true) return;
  final summary = SaveImporter(save, playerIndex: index).apply(tracker);
  if (!context.mounted) return;
  await showImportSummary(context, summary);
  AdsService.instance.onProgressImported();
  ReviewPrompt.positiveMoment();
}

Future<void> showImportSummary(BuildContext context, ImportSummary summary) => showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Imported')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final e in summary.counts.entries) Text('${tr(e.key)}: ${e.value}')],
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: Text(tr('OK')))],
      ),
    );

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null || subtitle!.isEmpty ? null : Text(subtitle!, style: TextStyle(color: context.farm.textMuted, fontSize: 12)),
        trailing: onTap == null ? null : Icon(Icons.chevron_right),
        onTap: onTap,
      );
}
