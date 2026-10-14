import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../l10n/names.dart';

import '../../data/game_data.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Tracker image (from the bundled drawables) with a placeholder.
class TImage extends StatelessWidget {
  const TImage(this.image, {super.key, this.size = 36});
  final Object? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = imagePath(image);
    if (path == null) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.image_not_supported_outlined, size: size * 0.6, color: context.farm.textMuted),
      );
    }
    return PixelImage(path, size: size);
  }
}

/// Square pixel checkbox.
class PixelCheck extends StatelessWidget {
  const PixelCheck({super.key, required this.value, required this.onChanged, this.size = 26});
  final bool value;
  final ValueChanged<bool> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: EdgeInsets.all(6),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: value ? p.grass : p.panel,
            border: Border.all(color: p.outline, width: 2),
          ),
          child: value ? Icon(Icons.check, size: size * 0.8, color: Colors.white) : null,
        ),
      ),
    );
  }
}

class ProgressHeader extends StatelessWidget {
  const ProgressHeader({super.key, required this.done, required this.total, this.label});
  final int done;
  final int total;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    final frac = total == 0 ? 0.0 : done / total;
    return Row(children: [
      Expanded(
        child: Container(
          height: 18,
          decoration: BoxDecoration(color: p.panelAlt, border: Border.all(color: p.outline, width: 2)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: frac.clamp(0, 1),
            child: Container(color: frac >= 1 ? p.wheat : p.grass),
          ),
        ),
      ),
      SizedBox(width: 10),
      Text('${label ?? ''}$done/$total', style: TextStyle(fontWeight: FontWeight.w600)),
    ]);
  }
}

/// Small item reference (ingredient, gift…) with icon and label.
class ItemRefChip extends StatelessWidget {
  const ItemRefChip({super.key, required this.ref, this.amount, this.onTap});
  final Map ref;
  final int? amount;
  final VoidCallback? onTap;

  static String label(Map ref) {
    if (ref['gold'] != null) return '${ref['gold']}g';
    if (ref['id'] != null || ref['category'] != null) return L10n.i.itemName(ref);
    return (ref['name'] ?? '?').toString();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    final a = amount ?? (ref['amount'] as num?)?.toInt();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(4, 3, 8, 3),
        decoration: BoxDecoration(color: p.panelAlt, border: Border.all(color: p.outline.withValues(alpha: 0.7), width: 1.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (ref['image'] != null) TImage(ref['image'], size: 22) else if (ref['gold'] != null) Icon(Icons.monetization_on, size: 20, color: p.wheat),
          SizedBox(width: 4),
          Flexible(child: Text(label(ref) + (a != null && a > 1 ? ' ×$a' : ''), style: TextStyle(fontSize: 13))),
        ]),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.icon});
  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) ...[Icon(icon, size: 18, color: p.woodDark), SizedBox(width: 6)],
        SizedBox(width: 110, child: Text(label, style: TextStyle(color: p.textMuted))),
        Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

/// Horizontal single-select chip row used for filters.
class FilterRow<T> extends StatelessWidget {
  const FilterRow({super.key, required this.options, required this.value, required this.onChanged, required this.label});
  final List<T?> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String Function(T?) label;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final o in options)
              Padding(
                padding: EdgeInsets.only(right: 6),
                child: ChoiceChip(label: Text(label(o)), selected: o == value, onSelected: (_) => onChanged(o)),
              ),
          ],
        ),
      );
}

String seasonLabel(Object? s) => s == null ? tr('Any') : seasonName(s);

const seasonEmoji = {'spring': '🌸', 'summer': '☀️', 'fall': '🍂', 'winter': '❄️'};

class SeasonBadges extends StatelessWidget {
  const SeasonBadges(this.list, {super.key});
  final List? list;
  @override
  Widget build(BuildContext context) {
    final l = (list ?? []).map((e) => e.toString()).toList();
    if (l.length >= 4) return PixelTag(tr('All seasons'));
    return Wrap(spacing: 4, runSpacing: 4, children: [for (final s in l) PixelTag('${seasonEmoji[s] ?? ''} ${seasonName(s)}')]);
  }
}
