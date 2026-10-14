import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../data/game_data.dart';
import '../../state/settings_state.dart';
import '../../state/tracker_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../settings/language_picker.dart';
import '../tracker/tracker_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  final _name = TextEditingController();
  bool _remixed = false;
  bool _error = false;

  List<(String, String, Object?)> get _slides {
    final gd = GameData.i;
    return [
      (tr('Never miss an event'), tr('Birthdays, festivals, the Queen of Sauce and your own to-do notes for every in-game day.'),
          gd.itemsById['221']?['image']),
      (tr('Complete the Community Center'), tr('Track every bundle item and see where and when to find it.'),
          'src_assets_bundles_spring_crops_bundle'),
      (tr('Catch every fish'), tr('Fish, museum, recipes, shipping, walnuts and more – all in one place.'), gd.itemsById['128']?['image']),
      (tr('Edit your save'), tr('Change money, skills, items, relationships and bundles. Backups are kept automatically.'),
          gd.itemsById['74']?['image']),
    ];
  }

  void _finish() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = true);
      return;
    }
    final t = context.read<TrackerState>();
    t.renameFarm(t.farm, name);
    t.setRemixed(_remixed);
    context.read<SettingsState>().setOnboarded();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    final slides = _slides;
    final last = slides.length;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          if (_page == 0)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: LanguagePicker(showSystem: false),
            ),
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                for (final (title, body, img) in slides)
                  Padding(
                    padding: EdgeInsets.all(28),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      PixelPanel(color: p.panelAlt, padding: EdgeInsets.all(18), child: TImage(img, size: 120)),
                      SizedBox(height: 28),
                      Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                      SizedBox(height: 12),
                      Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: p.textMuted)),
                    ]),
                  ),
                Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(tr('Welcome to the valley!'), textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                    SizedBox(height: 20),
                    TextField(
                      controller: _name,
                      maxLength: 30,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20),
                      decoration: InputDecoration(
                        labelText: tr('Farm name'),
                        errorText: _error ? tr('Please name your farm') : null,
                      ),
                      onChanged: (_) => _error ? setState(() => _error = false) : null,
                    ),
                    SwitchListTile(
                      title: Text(tr('Remixed Bundles')),
                      subtitle: Text(tr('Turn on if your farm uses remixed Community Center bundles.')),
                      value: _remixed,
                      onChanged: (v) => setState(() => _remixed = v),
                    ),
                    SizedBox(height: 8),
                    Text(tr('You can add more farms later in Settings.'), textAlign: TextAlign.center, style: TextStyle(color: p.textMuted)),
                  ]),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(children: [
              if (_page < last)
                TextButton(onPressed: () => _pages.animateToPage(last, duration: Duration(milliseconds: 300), curve: Curves.easeOut), child: Text(tr('Skip'))),
              Spacer(),
              for (var i = 0; i <= last; i++)
                Container(
                  width: 10,
                  height: 10,
                  margin: EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(color: i == _page ? p.grassDark : p.panelAlt, border: Border.all(color: p.outline, width: 1.5)),
                ),
              Spacer(),
              FilledButton(
                onPressed: _page < last
                    ? () => _pages.nextPage(duration: Duration(milliseconds: 300), curve: Curves.easeOut)
                    : _finish,
                child: Text(_page < last ? tr('Next') : tr('Get started')),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
