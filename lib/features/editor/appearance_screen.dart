import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:provider/provider.dart';


import '../../save/color.dart';
import '../../state/editor_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'farmer_preview.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final f = state.player;
    if (f == null) return SizedBox();
    final p = context.farm;
    void edit(VoidCallback fn) {
      fn();
      state.changed();
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('Appearance'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Center(
            child: PixelPanel(
              color: p.sky.withValues(alpha: 0.5),
              padding: EdgeInsets.all(16),
              child: FarmerPreview(farmer: f, scale: 6),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(tr('Male'))),
                ButtonSegment(value: false, label: Text(tr('Female'))),
              ],
              selected: {f.isMale},
              onSelectionChanged: (s) => edit(() => f.isMale = s.first),
            ),
          ),
          PlankHeader(tr('Body')),
          _Stepper(label: tr('Skin tone'), value: f.skin, min: 0, max: 23, onChanged: (v) => edit(() => f.skin = v)),
          _Stepper(label: tr('Hairstyle'), value: f.hairstyle, min: 0, max: 73, onChanged: (v) => edit(() => f.hairstyle = v)),
          _Stepper(
              label: tr('Accessory'),
              value: f.accessory,
              min: -1,
              max: 29,
              display: (v) => v < 0 ? tr('None') : '$v',
              onChanged: (v) => edit(() => f.accessory = v)),
          PlankHeader(tr('Colors')),
          _ColorRow(label: tr('Hair color'), color: f.hairColor, onChanged: (c) => edit(() => f.hairColor = c)),
          _ColorRow(label: tr('Eye color'), color: f.eyeColor, onChanged: (c) => edit(() => f.eyeColor = c)),
          for (final slot in ['shirtItem', 'pantsItem'])
            if (f.equipment(slot)?.clothesColor != null)
              _ColorRow(
                label: slot == 'shirtItem' ? tr('Shirt dye') : tr('Pants dye'),
                color: f.equipment(slot)!.clothesColor!,
                onChanged: (c) => edit(() => f.equipment(slot)!.clothesColor = c),
              ),
          SizedBox(height: 8),
          Text(tr('Change clothes, hat and boots from the Inventory screen.'),
              style: TextStyle(fontSize: 12, color: p.textMuted)),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.min, required this.max, required this.onChanged, this.display});
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;
  final String Function(int)? display;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 16))),
        IconButton.outlined(
          onPressed: () => onChanged(value <= min ? max : value - 1),
          icon: Icon(Icons.chevron_left),
          style: IconButton.styleFrom(shape: RoundedRectangleBorder()),
        ),
        SizedBox(
          width: 56,
          child: Text(display?.call(value) ?? '$value',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        IconButton.outlined(
          onPressed: () => onChanged(value >= max ? min : value + 1),
          icon: Icon(Icons.chevron_right),
          style: IconButton.styleFrom(shape: RoundedRectangleBorder()),
        ),
      ]),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.label, required this.color, required this.onChanged});
  final String label;
  final SdvColor color;
  final ValueChanged<SdvColor> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 16))),
        Text(color.toHex().toUpperCase(), style: TextStyle(color: p.textMuted)),
        SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDialog<SdvColor>(context: context, builder: (_) => _ColorDialog(initial: color));
            if (picked != null) onChanged(picked);
          },
          child: Container(
            width: 44,
            height: 32,
            decoration: BoxDecoration(
              color: Color.fromARGB(255, color.r, color.g, color.b),
              border: Border.all(color: p.outline, width: 2),
            ),
          ),
        ),
      ]),
    );
  }
}

const _swatches = [
  0xFF2B1A0E, 0xFF5B3A1E, 0xFF8B5A2B, 0xFFC68642, 0xFFE8C07D, 0xFFF4E3B1,
  0xFF1F1F1F, 0xFF6E6E6E, 0xFFE6E6E6, 0xFFB03A2E, 0xFFE07B39, 0xFFF2C14E,
  0xFF6AA84F, 0xFF2E7D32, 0xFF3D85C6, 0xFF1C4587, 0xFF8E44AD, 0xFFE91E63,
];

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.initial});
  final SdvColor initial;
  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late int r = widget.initial.r, g = widget.initial.g, b = widget.initial.b;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    Widget slider(String l, int v, ValueChanged<int> set, Color c) => Row(children: [
          SizedBox(width: 20, child: Text(l)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(activeTrackColor: c),
              child: Slider(value: v.toDouble(), max: 255, onChanged: (x) => setState(() => set(x.round()))),
            ),
          ),
          SizedBox(width: 34, child: Text('$v', textAlign: TextAlign.right)),
        ]);
    return AlertDialog(
      title: Text(tr('Pick a color')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          height: 44,
          decoration: BoxDecoration(color: Color.fromARGB(255, r, g, b), border: Border.all(color: p.outline, width: 2)),
        ),
        SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in _swatches)
            GestureDetector(
              onTap: () => setState(() {
                r = (s >> 16) & 0xff;
                g = (s >> 8) & 0xff;
                b = s & 0xff;
              }),
              child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Color(s), border: Border.all(color: p.outline, width: 1.5))),
            ),
        ]),
        SizedBox(height: 8),
        slider('R', r, (v) => r = v, Colors.red),
        slider('G', g, (v) => g = v, Colors.green),
        slider('B', b, (v) => b = v, Colors.blue),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(context, SdvColor(r, g, b)), child: Text(tr('Apply'))),
      ],
    );
  }
}
