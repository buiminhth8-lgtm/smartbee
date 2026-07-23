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

  testWidgets('默认地图功能不被破坏', (tester) async {
    final liveController = LiveStreamController(
      captureService: FakeMediaCaptureService(),
      publisherFactory: fakePublisherFactory(FakeStreamPublisher()),
      storage: FakeStreamConfigStorage(),
    );
    final novelController = NovelWritingController(
      repository: FakeNovelRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          liveStreamController: liveController,
          novelWritingController: novelController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('地图示例'), findsOneWidget);
    expect(find.textContaining('经度'), findsOneWidget);
    expect(find.textContaining('纬度'), findsOneWidget);
  });
}
