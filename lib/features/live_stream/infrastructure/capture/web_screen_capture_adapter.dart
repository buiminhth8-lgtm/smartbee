import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../domain/stream_profile.dart';
import 'screen_capture_adapter.dart';

class WebScreenCaptureAdapter implements ScreenCaptureAdapter {
  @override
  String get platformLabel => 'web';

  @override
  Future<MediaStream> startScreenCapture({
    required StreamProfile profile,
    required bool captureAudio,
    DesktopCaptureSourcePicker? sourcePicker,
  }) async {
    logScreenCapture('start', platform: platformLabel);
    try {
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
