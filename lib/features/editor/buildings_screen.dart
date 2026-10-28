import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:provider/provider.dart';


import '../../save/buildings.dart';
import '../../state/editor_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

class BuildingsScreen extends StatelessWidget {
  const BuildingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final save = state.save;
    if (save == null) return SizedBox();
    final buildings = save.buildings();
    final p = context.farm;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Buildings ({n})', {'n': buildings.length}))),
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 40),
        itemCount: buildings.length,
        separatorBuilder: (_, _) => SizedBox(height: 12),
        itemBuilder: (context, i) {
          final b = buildings[i];
          final animals = b.animals;
          return PixelPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 72,
                  height: 72,
                  color: p.grass.withValues(alpha: 0.25),
                  child: PixelImage(b.assetPath, size: 72),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(L10n.i.buildingName(b.type), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    Text('${b.locationName} · tile ${b.tileX},${b.tileY}', style: TextStyle(fontSize: 12, color: p.textMuted)),
                    if (b.capacity != null)
                      Text(tr('{n}/{max} animals', {'n': animals.length, 'max': b.capacity}), style: TextStyle(fontSize: 12, color: p.textMuted)),
                    if (b.daysOfConstructionLeft > 0 || b.daysUntilUpgrade > 0)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Row(children: [
                          PixelTag(b.daysOfConstructionLeft > 0
                              ? tr('Building: {n}d', {'n': b.daysOfConstructionLeft})
                              : tr('Upgrading: {n}d', {'n': b.daysUntilUpgrade}), color: p.wheat),
                          TextButton(
                            onPressed: () {
                              if (b.daysOfConstructionLeft > 0) b.daysOfConstructionLeft = 1;
                              if (b.daysUntilUpgrade > 0) b.daysUntilUpgrade = 1;
                              state.changed();
                            },
                            child: Text(tr('Finish tomorrow')),
                          ),
                        ]),
                      ),
                  ]),
                ),
              ]),
              if (b.isGreenhouse)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('Greenhouse repaired')),
                  value: save.greenhouseUnlocked,
                  onChanged: (v) {
                    save.greenhouseUnlocked = v;
                    state.changed();
                  },
                ),
              for (final a in animals) _AnimalTile(animal: a, onChanged: state.changed),
            ]),
          );
        },
      ),
    );
  }
}

class _AnimalTile extends StatelessWidget {
  const _AnimalTile({required this.animal, required this.onChanged});
  final FarmAnimalView animal;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    return Container(
      margin: EdgeInsets.only(top: 10),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(color: p.panelAlt, border: Border.all(color: p.outline.withValues(alpha: 0.6), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(animal.emoji, style: TextStyle(fontSize: 22)),
          SizedBox(width: 8),
          Expanded(
            child: CommitTextField(
              label: tr(animal.type),
              value: animal.name,
              onChanged: (v) {
                animal.name = v;
                onChanged();
              },
            ),
          ),
        ]),
        SizedBox(height: 6),
        Row(children: [
          SizedBox(width: 80, child: Text(tr('Friendship'))),
          Expanded(
            child: HeartRow(
              hearts: animal.hearts,
              max: 5,
              onTap: (h) {
                animal.friendship = h * 200;
                onChanged();
              },
            ),
          ),
        ]),
        _StatSlider(label: tr('Happiness'), value: animal.happiness, max: 255, onChanged: (v) {
          animal.happiness = v;
          onChanged();
        }),
        _StatSlider(label: tr('Fullness'), value: animal.fullness, max: 255, onChanged: (v) {
          animal.fullness = v;
          onChanged();
        }),
      ]),
    );
  }
}

class _StatSlider extends StatefulWidget {
  const _StatSlider({required this.label, required this.value, required this.max, required this.onChanged});
  final String label;
  final int value, max;
  final ValueChanged<int> onChanged;
  @override
  State<_StatSlider> createState() => _StatSliderState();
}

class _StatSliderState extends State<_StatSlider> {
  double? _drag;
  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(width: 80, child: Text(widget.label)),
        Expanded(
          child: Slider(
            value: (_drag ?? widget.value.toDouble()).clamp(0, widget.max.toDouble()),
            max: widget.max.toDouble(),
            onChanged: (v) => setState(() => _drag = v),
            onChangeEnd: (v) {
              _drag = null;
              widget.onChanged(v.round());
            },
          ),
        ),
        SizedBox(width: 32, child: Text('${(_drag ?? widget.value).round()}', textAlign: TextAlign.right)),
      ]);
}
