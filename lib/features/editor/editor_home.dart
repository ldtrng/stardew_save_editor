import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../l10n/names.dart';
import 'package:provider/provider.dart';

import '../../ads/ads_service.dart';
import '../../save/save_file.dart';
import '../../state/editor_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'backups_screen.dart';
import 'bundles_screen.dart';
import 'buildings_screen.dart';
import 'character_screen.dart';
import 'appearance_screen.dart';
import 'chests_screen.dart';
import 'inventory_screen.dart';
import 'load_save_screen.dart';
import 'qi_quests_screen.dart';
import 'recipes_screen.dart';
import 'relationships_screen.dart';

class EditorHome extends StatelessWidget {
  const EditorHome({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    if (state.save == null) return LoadSaveScreen();
    return _EditorHub();
  }
}

class _Section {
  const _Section(this.title, this.subtitle, this.icon, this.builder);
  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
}

List<_Section> get _sections => <_Section>[
  _Section(tr('Character'), tr('Money, skills, professions, wallet'), Icons.person_outline, (_) => CharacterScreen()),
  _Section(tr('Appearance'), tr('Hair, skin, eyes, accessories'), Icons.face_retouching_natural, (_) => AppearanceScreen()),
  _Section(tr('Inventory'), tr('Backpack & equipment'), Icons.backpack_outlined, (_) => InventoryScreen()),
  _Section(tr('Chests'), tr('Every chest, fridge & machine'), Icons.inventory_2_outlined, (_) => ChestsScreen()),
  _Section(tr('Relationships'), tr('Hearts & marriage status'), Icons.favorite_border, (_) => RelationshipsScreen()),
  _Section(tr('Cooking'), tr('Unlock cooking recipes'), Icons.restaurant_outlined, (_) => RecipesScreen(cooking: true)),
  _Section(tr('Crafting'), tr('Unlock crafting recipes'), Icons.handyman_outlined, (_) => RecipesScreen(cooking: false)),
  _Section(tr('Bundles'), tr('Community Center progress'), Icons.redeem_outlined, (_) => BundlesScreen()),
  _Section(tr('Buildings'), tr('Buildings & farm animals'), Icons.agriculture_outlined, (_) => BuildingsScreen()),
  _Section(tr("Qi's Quests"), tr('Walnut Room special orders'), Icons.diamond_outlined, (_) => QiQuestsScreen()),
];

class _EditorHub extends StatelessWidget {
  const _EditorHub();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final save = state.save!;
    final p = context.farm;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Save Editor')),
        actions: [
          IconButton(
            tooltip: tr('Backups'),
            icon: Icon(Icons.history),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BackupsScreen())),
          ),
          IconButton(
            tooltip: tr('Close save'),
            icon: Icon(Icons.close),
            onPressed: () => _confirmClose(context, state),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _SaveHeader(save: save, state: state),
          SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 600 ? 3 : 2;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                for (final s in _sections)
                  PixelPanel(
                    padding: EdgeInsets.all(10),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: s.builder))
                        .then((_) => AdsService.instance.onEditorSectionClosed()),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(s.icon, color: p.woodDark, size: 30),
                        Spacer(),
                        Text(s.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        Text(s.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: p.textMuted)),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
      bottomSheet: _SaveBar(state: state),
    );
  }

  Future<void> _confirmClose(BuildContext context, EditorState state) async {
    if (state.dirty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(tr('Discard changes?')),
          content: Text(tr('You have unsaved edits. Close the save anyway?')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Keep editing'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Discard'))),
          ],
        ),
      );
      if (ok != true) return;
    }
    state.close();
  }
}

class _SaveHeader extends StatelessWidget {
  const _SaveHeader({required this.save, required this.state});
  final SaveFile save;
  final EditorState state;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    final player = state.player!;
    final season = seasonName(save.season);
    return PixelPanel(
      color: p.panelAlt,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.agriculture, size: 36),
          SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(player.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              Text(tr('{farm} Farm · {season} {day}, Year {year}', {'farm': player.farmName, 'season': season, 'day': save.dayOfMonth, 'year': save.year}),
                  style: TextStyle(color: p.textMuted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${player.money}g', style: TextStyle(fontSize: 18, color: p.woodDark, fontWeight: FontWeight.w700)),
            Text('v${save.gameVersion}', style: TextStyle(fontSize: 11, color: p.textMuted)),
          ]),
        ]),
        if (save.players.length > 1) ...[
          SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var i = 0; i < save.players.length; i++)
              ChoiceChip(
                label: Text(i == 0 ? '${save.players[i].name} (host)' : save.players[i].name),
                selected: state.playerIndex == i,
                onSelected: (_) => state.selectPlayer(i),
              ),
          ]),
        ],
        SizedBox(height: 6),
        Text(state.sourceUri != null ? tr('Opened from game folder · {file}', {'file': state.fileName}) : tr('File: {file}', {'file': state.fileName}),
            style: TextStyle(fontSize: 12, color: p.textMuted)),
      ]),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.state});
  final EditorState state;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).padding.bottom * 0),
      decoration: BoxDecoration(color: p.woodDark, border: Border(top: BorderSide(color: p.outline, width: 3))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          if (state.busy)
            Padding(
              padding: EdgeInsets.only(right: 10),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 3)),
            ),
          Expanded(
            child: Text(state.dirty ? tr('Unsaved changes') : tr('No changes'),
                style: TextStyle(color: state.dirty ? p.wheat : Colors.white70)),
          ),
          IconButton(
            tooltip: tr('Share'),
            color: Colors.white,
            onPressed: () => state.share(),
            icon: Icon(Icons.share),
          ),
          OutlinedButton(
            onPressed: () async {
              if (await state.saveAs() && context.mounted) showToast(context, tr('Saved a copy'));
            },
            child: Text(tr('Save as…')),
          ),
          if (state.sourceUri != null) ...[
            SizedBox(width: 8),
            FilledButton(
              onPressed: state.busy
                  ? null
                  : () async {
                      try {
                        await state.writeBack();
                        if (context.mounted) showToast(context, tr('Written to game folder (backup kept)'));
                      } catch (e) {
                        if (context.mounted) showToast(context, tr('Write failed: {error}', {'error': e}));
                      }
                    },
              child: Text(tr('Save to game')),
            ),
          ],
        ]),
      ),
    );
  }
}
