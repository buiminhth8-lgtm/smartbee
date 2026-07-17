import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../domain/stream_profile.dart';
import '../../domain/streaming_exception.dart';
import 'screen_capture_adapter.dart';

class AndroidScreenCaptureAdapter implements ScreenCaptureAdapter {
  @override
  String get platformLabel => 'android';

  @override
  Future<MediaStream> startScreenCapture({
    required StreamProfile profile,
    required bool captureAudio,
    DesktopCaptureSourcePicker? sourcePicker,
  }) async {
    logScreenCapture(
      'start',
      platform: platformLabel,
      status: 'requestingPermission',
    );
    try {
      logScreenCapture('request-permission-start', platform: platformLabel);
      final granted = await Helper.requestCapturePermission(
        fullScreenOnly: true,
      );
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

      logScreenCapture('getDisplayMedia-start', platform: platformLabel);
      final stream = await navigator.mediaDevices.getDisplayMedia(
        <String, dynamic>{'video': true, 'audio': false},
      );
      return validateScreenStream(stream, platform: platformLabel);
    } catch (error, stackTrace) {
      logScreenCapture(
        'getDisplayMedia-failed',
        platform: platformLabel,
        error: error,
        stackTrace: stackTrace,
      );
      throw mapScreenCaptureException(error, platform: platformLabel);
    }
  }
}
