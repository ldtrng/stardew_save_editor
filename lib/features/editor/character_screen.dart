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

class CharacterScreen extends StatelessWidget {
  const CharacterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final save = state.save;
    final player = state.player;
    if (save == null || player == null) return SizedBox();
    void edit(VoidCallback fn) {
      fn();
      state.changed();
    }

    Widget grid(List<Widget> children) => LayoutBuilder(builder: (c, box) {
          final cols = box.maxWidth > 520 ? 3 : 2;
          final w = (box.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(spacing: 10, runSpacing: 12, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
        });

    return Scaffold(
      appBar: AppBar(title: Text(tr('Character'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          PlankHeader(tr('Profile')),
          grid([
            CommitTextField(label: tr('Name'), value: player.name, onChanged: (v) => edit(() => player.name = v), maxLength: 30),
            CommitTextField(label: tr('Farm name'), value: player.farmName, onChanged: (v) => edit(() => player.farmName = v), maxLength: 30),
            CommitTextField(label: tr('Favorite thing'), value: player.favoriteThing, onChanged: (v) => edit(() => player.favoriteThing = v), maxLength: 30),
          ]),
          PlankHeader(tr('Money & stats')),
          grid([
            NumberField(label: tr('Money'), prefix: 'g ', value: player.money, max: 99999999, onChanged: (v) => edit(() => player.money = v)),
            NumberField(label: tr('Total earned'), value: player.totalMoneyEarned, max: 999999999, onChanged: (v) => edit(() => player.totalMoneyEarned = v)),
            NumberField(label: tr('Max health'), value: player.maxHealth, min: 1, max: 99999, onChanged: (v) => edit(() => player.maxHealth = v)),
            NumberField(label: tr('Max energy'), value: player.maxStamina, min: 1, max: 99999, onChanged: (v) => edit(() => player.maxStamina = v)),
            NumberField(label: tr('Qi gems'), value: player.qiGems, max: 99999, onChanged: (v) => edit(() => player.qiGems = v)),
            NumberField(label: tr('Qi coins (casino)'), value: player.clubCoins, max: 99999999, onChanged: (v) => edit(() => player.clubCoins = v)),
            NumberField(label: tr('Hay in silos'), value: save.hay, max: 99999, onChanged: (v) => edit(() => save.hay = v)),
            NumberField(label: tr('Golden walnuts'), value: save.goldenWalnuts, max: 999, onChanged: (v) => edit(() => save.goldenWalnuts = v)),
            NumberField(
                label: tr('Deepest mine level'),
                value: save.mainPlayer.deepestMineLevel,
                max: 77376,
                onChanged: (v) => edit(() => save.mainPlayer.deepestMineLevel = v)),
          ]),
          Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(tr('Mine level: 1–120 = The Mines, 121+ = Skull Cavern.'),
                style: TextStyle(fontSize: 12, color: context.farm.textMuted)),
          ),
          PlankHeader(
            tr('Skills'),
            trailing: TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () async {
                if (!await AdsService.instance.unlockTools(context, 'Max all skills')) return;
                for (final s in Farmer.skillOrder) {
                  player.setExperience(s, Farmer.xpForLevel.last);
                }
                state.changed();
              },
              child: Text(tr('Max all')),
            ),
          ),
          for (final skill in Farmer.skillOrder) _SkillRow(player: player, skill: skill, onChanged: state.changed),
          PlankHeader(tr('Professions')),
          Text(tr('Choosing a level-10 profession also selects its level-5 parent.'),
              style: TextStyle(fontSize: 12, color: context.farm.textMuted)),
          SizedBox(height: 6),
          for (final tree in Professions.trees) _ProfessionTree(player: player, tree: tree, onChanged: state.changed),
          PlankHeader(tr('Wallet')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (flag, label, emoji) in walletItems)
              FilterChip(
                label: Text('$emoji ${tr(label)}'),
                selected: player.hasMail(flag),
                onSelected: (v) => edit(() => player.setMail(flag, v)),
              ),
          ]),
        ],
      ),
    );
  }
}

const _skillEmoji = {'farming': '🥕', 'fishing': '🎣', 'foraging': '🌳', 'mining': '⛏️', 'combat': '⚔️'};

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.player, required this.skill, required this.onChanged});
  final Farmer player;
  final String skill;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    final xp = player.experience(skill);
    final level = Farmer.levelForXp(xp);
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: PixelPanel(
        padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${_skillEmoji[skill]} ${skillName(skill)}',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            Spacer(),
            Text(tr('Lv {level} · {xp} XP', {'level': level, 'xp': xp}), style: TextStyle(color: p.textMuted)),
          ]),
          SizedBox(height: 6),
          Row(children: [
            for (var i = 1; i <= 10; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    final target = level == i ? i - 1 : i;
                    player.setExperience(skill, Farmer.xpForLevel[target]);
                    onChanged();
                  },
                  child: Container(
                    height: 22,
                    margin: EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: i <= level ? (i == 5 || i == 10 ? p.wheat : p.grass) : p.panelAlt,
                      border: Border.all(color: p.outline, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text('$i', style: TextStyle(fontSize: 11, color: i <= level ? p.outline : p.textMuted)),
                  ),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _ProfessionTree extends StatelessWidget {
  const _ProfessionTree({required this.player, required this.tree, required this.onChanged});
  final Farmer player;
  final SkillTree tree;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    Widget chip(int id) {
      final prof = Professions.all[id]!;
      final on = player.hasProfession(id);
      return Tooltip(
        message: tr(prof.description),
        child: FilterChip(
          label: Text(tr(prof.name)),
          selected: on,
          onSelected: (v) {
            player.setProfession(id, v);
            onChanged();
          },
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: PixelPanel(
        padding: EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_skillEmoji[tree.skill]} ${skillName(tree.skill)}',
              style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          for (final primary in tree.primary)
            Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Row(children: [
                SizedBox(width: 130, child: chip(primary)),
                Icon(Icons.arrow_right, color: p.textMuted),
                Expanded(child: Wrap(spacing: 6, runSpacing: 4, children: [for (final s in tree.secondary[primary]!) chip(s)])),
              ]),
            ),
        ]),
      ),
    );
  }
}
