import 'dart:async';

import 'package:flutter/material.dart';

import 'app_appearance_controller.dart';
import 'app_palette.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key, required this.controller});

  final AppAppearanceController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final state = controller.state;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('外观模式', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<ThemeMode>(
                selected: <ThemeMode>{state.themeMode},
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('跟随系统'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('白昼'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('黑夜'),
                  ),
                ],
                onSelectionChanged: (selection) {
                  unawaited(controller.setThemeMode(selection.single));
                },
              ),
              const SizedBox(height: 28),
              Text('背景调色盘', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final palette in AppPalette.values)
                    ChoiceChip(
                      selected: state.palette == palette,
                      avatar: CircleAvatar(backgroundColor: palette.seedColor),
                      label: Text(palette.label),
                      onSelected: (_) {
                        unawaited(controller.setPalette(palette));
                      },
                    ),
                ],
              ),
              const SizedBox(height: 28),
              Text('当前配置', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '${_themeModeLabel(state.themeMode)} · ${state.palette.label}',
              ),
            ],
          );
        },
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '白昼',
      ThemeMode.dark => '黑夜',
    };
  }
}
