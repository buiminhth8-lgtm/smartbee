import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbee/features/novel_writing/application/novel_writing_controller.dart';
import 'package:smartbee/features/novel_writing/presentation/novel_writing_page.dart';

import '../fakes.dart';

void main() {
  testWidgets('empty library opens create novel dialog', (tester) async {
    final controller = NovelWritingController(
      repository: FakeNovelRepository(),
    );
    await controller.loadLibrary();

    await tester.pumpWidget(
      MaterialApp(home: NovelWritingPage(controller: controller)),
    );

    expect(
      find.text('\u8fd8\u6ca1\u6709\u5c0f\u8bf4\u4f5c\u54c1'),
      findsOneWidget,
    );

    await tester.tap(find.text('\u65b0\u5efa\u5c0f\u8bf4'));
    await tester.pumpAndSettle();

    expect(find.text('\u4e66\u540d'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('created novel shows outline and updates editor statistics', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = NovelWritingController(
      repository: FakeNovelRepository(),
      autosaveDelay: const Duration(milliseconds: 10),
    );
    await controller.createNovel(title: '\u6d4b\u8bd5\u5c0f\u8bf4');

    await tester.pumpWidget(
      MaterialApp(home: NovelWritingPage(controller: controller)),
    );

    expect(find.text('\u7b2c\u4e00\u5377'), findsOneWidget);
    expect(find.text('\u7b2c\u4e00\u7ae0'), findsWidgets);

    await tester.enterText(
      find.byType(TextField).last,
      '\u4e2d\u6587 \u6b63\u6587',
    );
    await tester.pump();

    expect(find.text('\u6709\u672a\u4fdd\u5b58\u4fee\u6539'), findsOneWidget);
    expect(
      find.textContaining(
        '\u5b57\u6570\uff08\u4e0d\u542b\u7a7a\u767d\uff09\uff1a4',
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    expect(find.textContaining('\u5df2\u4fdd\u5b58'), findsWidgets);
    controller.dispose();
  });
}
