import 'package:flutter/material.dart';

import 'local_prefs.dart';

/// Holds the member's local appearance choice and persists it between launches.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.system);

  static final instance = ThemeController._();

  Future<void> load() async {
    value = await LocalPrefs.themeMode();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (value == mode) return;
    value = mode;
    await LocalPrefs.setThemeMode(mode);
  }
}
