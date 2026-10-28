import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../l10n/names.dart';
import 'package:provider/provider.dart';

import '../../ads/ads_service.dart';

import '../../save/farmer.dart';
import '../../save/game_constants.dart';
import '../../state/editor_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

class RelationshipsScreen extends StatelessWidget {
  const RelationshipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final f = state.player;
    if (f == null) return SizedBox();
    final list = f.friendships;
    final missing = socialNpcs.where((n) => !list.any((x) => x.name == n)).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Relationships')),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'max' && !await AdsService.instance.unlockTools(context, 'Max all hearts')) return;
              for (final fr in f.friendships) {
                if (v == 'max') fr.points = fr.maxPoints;
                if (v == 'reset') fr.points = 0;
              }
              state.changed();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'max', child: Text(tr('Max all hearts'))),
              PopupMenuItem(value: 'reset', child: Text(tr('Reset all to 0'))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          if (missing > 0)
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: () {
                  final n = f.addMissingFriendships();
                  state.changed();
                  showToast(context, 'Added $n villagers');
                },
                icon: Icon(Icons.person_add_alt),
                label: Text(tr("Add {n} villagers you haven't met", {'n': missing})),
              ),
            ),
          for (final fr in list) ...[
            _FriendCard(fr: fr, onChanged: state.changed),
            SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({required this.fr, required this.onChanged});
  final Friendship fr;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    return PixelPanel(
      padding: EdgeInsets.all(8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          decoration: BoxDecoration(border: Border.all(color: p.outline, width: 2), color: p.panelAlt),
          child: SheetSprite(asset: 'assets/editor/portraits/${fr.name}.png', src: Rect.fromLTWH(0, 0, 64, 64), size: 56),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(villagerName(fr.name), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
              Text('${fr.points} pts', style: TextStyle(color: p.textMuted, fontSize: 12)),
            ]),
            SizedBox(height: 4),
            HeartRow(
              hearts: fr.hearts,
              max: fr.maxHearts,
              onTap: (h) {
                fr.hearts = h;
                onChanged();
              },
            ),
            if (fr.dateable) ...[
              SizedBox(height: 6),
              Wrap(spacing: 4, runSpacing: 4, children: [
                for (final s in friendshipStatuses)
                  ChoiceChip(
                    label: Text(tr(s), style: TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    selected: fr.status == s,
                    onSelected: (_) {
                      fr.status = s;
                      if (fr.points > fr.maxPoints) fr.points = fr.maxPoints;
                      onChanged();
                    },
                  ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}
