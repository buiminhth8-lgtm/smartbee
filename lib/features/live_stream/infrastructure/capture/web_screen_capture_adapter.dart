import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../domain/stream_profile.dart';
import '../../domain/streaming_exception.dart';
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
      late final MediaStream stream;
      try {
        stream = await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
          'video': true,
          'audio': false,
        });
      } catch (error, stackTrace) {
        logScreenCapture(
          'getDisplayMedia-failed',
          platform: platformLabel,
          error: error,
          stackTrace: stackTrace,
        );
        throw mapScreenCaptureException(error, platform: platformLabel);
      }

      logScreenCapture(
        'getDisplayMedia-returned',
        platform: platformLabel,
        stream: stream,
        fields: {
          'videoTrackCount': stream.getVideoTracks().length,
          'audioTrackCount': stream.getAudioTracks().length,
        },
      );

      try {
        validateScreenStream(stream, platform: platformLabel);
        logScreenCapture(
          'capture-ready',
          platform: platformLabel,
          stream: stream,
        );
        return stream;
      } catch (error, stackTrace) {
        logScreenCapture(
          'validate-stream-failed',
          platform: platformLabel,
          error: error,
          stackTrace: stackTrace,
        );
        await disposeMediaStreamSafely(stream, platform: platformLabel);
        rethrow;
      }
    } catch (error, stackTrace) {
      logScreenCapture(
        'start-failed',
        platform: platformLabel,
        error: error,
        stackTrace: stackTrace,
      );
      if (error is StreamingException) {
        rethrow;
      }
      throw mapScreenCaptureException(error, platform: platformLabel);
    }
  }
}
