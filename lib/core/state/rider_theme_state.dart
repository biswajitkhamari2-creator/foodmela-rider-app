import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode controller for the rider app. Persisted under
/// 'rider_theme_mode' as 'light' | 'dark' | 'system'.
class RiderThemeState extends ChangeNotifier {
  RiderThemeState._(this._mode);
  static const storageKey = 'rider_theme_mode';

  ThemeMode _mode;
  ThemeMode get mode => _mode;

  static Future<RiderThemeState> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey) ?? 'system';
      return RiderThemeState._(_fromString(raw));
    } catch (_) {
      return RiderThemeState._(ThemeMode.system);
    }
  }

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    _persist();
  }

  void toggle() {
    setMode(_mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, _toString(_mode));
    } catch (_) {}
  }

  static ThemeMode _fromString(String v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

/// Global instance — created once in main() before runApp.
late final RiderThemeState riderThemeState;
