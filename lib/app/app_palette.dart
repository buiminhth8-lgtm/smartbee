import 'package:flutter/material.dart';

enum AppPalette {
  ocean('ocean', Color(0xFF1565C0)),
  forest('forest', Color(0xFF2E7D32)),
  honey('honey', Color(0xFFE08A00)),
  wisteria('wisteria', Color(0xFF7E57C2)),
  camellia('camellia', Color(0xFFC2185B)),
  graphite('graphite', Color(0xFF455A64));

  const AppPalette(this.id, this.seedColor);

  final String id;
  final Color seedColor;

  String get label {
    return switch (this) {
      AppPalette.ocean => '海蓝',
      AppPalette.forest => '森林',
      AppPalette.honey => '蜂蜜',
      AppPalette.wisteria => '紫藤',
      AppPalette.camellia => '山茶',
      AppPalette.graphite => '石墨',
    };
  }

  static AppPalette fromId(String? id) {
    for (final palette in AppPalette.values) {
      if (palette.id == id) {
        return palette;
      }
    }
    return AppPalette.ocean;
  }

  Color scaffoldBackground(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return switch (this) {
        AppPalette.ocean => const Color(0xFF07111F),
        AppPalette.forest => const Color(0xFF07160E),
        AppPalette.honey => const Color(0xFF171006),
        AppPalette.wisteria => const Color(0xFF120C1F),
        AppPalette.camellia => const Color(0xFF1D0A13),
        AppPalette.graphite => const Color(0xFF0B1013),
      };
    }

    return switch (this) {
      AppPalette.ocean => const Color(0xFFF3F8FF),
      AppPalette.forest => const Color(0xFFF2FAF4),
      AppPalette.honey => const Color(0xFFFFF8EC),
      AppPalette.wisteria => const Color(0xFFF9F5FF),
      AppPalette.camellia => const Color(0xFFFFF5F8),
      AppPalette.graphite => const Color(0xFFF5F7F8),
    };
  }

  Color surfaceColor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return Color.alphaBlend(
        seedColor.withAlpha(22),
        scaffoldBackground(brightness),
      );
    }

    return Color.alphaBlend(seedColor.withAlpha(10), Colors.white);
  }
}
