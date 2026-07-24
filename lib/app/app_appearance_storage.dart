import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_palette.dart';

class StoredAppAppearance {
  const StoredAppAppearance({required this.themeMode, required this.palette});

  final ThemeMode themeMode;
  final AppPalette palette;
}

abstract interface class AppAppearanceStorage {
  Future<StoredAppAppearance?> load();

  Future<void> save(StoredAppAppearance appearance);
}

class SharedPreferencesAppAppearanceStorage implements AppAppearanceStorage {
  static const _themeModeKey = 'app_appearance.theme_mode';
  static const _paletteKey = 'app_appearance.palette';

  @override
  Future<StoredAppAppearance?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final themeModeName = preferences.getString(_themeModeKey);
    final paletteId = preferences.getString(_paletteKey);

    if (themeModeName == null && paletteId == null) {
      return null;
    }

    return StoredAppAppearance(
      themeMode: themeModeFromName(themeModeName),
      palette: AppPalette.fromId(paletteId),
    );
  }

  @override
  Future<void> save(StoredAppAppearance appearance) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _themeModeKey,
      themeModeName(appearance.themeMode),
    );
    await preferences.setString(_paletteKey, appearance.palette.id);
  }
}

ThemeMode themeModeFromName(String? name) {
  return switch (name) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

String themeModeName(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}
