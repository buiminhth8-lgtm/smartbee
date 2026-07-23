import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbee/app/app_shell.dart';
import 'package:smartbee/features/live_stream/application/live_stream_controller.dart';
import 'package:smartbee/features/novel_writing/application/novel_writing_controller.dart';

import 'features/live_stream/fakes.dart';
import 'features/live_stream/webrtc_test_binding.dart';
import 'features/novel_writing/fakes.dart';

void main() {
  setUp(mockWebRtcRenderer);

  LiveStreamController liveController() {
    return LiveStreamController(
      captureService: FakeMediaCaptureService(),
      publisherFactory: fakePublisherFactory(FakeStreamPublisher()),
      storage: FakeStreamConfigStorage(),
    );
  }

  NovelWritingController novelController() {
    return NovelWritingController(repository: FakeNovelRepository());
  }

  testWidgets('地图页面可以打开', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          liveStreamController: liveController(),
          novelWritingController: novelController(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('地图示例'), findsOneWidget);
  });

  testWidgets('推流页面可以打开', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          liveStreamController: liveController(),
          novelWritingController: novelController(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('实时推流').last);
    await tester.pumpAndSettle();

    expect(find.text('实时推流'), findsWidgets);
    expect(find.text('打开预览'), findsOneWidget);
  });

  testWidgets('小说写作页面可以打开', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          liveStreamController: liveController(),
          novelWritingController: novelController(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('小说写作').last);
    await tester.pumpAndSettle();

    expect(find.text('小说写作'), findsWidgets);
    expect(find.text('还没有小说作品'), findsOneWidget);
    expect(find.text('新建小说'), findsOneWidget);
  });
}
