import 'package:flutter_test/flutter_test.dart';
import 'package:smartbee/features/live_stream/application/live_stream_controller.dart';
import 'package:smartbee/features/live_stream/domain/capture_source_type.dart';
import 'package:smartbee/features/live_stream/domain/publish_protocol.dart';
import 'package:smartbee/features/live_stream/domain/stream_server_config.dart';
import 'package:smartbee/features/live_stream/domain/stream_session_state.dart';
import 'package:smartbee/features/live_stream/domain/stream_statistics.dart';
import 'package:smartbee/features/live_stream/domain/streaming_exception.dart';
import 'package:smartbee/features/live_stream/infrastructure/publisher/rtmp_publisher.dart';
import 'package:smartbee/features/live_stream/infrastructure/publisher/whip_publisher.dart';

import 'fakes.dart';

void main() {
  LiveStreamController buildController({
    FakeMediaCaptureService? capture,
    FakeStreamPublisher? publisher,
    StreamPublisherFactory? factory,
  }) {
    final fakePublisher = publisher ?? FakeStreamPublisher();
    return LiveStreamController(
      captureService: capture ?? FakeMediaCaptureService(),
      publisherFactory: factory ?? fakePublisherFactory(fakePublisher),
      storage: FakeStreamConfigStorage(),
    );
  }

  test('摄像头预览状态转换正确', () async {
    final controller = buildController();
    await controller.openPreview();
    expect(controller.state.status, StreamSessionStatus.previewing);
    expect(controller.currentStream?.id, 'camera-stream');
    controller.dispose();
  });

  test('屏幕预览状态转换正确', () async {
    final controller = buildController();
    await controller.setSourceType(CaptureSourceType.screen);
    await controller.openPreview();
    expect(controller.state.status, StreamSessionStatus.previewing);
    expect(controller.currentStream?.id, 'screen-stream');
    controller.dispose();
  });

  test('返回空视频轨时进入failed', () async {
    final controller = buildController(
      capture: FakeMediaCaptureService(screenStreamHasVideo: false),
    );
    await controller.setSourceType(CaptureSourceType.screen);
    await controller.openPreview();
    expect(controller.state.status, StreamSessionStatus.failed);
    expect(controller.state.errorMessage, contains('视频轨'));
    controller.dispose();
  });

  test('用户取消时回到idle', () async {
    final controller = buildController(
      capture: FakeMediaCaptureService(
        screenCaptureThrows: const StreamingException(
          StreamingErrorCode.permissionCancelled,
          '用户取消了屏幕共享。',
        ),
      ),
    );
    await controller.setSourceType(CaptureSourceType.screen);
    await controller.openPreview();
    expect(controller.state.status, StreamSessionStatus.idle);
    expect(controller.state.errorMessage, isNull);
    controller.dispose();
  });

  test('权限拒绝时进入failed', () async {
    final controller = buildController(
      capture: FakeMediaCaptureService(
        screenCaptureThrows: const StreamingException(
          StreamingErrorCode.permissionDenied,
          '未获得屏幕录制权限。',
        ),
      ),
    );
    await controller.setSourceType(CaptureSourceType.screen);
    await controller.openPreview();
    expect(controller.state.status, StreamSessionStatus.failed);
    expect(controller.state.errorMessage, contains('权限'));
    controller.dispose();
  });

  test('连续点击打开只创建一次采集请求', () async {
    final capture = FakeMediaCaptureService();
    final controller = buildController(capture: capture);
    await controller.setSourceType(CaptureSourceType.screen);
    await Future.wait([controller.openPreview(), controller.openPreview()]);
    expect(capture.screenCaptureCount, 1);
    controller.dispose();
  });

  test('开始推流成功', () async {
    final publisher = FakeStreamPublisher();
    final controller = buildController(publisher: publisher);
    await controller.startPublishing();
    expect(controller.state.status, StreamSessionStatus.publishing);
    expect(publisher.started, isTrue);
    controller.dispose();
  });

  test('推流失败进入failed', () async {
    final controller = buildController(
      publisher: FakeStreamPublisher(failOnStart: true),
    );
    await controller.startPublishing();
    expect(controller.state.status, StreamSessionStatus.failed);
    controller.dispose();
  });

  test('停止操作幂等', () async {
    final capture = FakeMediaCaptureService();
    final controller = buildController(capture: capture);
    await controller.startPublishing();
    await controller.stopPublishing();
    await controller.stopPublishing();
    expect(controller.state.status, StreamSessionStatus.stopped);
    expect(capture.stopped, isTrue);
    controller.dispose();
  });

  test('系统结束视频轨后状态变为stopped', () async {
    final controller = buildController();
    await controller.setSourceType(CaptureSourceType.screen);
    await controller.openPreview();
    final videoTrack = controller.currentStream!.getVideoTracks().first;
    videoTrack.onEnded?.call();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.state.status, StreamSessionStatus.stopped);
    controller.dispose();
  });

  test('摄像头预览不因录屏修复而损坏', () async {
    final capture = FakeMediaCaptureService();
    final controller = buildController(capture: capture);
    await controller.openPreview();
    expect(controller.state.status, StreamSessionStatus.previewing);
    expect(capture.cameraCaptureCount, 1);
    controller.dispose();
  });

  test('用户停止后不会自动重连', () async {
    final publisher = FakeStreamPublisher();
    final controller = buildController(publisher: publisher);
    await controller.startPublishing();
    await controller.stopPublishing();
    publisher.fail();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.state.status, StreamSessionStatus.stopped);
    controller.dispose();
  });

  test('Token不会出现在日志中', () async {
    final controller = buildController(
      publisher: FakeStreamPublisher(
        failOnStart: true,
        failureMessage: 'secret-token failed',
      ),
    );
    await controller.updateConfig(
      StreamServerConfig.defaults().copyWith(bearerToken: 'secret-token'),
    );
    await controller.startPublishing();
    expect(controller.state.logs.join('\n'), isNot(contains('secret-token')));
    controller.dispose();
  });

  test('不支持协议返回明确错误', () async {
    final controller = buildController(
      factory: StreamPublisherFactory((protocol) => RtmpPublisher()),
    );
    controller.setProtocol(PublishProtocol.rtmp);
    await controller.startPublishing();
    expect(controller.state.status, StreamSessionStatus.failed);
    expect(controller.state.errorMessage, contains('暂未实现直接推送'));
    controller.dispose();
  });

  test('统计只保留最近60秒数据', () async {
    final publisher = FakeStreamPublisher();
    final controller = buildController(publisher: publisher);
    await controller.startPublishing();
    for (var i = 0; i < 65; i++) {
      publisher.statisticsController.add(StreamStatistics.empty());
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.state.statisticsHistory.length, 60);
    controller.dispose();
  });
}
