// lib/services/lab_theme_manager.dart
//
// Drop-in replacement for the existing ThemeManager — but speaking the
// Lab Console vocabulary (8 themes). Keeps the same Provider /
// ChangeNotifier shape so the rest of the app needs no other changes.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/lab/tokens/lab_themes.dart';

class LabThemeManager extends ChangeNotifier {
  static const _kThemeId = 'lab_theme_id';
  static const _kThemeMode = 'lab_theme_mode'; // 'system' | 'dark' | 'light'

  LabTheme _theme = labThemeSignal;
  ThemeMode _mode = ThemeMode.dark;

  LabTheme get theme => _theme;
  ThemeMode get mode => _mode;
  List<LabTheme> get all => LabThemes.all;

  /// Restore last choice from SharedPreferences.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kThemeId) ?? 'signal';
    final modeStr = prefs.getString(_kThemeMode) ?? 'dark';
    _theme = LabThemes.byId(id);
    _mode = switch (modeStr) {
      'system' => ThemeMode.system,
      'light'  => ThemeMode.light,
      _        => ThemeMode.dark,
    };
    notifyListeners();
  }

  Future<void> setTheme(String id) async {
    _theme = LabThemes.byId(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeId, id);
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, switch (mode) {
      ThemeMode.system => 'system',
      ThemeMode.light  => 'light',
      ThemeMode.dark   => 'dark',
    });
    notifyListeners();
  }
}
