import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbee/app/app_appearance_controller.dart';
import 'package:smartbee/app/app_appearance_storage.dart';
import 'package:smartbee/app/app_palette.dart';
import 'package:smartbee/app/appearance_settings_page.dart';

void main() {
  test('theme mode name round trip', () {
    expect(themeModeFromName('light'), ThemeMode.light);
    expect(themeModeFromName('dark'), ThemeMode.dark);
    expect(themeModeFromName('system'), ThemeMode.system);
    expect(themeModeName(ThemeMode.light), 'light');
    expect(themeModeName(ThemeMode.dark), 'dark');
    expect(themeModeName(ThemeMode.system), 'system');
  });

  test(
    'appearance controller loads and persists theme mode and palette',
    () async {
      final storage = FakeAppearanceStorage(
        stored: const StoredAppAppearance(
          themeMode: ThemeMode.dark,
          palette: AppPalette.forest,
        ),
      );
      final controller = AppAppearanceController(storage: storage);

      await controller.load();

      expect(controller.state.themeMode, ThemeMode.dark);
      expect(controller.state.palette, AppPalette.forest);

      await controller.setThemeMode(ThemeMode.light);
      await controller.setPalette(AppPalette.honey);

      expect(storage.saved!.themeMode, ThemeMode.light);
      expect(storage.saved!.palette, AppPalette.honey);
    },
  );

  testWidgets('settings page switches day night and palette', (tester) async {
    final controller = AppAppearanceController(
      storage: FakeAppearanceStorage(),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(home: AppearanceSettingsPage(controller: controller)),
    );
    await tester.pump();

    expect(find.text('外观模式'), findsOneWidget);
    expect(find.text('背景调色盘'), findsOneWidget);

    await tester.tap(find.text('黑夜'));
    await tester.pump();
    expect(controller.state.themeMode, ThemeMode.dark);

    await tester.tap(find.text('白昼'));
    await tester.pump();
    expect(controller.state.themeMode, ThemeMode.light);

    await tester.tap(find.widgetWithText(ChoiceChip, '蜂蜜'));
    await tester.pump();
    expect(controller.state.palette, AppPalette.honey);
  });
}

class FakeAppearanceStorage implements AppAppearanceStorage {
  FakeAppearanceStorage({this.stored});

  StoredAppAppearance? stored;
  StoredAppAppearance? saved;

  @override
  Future<StoredAppAppearance?> load() async => stored;

  @override
  Future<void> save(StoredAppAppearance appearance) async {
    saved = appearance;
    stored = appearance;
  }
}
