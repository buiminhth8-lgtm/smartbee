import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbee/app/app_shell.dart';
import 'package:smartbee/features/live_stream/application/live_stream_controller.dart';

import 'features/live_stream/fakes.dart';
import 'features/live_stream/webrtc_test_binding.dart';

void main() {
  setUp(mockWebRtcRenderer);

  testWidgets('地图页面可以打开', (tester) async {
    final controller = LiveStreamController(
      captureService: FakeMediaCaptureService(),
      publisherFactory: fakePublisherFactory(FakeStreamPublisher()),
      storage: FakeStreamConfigStorage(),
    );
    await tester.pumpWidget(
      MaterialApp(home: AppShell(liveStreamController: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('地图示例'), findsOneWidget);
  });

  testWidgets('推流页面可以打开', (tester) async {
    final controller = LiveStreamController(
      captureService: FakeMediaCaptureService(),
      publisherFactory: fakePublisherFactory(FakeStreamPublisher()),
      storage: FakeStreamConfigStorage(),
    );
    await tester.pumpWidget(
      MaterialApp(home: AppShell(liveStreamController: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('实时推流').last);
    await tester.pumpAndSettle();

    expect(find.text('实时推流'), findsWidgets);
    expect(find.text('打开预览'), findsOneWidget);
  });
}
