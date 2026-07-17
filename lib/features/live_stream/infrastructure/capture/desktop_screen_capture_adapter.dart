import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../domain/stream_profile.dart';
import '../../domain/streaming_exception.dart';
import 'screen_capture_adapter.dart';

class DesktopScreenCaptureAdapter implements ScreenCaptureAdapter {
  const DesktopScreenCaptureAdapter({required this.platformLabel});

  @override
  final String platformLabel;

  @override
  Future<MediaStream> startScreenCapture({
    required StreamProfile profile,
    required bool captureAudio,
    DesktopCaptureSourcePicker? sourcePicker,
  }) async {
    logScreenCapture('start', platform: platformLabel);
    try {
      logScreenCapture('desktop-getSources-start', platform: platformLabel);
      final sources = await desktopCapturer.getSources(
        types: <SourceType>[SourceType.Screen, SourceType.Window],
        thumbnailSize: ThumbnailSize(320, 180),
      );
      logScreenCapture(
        'desktop-getSources-returned',
        platform: platformLabel,
        fields: {'sourceCount': sources.length},
      );

      if (sourcePicker == null) {
        throw const StreamingException(
          StreamingErrorCode.captureSourceNotSelected,
          '未配置屏幕或窗口来源选择器。',
        );
      }
      final selectedSource = await sourcePicker(sources);
      if (selectedSource == null) {
        throw const StreamingException(
          StreamingErrorCode.permissionCancelled,
          '用户取消了屏幕共享。',
        );
      }

      logScreenCapture(
        'desktop-source-selected',
        platform: platformLabel,
        fields: {
          'sourceId': selectedSource.id,
          'sourceName': selectedSource.name,
          'sourceType': selectedSource.type.name,
        },
      );

      final constraints = <String, dynamic>{
        'video': <String, dynamic>{
          'deviceId': <String, dynamic>{'exact': selectedSource.id},
          'mandatory': <String, dynamic>{'frameRate': profile.fps.toDouble()},
        },
        'audio': false,
      };

      logScreenCapture('getDisplayMedia-start', platform: platformLabel);
      late final MediaStream stream;
      try {
        stream = await navigator.mediaDevices.getDisplayMedia(constraints);
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
