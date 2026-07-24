import 'dart:async';

import 'package:flutter/material.dart';

import 'app_appearance_controller.dart';
import 'app_appearance_storage.dart';
import 'app_shell.dart';
import 'smartbee_theme.dart';

class SmartbeeApp extends StatefulWidget {
  const SmartbeeApp({super.key, this.appearanceController});

  final AppAppearanceController? appearanceController;

  @override
  State<SmartbeeApp> createState() => _SmartbeeAppState();
}

class _SmartbeeAppState extends State<SmartbeeApp> {
  late final AppAppearanceController _appearanceController;
  late final bool _ownsAppearanceController;

  @override
  void initState() {
    super.initState();
    _ownsAppearanceController = widget.appearanceController == null;
    _appearanceController =
        widget.appearanceController ??
        AppAppearanceController(
          storage: SharedPreferencesAppAppearanceStorage(),
        );
    unawaited(_appearanceController.load());
  }

  @override
  void dispose() {
    if (_ownsAppearanceController) {
      _appearanceController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appearanceController,
      builder: (context, _) {
        final appearance = _appearanceController.state;
        return MaterialApp(
          title: 'Smartbee',
          debugShowCheckedModeBanner: false,
          themeMode: appearance.themeMode,
          theme: buildSmartbeeTheme(
            palette: appearance.palette,
            brightness: Brightness.light,
          ),
          darkTheme: buildSmartbeeTheme(
            palette: appearance.palette,
            brightness: Brightness.dark,
          ),
          home: AppShell(appearanceController: _appearanceController),
        );
      },
    );
  }
}
