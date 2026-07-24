import 'package:flutter/material.dart';

import 'app_palette.dart';

ThemeData buildSmartbeeTheme({
  required AppPalette palette,
  required Brightness brightness,
}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: palette.seedColor,
    brightness: brightness,
  );
  final background = palette.scaffoldBackground(brightness);
  final surface = palette.surfaceColor(brightness);

  return ThemeData(
    colorScheme: colorScheme.copyWith(surface: surface),
    scaffoldBackgroundColor: background,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: colorScheme.primary,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: colorScheme.secondaryContainer,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surface,
      indicatorColor: colorScheme.secondaryContainer,
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: colorScheme.primary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: const OutlineInputBorder(),
    ),
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
  );
}
