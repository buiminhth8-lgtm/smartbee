import 'package:flutter/material.dart';

import 'app_palette.dart';

class AppAppearanceState {
  const AppAppearanceState({
    required this.themeMode,
    required this.palette,
    required this.isLoaded,
  });

  final ThemeMode themeMode;
  final AppPalette palette;
  final bool isLoaded;

  static const initial = AppAppearanceState(
    themeMode: ThemeMode.system,
    palette: AppPalette.ocean,
    isLoaded: false,
  );

  AppAppearanceState copyWith({
    ThemeMode? themeMode,
    AppPalette? palette,
    bool? isLoaded,
  }) {
    return AppAppearanceState(
      themeMode: themeMode ?? this.themeMode,
      palette: palette ?? this.palette,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}
