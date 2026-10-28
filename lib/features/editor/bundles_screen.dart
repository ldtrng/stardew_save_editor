import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../ads/ads_service.dart';

import '../../save/bundles.dart';
import '../../state/editor_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

const _bundleColors = [
  Color(0xFF6BAF4A), Color(0xFF9B6BC4), Color(0xFFE38B3C), Color(0xFFE9C64A),
  Color(0xFFD25B4B), Color(0xFF5B9BD5), Color(0xFF3FB5A5),
];

class BundlesScreen extends StatefulWidget {
  const BundlesScreen({super.key});
  @override
  State<BundlesScreen> createState() => _BundlesScreenState();
}

class _BundlesScreenState extends State<BundlesScreen> {
  CommunityCenter? _cc;
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    if (!_loaded) {
      _cc = state.save?.communityCenter();
      _loaded = true;
    }
    final cc = _cc;
    if (cc == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Bundles'))),
        body: EmptyState(icon: Icons.redeem_outlined, title: tr('No Community Center bundles in this save')),
      );
    }
    void changed() {
      cc.applySideEffects();
      state.changed();
    }

    final rooms = cc.byRoom;
    final p = context.farm;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Community Center'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          if (cc.isJoja)
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: PixelTag(tr('Joja member route'), color: p.sky),
            ),
          for (final entry in rooms.entries) ...[
            PlankHeader(
              '${tr(entry.key.label)}  ${entry.value.where((b) => b.completed).length}/${entry.value.length}',
              trailing: TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () async {
                  final allDone = entry.value.every((b) => b.completed);
                  if (!allDone && !await AdsService.instance.unlockTools(context, tr('Complete {room}', {'room': tr(entry.key.label)}))) return;
                  for (final b in entry.value) {
                    b.setCompleted(!allDone);
                  }
                  changed();
                },
                child: Text(entry.value.every((b) => b.completed) ? tr('Reset') : tr('Complete')),
              ),
            ),
            for (final b in entry.value) ...[
              _BundleCard(bundle: b, onChanged: changed),
              SizedBox(height: 8),
            ],
          ],
          SizedBox(height: 8),
          Text(tr('Completing a room also sets the mail flags the game uses to restore it (bus, bridge, greenhouse…).'),
              style: TextStyle(fontSize: 12, color: p.textMuted)),
        ],
      ),
    );
  }
}

class _BundleCard extends StatelessWidget {
  const _BundleCard({required this.bundle, required this.onChanged});
  final Bundle bundle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    final reqs = bundle.requirements;
    final color = _bundleColors[(bundle.color ?? 0).clamp(0, _bundleColors.length - 1)];
    return PixelPanel(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        shape: Border(),
        collapsedShape: Border(),
        leading: Container(
          width: 14,
          height: 36,
          decoration: BoxDecoration(color: color, border: Border.all(color: p.outline, width: 1.5)),
        ),
        title: Text(L10n.i.bundleName('${bundle.roomName}/${bundle.spriteIndex}', bundle.name), style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${bundle.submittedCount}/${bundle.requiredCount} · Reward: ${bundle.rewardLabel}',
            style: TextStyle(fontSize: 12, color: p.textMuted)),
        trailing: Checkbox(
          value: bundle.completed,
          onChanged: (v) {
            bundle.setCompleted(v ?? false);
            onChanged();
          },
        ),
        children: [
          for (var i = 0; i < reqs.length; i++)
            CheckboxListTile(
              dense: true,
              value: bundle.isSubmitted(i),
              onChanged: (v) {
                bundle.setSubmitted(i, v ?? false);
                onChanged();
              },
              secondary: reqs[i].isMoney
                  ? Icon(Icons.monetization_on, color: p.wheat)
                  : ItemIcon(info: reqs[i].info, size: 28),
              title: Text('${reqs[i].isMoney ? reqs[i].label : L10n.i.itemName({'id': reqs[i].itemId}, reqs[i].label)}${reqs[i].quantity > 1 && !reqs[i].isMoney ? ' ×${reqs[i].quantity}' : ''}'),
              subtitle: reqs[i].quality > 0
                  ? Text(tr({1: 'Silver+', 2: 'Gold+', 3: 'Iridium', 4: 'Iridium'}[reqs[i].quality] ?? ''),
                      style: TextStyle(fontSize: 11, color: p.textMuted))
                  : null,
            ),
        ],
      ),
    );
  }
}
