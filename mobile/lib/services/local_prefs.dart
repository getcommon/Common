import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart' show ThemeMode;

class LocalPrefs {
  static const _kOnboarded = 'onboarded';
  static const _kThemeMode = 'theme_mode';
  static Future<bool> hasOnboarded() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kOnboarded) ?? false;
  }

  static Future<void> setOnboarded(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOnboarded, v);
  }

  static Future<ThemeMode> themeMode() async {
    final p = await SharedPreferences.getInstance();
    return switch (p.getString(_kThemeMode)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    final p = await SharedPreferences.getInstance();
    await p.setString(_kThemeMode, value);
  }
}
