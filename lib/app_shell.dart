import 'package:flutter/material.dart';

import 'l10n/l10n.dart';
import 'package:provider/provider.dart';

import 'ads/ads_service.dart';
import 'dev/screenshot_mode.dart';

import 'features/calendar/calendar_screen.dart';
import 'features/editor/editor_home.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/tracker/collections_hub.dart';
import 'features/villagers/villagers_screen.dart';
import 'state/settings_state.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = screenshotMode ? shotTabs.value : 0;
  static bool _shotsStarted = false;

  @override
  void initState() {
    super.initState();
    if (screenshotMode) {
      shotTabs.addListener(_onShotTab);
      if (!_shotsStarted) {
        _shotsStarted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => runScreenshots(context));
      }
    }
  }

  void _onShotTab() => mounted ? setState(() => _index = shotTabs.value) : null;

  @override
  void dispose() {
    shotTabs.removeListener(_onShotTab);
    super.dispose();
  }

  static const _tabs = [
    CalendarScreen(),
    VillagersScreen(),
    CollectionsHub(),
    EditorHome(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    if (!settings.onboarded) return OnboardingScreen();
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          if (i != _index) AdsService.instance.onTabChanged();
          setState(() => _index = i);
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 64,
        destinations: [
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: tr('Calendar')),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: tr('Villagers')),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: tr('Collections')),
          NavigationDestination(icon: Icon(Icons.edit_note_outlined), selectedIcon: Icon(Icons.edit_note), label: tr('Save Editor')),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: tr('Settings')),
        ],
      ),
    );
  }
}
