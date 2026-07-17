import 'package:flutter_test/flutter_test.dart';
import 'package:smartbee/features/live_stream/infrastructure/capture/desktop_screen_capture_adapter.dart';
import 'package:smartbee/features/live_stream/infrastructure/capture/screen_capture_adapter.dart';
import 'package:smartbee/features/live_stream/infrastructure/capture/webrtc_media_capture_service.dart';
import 'package:smartbee/features/live_stream/domain/streaming_exception.dart';

import 'fakes.dart';

void main() {
  test('Windows环境不会选择Android适配器', () {
    final service = WebRtcMediaCaptureService();
    expect(service.debugScreenCapturePlatformLabel, isNot('android'));
  });

  test('Windows适配器不调用Android权限API', () {
    const adapter = DesktopScreenCaptureAdapter(platformLabel: 'windows');
    expect(adapter.platformLabel, 'windows');
  });

  test('validateScreenStream有视频轨时校验通过', () {
    final stream = FakeMediaStream('screen-stream');
    final videoTrack = stream.getVideoTracks().first;

    final result = validateScreenStream(stream, platform: 'windows');

    expect(result, same(videoTrack));
  });

  test('validateScreenStream没有视频轨时抛出emptyVideoTrack', () {
    final stream = FakeMediaStream('screen-stream', includeVideo: false);

    expect(
      () => validateScreenStream(stream, platform: 'windows'),
      throwsA(
        isA<StreamingException>().having(
          (error) => error.code,
          'code',
          StreamingErrorCode.emptyVideoTrack,
        ),
      ),
    );
  });

  test('validateScreenStream空Track列表时校验失败', () {
    final stream = FakeMediaStream(
      'screen-stream',
      includeVideo: false,
      includeAudio: false,
    );

    expect(
      () => validateScreenStream(stream, platform: 'windows'),
      throwsA(
        isA<StreamingException>().having(
          (error) => error.code,
          'code',
          StreamingErrorCode.emptyVideoTrack,
        ),
      ),
    );
  });

  test('validateScreenStream不读取原生active getter', () {
    final stream = FakeMediaStream('native-stream', throwOnActiveRead: true);
    final videoTrack = stream.getVideoTracks().first;

    final result = validateScreenStream(stream, platform: 'windows');

    expect(result, same(videoTrack));
    expect(stream.unsupportedGetterReadCount, 0);
  });

  test('校验失败后可以安全释放刚创建的Stream', () async {
    final stream = FakeMediaStream(
      'screen-stream',
      includeVideo: false,
      includeAudio: true,
    );

    expect(
      () => validateScreenStream(stream, platform: 'windows'),
      throwsA(isA<StreamingException>()),
    );

    await disposeMediaStreamSafely(stream, platform: 'windows');

    expect(stream.stopTrackCount, 1);
    expect(stream.disposeCount, 1);
  });
}
