import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:flutter/services.dart';

import '../../ui/theme.dart';
import '../../ui/widgets.dart';

const savesPath = 'Android/data/com.chucklefish.stardewvalley/files/Saves';

/// Step-by-step guide for reaching the game's save folder on every Android
/// version.
class SaveGuideScreen extends StatelessWidget {
  const SaveGuideScreen({super.key, this.sdk});
  final int? sdk;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    final modern = (sdk ?? 33) >= 33;
    return DefaultTabController(
      length: 3,
      initialIndex: modern ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Getting your save')),
          bottom: TabBar(tabs: [
            Tab(text: tr('Android ≤ 12')),
            Tab(text: tr('Android 13+')),
            Tab(text: tr('PC / Switch')),
          ]),
        ),
        body: TabBarView(children: [
          _GuideList(children: [
            _Where(p: p),
            _Step(1, tr('Close Stardew Valley completely'), tr('Swipe it away from recent apps so the save is not being written.')),
            _Step(2, tr('Open the Editor tab → "Allow access to Saves folder"'), tr('The system file picker opens directly at the game\'s Saves folder.')),
            _Step(3, tr('Tap "Use this folder", then "Allow"'), tr('If the picker opens somewhere else, browse to Android › data › com.chucklefish.stardewvalley › files › Saves.')),
            _Step(4, tr('Pick your farm, edit, then tap "Save to game"'), tr('The original file is backed up inside this app before it is overwritten.')),
            _Step(5, tr('Start the game and load the farm'), tr('Your changes are applied.')),
            _Note(
                tr('Some Android 12 devices (or ones that received a newer system update) refuse the Android/data folder. '
                'If "Use this folder" is greyed out, follow the Android 13+ tab instead.')),
          ]),
          _GuideList(children: [
            _Where(p: p),
            _Note(
                tr('Since Android 13, Google blocks every app (including this one) from opening Android/data. '
                'You need to copy the save out, edit it here, and copy it back. Pick one of the methods below.')),
            PlankHeader(tr('Method A · Computer + USB cable (easiest)')),
            _Step(1, tr('Close Stardew Valley on the phone'), ''),
            _Step(2, tr('Connect the phone to a computer, choose "File transfer" in the USB notification'), ''),
            _Step(3, tr('On the computer open Internal storage › {path}', {'path': savesPath}),
                tr('Windows: This PC › phone. Mac: use "Android File Transfer" or OpenMTP.')),
            _Step(4, tr('Copy your farm folder (e.g. Farm_123456789) into the phone\'s Download folder'), tr('Keep a copy on the computer as a backup.')),
            _Step(5, tr('In this app: Editor › "Pick save file" › Download › your farm folder › file with the same name'), ''),
            _Step(6, tr('Edit, then tap "Save as…" and save it to Download'), tr('If a file with that name exists, Android adds " (1)" to the new one.')),
            _Step(7, tr('Copy the edited file back into Saves/<your farm>/ from the computer'), tr('It must have exactly the folder\'s name (e.g. Farm_123456789, no extension) – rename it and overwrite the original.')),
            PlankHeader(tr('Method B · ADB (no file transfer UI)')),
            _Step(1, tr('Enable Developer options › USB debugging, connect to a computer with platform-tools'), ''),
            _Command('adb pull /sdcard/$savesPath/'),
            _Step(2, tr('Push the folder to Download, edit it in this app, then push it back:'), ''),
            _Command('adb push Farm_123456789 /sdcard/Download/'),
            _Command('adb push Farm_123456789/Farm_123456789 /sdcard/$savesPath/Farm_123456789/'),
            PlankHeader(tr('Method C · On the phone with Shizuku')),
            _Step(1, tr('Install Shizuku and start it with Wireless debugging (Developer options)'), tr('Shizuku\'s own guide explains the pairing step.')),
            _Step(2, tr('Use a file manager that supports Shizuku to reach Android/data'), tr('Copy your farm folder to Download, edit it here, then copy the edited file back into Saves.')),
            _Note(tr('Always copy back with the game closed, and keep the original until you have checked the edited farm loads.')),
          ]),
          _GuideList(children: [
            PlankHeader(tr('Save locations')),
            _Path('Windows', r'%AppData%\StardewValley\Saves\'),
            _Path('macOS', '~/.config/StardewValley/Saves/'),
            _Path('Linux / Steam Deck', '~/.config/StardewValley/Saves/'),
            _Path('Android', savesPath),
            _Step(1, tr('Copy the farm folder to your phone (USB, cloud drive, chat app…)'), ''),
            _Step(2, tr('Pick the file named like the folder (Farm_123456789)'), tr('The SaveGameInfo file only holds the load-menu preview.')),
            _Step(3, tr('Edit, "Save as…" and copy it back over the original'), ''),
            _Note(tr('Saves are the same format on PC and mobile for version 1.6, so you can also move a farm between platforms. '
                'Console saves (Switch / PlayStation / Xbox) cannot be exported by the console.')),
          ]),
        ]),
      ),
    );
  }
}

class _GuideList extends StatelessWidget {
  const _GuideList({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: EdgeInsets.fromLTRB(16, 8, 16, 32), children: children);
}

class _Where extends StatelessWidget {
  const _Where({required this.p});
  final FarmPalette p;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: 8),
        child: PixelPanel(
          color: p.panelAlt,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Where the game keeps saves'), style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            SelectableText('$savesPath/<FarmName_ID>/'),
            SizedBox(height: 4),
            Text(tr('Each farm folder holds two files: <FarmName_ID> (the save you edit) and SaveGameInfo.'),
                style: TextStyle(fontSize: 12, color: p.textMuted)),
          ]),
        ),
      );
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.title, this.detail);
  final int n;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.grassDark, border: Border.all(color: p.outline, width: 2)),
          child: Text('$n', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (detail.isNotEmpty) Text(detail, style: TextStyle(color: p.textMuted, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: PixelPanel(
        color: p.wheat.withValues(alpha: 0.35),
        shadow: false,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lightbulb_outline, color: p.woodDark),
          SizedBox(width: 8),
          Expanded(child: Text(text)),
        ]),
      ),
    );
  }
}

class _Command extends StatelessWidget {
  const _Command(this.cmd);
  final String cmd;
  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(color: p.outline, border: Border.all(color: p.outline, width: 2)),
      child: Row(children: [
        Expanded(
          child: SelectableText(cmd, style: TextStyle(fontFamily: 'monospace', color: p.wheat, fontSize: 12)),
        ),
        IconButton(
          icon: Icon(Icons.copy, color: p.wheat, size: 18),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: cmd));
            showToast(context, tr('Copied'));
          },
        ),
      ]),
    );
  }
}

class _Path extends StatelessWidget {
  const _Path(this.platform, this.path);
  final String platform;
  final String path;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(tr(platform), style: TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: SelectableText(path)),
        ]),
      );
}
