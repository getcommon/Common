import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/local_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('uses the system appearance when no preference is stored', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await LocalPrefs.themeMode(), ThemeMode.system);
  });

  test('persists and restores the selected appearance', () async {
    SharedPreferences.setMockInitialValues({});

    await LocalPrefs.setThemeMode(ThemeMode.dark);
    expect(await LocalPrefs.themeMode(), ThemeMode.dark);

    await LocalPrefs.setThemeMode(ThemeMode.light);
    expect(await LocalPrefs.themeMode(), ThemeMode.light);
  });
}
