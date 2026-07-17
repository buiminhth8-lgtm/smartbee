import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbee/features/live_stream/application/live_stream_controller.dart';
import 'package:smartbee/features/live_stream/domain/capture_source_type.dart';
import 'package:smartbee/features/live_stream/domain/stream_session_state.dart';
import 'package:smartbee/features/live_stream/presentation/live_stream_page.dart';
import 'package:smartbee/features/live_stream/presentation/widgets/stream_preview.dart';

import 'fakes.dart';
import 'webrtc_test_binding.dart';

void main() {
  setUp(mockWebRtcRenderer);

  testWidgets('实时推流页面显示核心区域', (tester) async {
    final controller = LiveStreamController(
      captureService: FakeMediaCaptureService(),
      publisherFactory: fakePublisherFactory(FakeStreamPublisher()),
      storage: FakeStreamConfigStorage(),
    );

    await tester.pumpWidget(
      MaterialApp(home: LiveStreamPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('摄像头'), findsOneWidget);
    expect(find.text('屏幕'), findsOneWidget);
    expect(find.text('服务器配置'), findsOneWidget);
    expect(find.text('视频配置'), findsOneWidget);
    expect(find.text('输出地址'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('页面dispose后释放Renderer', (tester) async {
    var disposed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StreamPreview(
          stream: null,
          sourceType: CaptureSourceType.camera,
          status: StreamSessionStatus.idle,
          errorMessage: null,
          mirror: false,
          onRendererDisposed: () => disposed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(disposed, isTrue);
  });

  testWidgets('Renderer只初始化一次且Stream变化后更新srcObject', (tester) async {
    final firstStream = FakeMediaStream('first-stream');
    final secondStream = FakeMediaStream('second-stream');

    await tester.pumpWidget(
      MaterialApp(
        home: StreamPreview(
          stream: firstStream,
          sourceType: CaptureSourceType.screen,
          status: StreamSessionStatus.previewing,
          errorMessage: null,
          mirror: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        home: StreamPreview(
          stream: secondStream,
          sourceType: CaptureSourceType.screen,
          status: StreamSessionStatus.previewing,
          errorMessage: null,
          mirror: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(rendererInitializeCount, 1);
    expect(
      rendererBoundStreamIds,
      containsAll(<String>['first-stream', 'second-stream']),
    );
  });
}
