import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../ui/theme.dart';

/// Wrap of language chips; the first chip follows the system language.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key, this.showSystem = true});
  final bool showSystem;

  @override
  Widget build(BuildContext context) {
    final l = L10n.i;
    final p = context.farm;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      if (showSystem)
        ChoiceChip(
          avatar: Icon(Icons.phone_android, size: 16, color: p.woodDark),
          label: Text(tr('System')),
          selected: l.preference == null,
          onSelected: (_) => l.setLanguage(null),
        ),
      for (final e in L10n.languages.entries)
        ChoiceChip(
          label: Text(e.value),
          selected: showSystem ? l.preference == e.key : l.code == e.key,
          onSelected: (_) => l.setLanguage(e.key),
        ),
    ]);
  }
}
