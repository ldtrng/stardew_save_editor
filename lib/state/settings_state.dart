import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  bool hideCompleted = false;
  bool onboarded = false;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[p.getInt('theme_mode') ?? 0];
    hideCompleted = p.getBool('hide_completed') ?? false;
    onboarded = p.getBool('onboarded') ?? false;
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt('theme_mode', m.index);
  }

  Future<void> setHideCompleted(bool v) async {
    hideCompleted = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('hide_completed', v);
  }

  Future<void> setOnboarded() async {
    onboarded = true;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('onboarded', true);
  }
}
