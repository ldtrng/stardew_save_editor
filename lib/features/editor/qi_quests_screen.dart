import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../ads/banner_ad.dart';

import '../../save/qi_quests.dart';
import '../../state/editor_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

class QiQuestsScreen extends StatelessWidget {
  const QiQuestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final save = state.save;
    if (save == null) return SizedBox();
    final qi = save.qiQuests();
    final offered = qi.offered;
    final active = qi.inProgress;
    final p = context.farm;
    return Scaffold(
      bottomNavigationBar: SafeArea(child: AdBanner()),
      appBar: AppBar(title: Text(tr("Qi's Special Orders"))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          Text(tr('The Walnut Room board offers up to {n} quests. "Accept now" starts a quest immediately, skipping the weekly limit.',
              {'n': QiQuests.maxOffered}),
              style: TextStyle(color: p.textMuted, fontSize: 13)),
          SizedBox(height: 8),
          for (final t in QiQuestTemplate.all) ...[
            PixelPanel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(t.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                  PixelTag('💎 ${t.rewardGems}', color: p.wheat),
                ]),
                SizedBox(height: 4),
                Text(t.description, style: TextStyle(fontSize: 13, color: p.textMuted)),
                SizedBox(height: 4),
                Text(tr('Duration: {n} days', {'n': t.durationDays}), style: TextStyle(fontSize: 12)),
                SizedBox(height: 8),
                if (active.contains(t.key))
                  Row(children: [
                    PixelTag(tr('In progress'), color: p.grass),
                    Spacer(),
                    TextButton(
                      onPressed: () {
                        qi.cancel(t.key);
                        state.changed();
                      },
                      child: Text(tr('Cancel quest')),
                    ),
                  ])
                else
                  Row(children: [
                    FilterChip(
                      label: Text(tr('On board')),
                      selected: offered.contains(t.key),
                      onSelected: (v) {
                        if (v && qi.boardFull) {
                          showToast(context, tr('The board already shows {n} quests', {'n': QiQuests.maxOffered}));
                          return;
                        }
                        v ? qi.offer(t.key) : qi.unoffer(t.key);
                        state.changed();
                      },
                    ),
                    Spacer(),
                    FilledButton(
                      onPressed: () {
                        qi.accept(t.key);
                        state.changed();
                      },
                      child: Text(tr('Accept now')),
                    ),
                  ]),
              ]),
            ),
            SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
