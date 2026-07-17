import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../domain/stream_profile.dart';
import '../../domain/streaming_exception.dart';
import 'desktop_screen_capture_adapter.dart';
import 'screen_capture_adapter.dart';

class AppleScreenCaptureAdapter implements ScreenCaptureAdapter {
  @override
  String get platformLabel => WebRTC.platformIsMacOS ? 'macos' : 'ios';

  @override
  Future<MediaStream> startScreenCapture({
    required StreamProfile profile,
    required bool captureAudio,
    DesktopCaptureSourcePicker? sourcePicker,
  }) async {
    if (WebRTC.platformIsIOS) {
      throw const StreamingException(
        StreamingErrorCode.unsupportedPlatform,
        'iOS 屏幕共享需要 ReplayKit Broadcast Extension，当前主工程暂未实现。',
      );
    }

    logScreenCapture('request-permission-start', platform: platformLabel);
    try {
      final granted = await Helper.requestCapturePermission();
      logScreenCapture(
        'request-permission-result',
        platform: platformLabel,
        fields: {'granted': granted},
      );
      if (!granted) {
        throw const StreamingException(
          StreamingErrorCode.permissionCancelled,
          '用户取消了屏幕共享。',
        );
      }
      return DesktopScreenCaptureAdapter(
        platformLabel: platformLabel,
      ).startScreenCapture(
        profile: profile,
        captureAudio: captureAudio,
        sourcePicker: sourcePicker,
      );
    } catch (error, stackTrace) {
      logScreenCapture(
        'request-permission-failed',
        platform: platformLabel,
        error: error,
        stackTrace: stackTrace,
      );
      throw mapScreenCaptureException(error, platform: platformLabel);
    }
  }
}
