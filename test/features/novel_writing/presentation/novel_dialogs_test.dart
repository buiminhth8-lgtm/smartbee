import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbee/features/novel_writing/presentation/dialogs/create_chapter_dialog.dart';
import 'package:smartbee/features/novel_writing/presentation/dialogs/create_novel_dialog.dart';
import 'package:smartbee/features/novel_writing/presentation/dialogs/create_volume_dialog.dart';

void main() {
  testWidgets('create volume dialog survives parent rebuild while open', (
    tester,
  ) async {
    String? result;
    final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
    addTearDown(themeMode.dispose);

    await tester.pumpWidget(
      _DialogHost(
        themeMode: themeMode,
        buttonLabel: '打开分卷弹窗',
        onPressed: (context) async {
          result = await showCreateVolumeDialog(context);
        },
      ),
    );

    await tester.tap(find.text('打开分卷弹窗'));
    await tester.pumpAndSettle();

    expect(find.text('新建分卷'), findsOneWidget);

    themeMode.value = ThemeMode.dark;
    await tester.pump();

    await tester.enterText(find.byType(TextField), ' 第二卷 ');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(result, '第二卷');
    expect(tester.takeException(), isNull);
  });

  testWidgets('create chapter dialog returns trimmed title', (tester) async {
    String? result;

    await tester.pumpWidget(
      _DialogHost(
        buttonLabel: '打开章节弹窗',
        onPressed: (context) async {
          result = await showCreateChapterDialog(context);
        },
      ),
    );

    await tester.tap(find.text('打开章节弹窗'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' 第二章 ');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(result, '第二章');
    expect(tester.takeException(), isNull);
  });

  testWidgets('create novel dialog returns trimmed fields', (tester) async {
    CreateNovelDialogResult? result;

    await tester.pumpWidget(
      _DialogHost(
        buttonLabel: '打开小说弹窗',
        onPressed: (context) async {
          result = await showCreateNovelDialog(context);
        },
      ),
    );

    await tester.tap(find.text('打开小说弹窗'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '书名'), ' 测试小说 ');
    await tester.enterText(find.widgetWithText(TextField, '作者（可选）'), ' 作者 ');
    await tester.enterText(find.widgetWithText(TextField, '简介（可选）'), ' 简介 ');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(result?.title, '测试小说');
    expect(result?.author, '作者');
    expect(result?.synopsis, '简介');
    expect(tester.takeException(), isNull);
  });
}

class _DialogHost extends StatelessWidget {
  const _DialogHost({
    required this.buttonLabel,
    required this.onPressed,
    this.themeMode,
  });

  final String buttonLabel;
  final ValueNotifier<ThemeMode>? themeMode;
  final Future<void> Function(BuildContext context) onPressed;

  @override
  Widget build(BuildContext context) {
    final listenable = themeMode;

    if (listenable == null) {
      return _buildMaterialApp(ThemeMode.light);
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: listenable,
      builder: (context, mode, _) => _buildMaterialApp(mode),
    );
  }

  Widget _buildMaterialApp(ThemeMode mode) {
    return MaterialApp(
      themeMode: mode,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => onPressed(context),
                child: Text(buttonLabel),
              ),
            ),
          );
        },
      ),
    );
  }
}
