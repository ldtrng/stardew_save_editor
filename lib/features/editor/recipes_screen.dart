import 'dart:convert';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../l10n/names.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../ads/ads_service.dart';
import '../../ads/banner_ad.dart';

import '../../save/game_constants.dart';
import '../../save/items.dart';
import '../../state/editor_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key, required this.cooking});
  final bool cooking;
  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  List<String>? _all;
  String _query = '';

  String get _container => widget.cooking ? 'cookingRecipes' : 'craftingRecipes';

  @override
  void initState() {
    super.initState();
    rootBundle
        .loadString('assets/editor/data/${widget.cooking ? 'cooking' : 'crafting'}recipes.json')
        .then((s) => setState(() => _all = (jsonDecode(s) as List).cast<String>()));
  }

  ItemInfo? _info(String recipe) {
    final db = ItemDb.instance;
    return db.byName[recipeDisplayNames[recipe] ?? recipe] ?? db.byName[recipe];
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final f = state.player;
    final all = _all;
    if (f == null || all == null) return Scaffold(body: Center(child: CircularProgressIndicator()));
    final known = f.recipes(_container);
    final p = context.farm;
    final q = _query.toLowerCase();
    String label(String r) {
      final info = _info(r);
      return info == null ? (recipeDisplayNames[r] ?? r) : editorItemName(info);
    }

    final shown = all
        .where((r) => q.isEmpty || label(r).toLowerCase().contains(q) || (recipeDisplayNames[r] ?? r).toLowerCase().contains(q))
        .toList();
    return Scaffold(
      bottomNavigationBar: SafeArea(child: AdBanner()),
      appBar: AppBar(
        title: Text('${widget.cooking ? tr('Cooking') : tr('Crafting')} ${known.keys.where(all.contains).length}/${all.length}'),
        actions: [
          PopupMenuButton<bool>(
            onSelected: (v) async {
              if (v && !await AdsService.instance.unlockTools(context, 'Unlock all recipes')) return;
              for (final r in all) {
                f.setRecipe(_container, r, v);
              }
              state.changed();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: true, child: Text(tr('Unlock all'))),
              PopupMenuItem(value: false, child: Text(tr('Lock all'))),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(prefixIcon: Icon(Icons.search), hintText: tr('Search recipes')),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: 32),
            itemCount: shown.length,
            itemBuilder: (context, i) {
              final r = shown[i];
              final unlocked = known.containsKey(r);
              final made = known[r] ?? 0;
              return CheckboxListTile(
                value: unlocked,
                onChanged: (v) {
                  f.setRecipe(_container, r, v ?? false);
                  state.changed();
                },
                secondary: ItemIcon(info: _info(r), size: 34),
                title: Text(label(r)),
                subtitle: unlocked && made > 0
                    ? Text(widget.cooking ? tr('Cooked {n}×', {'n': made}) : tr('Crafted {n}×', {'n': made}), style: TextStyle(color: p.textMuted, fontSize: 12))
                    : null,
              );
            },
          ),
        ),
      ]),
    );
  }
}
