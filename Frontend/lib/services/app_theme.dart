import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static const _kModeKey = 'theme_mode'; // light | dark | system
  static const _kAccentKey = 'accent_color'; // int value

  static final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );
  static final ValueNotifier<Color> accent = ValueNotifier<Color>(
    Colors.green.shade700,
  );

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_kModeKey);
    switch (modeStr) {
      case 'dark':
        mode.value = ThemeMode.dark;
        break;
      case 'system':
        mode.value = ThemeMode.system;
        break;
      case 'light':
      default:
        mode.value = ThemeMode.light;
    }
    final colorInt = prefs.getInt(_kAccentKey);
    if (colorInt != null) {
      accent.value = Color(colorInt);
    }
  }

  static Future<void> _saveMode() async {
    final prefs = await SharedPreferences.getInstance();
    final str = switch (mode.value) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      _ => 'light',
    };
    await prefs.setString(_kModeKey, str);
  }

  static Future<void> _saveAccent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccentKey, accent.value.toARGB32());
  }

  static void toggle() {
    mode.value = mode.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    _saveMode();
  }

  static void set(ThemeMode m) {
    mode.value = m;
    _saveMode();
  }

  static void setAccent(Color c) {
    accent.value = c;
    _saveAccent();
  }
}
