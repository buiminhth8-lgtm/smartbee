import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../domain/stream_profile.dart';
import '../../domain/streaming_exception.dart';

typedef DesktopCaptureSourcePicker =
    Future<DesktopCapturerSource?> Function(
      List<DesktopCapturerSource> sources,
    );

abstract interface class DesktopCaptureSourcePickerHost {
  set desktopCaptureSourcePicker(DesktopCaptureSourcePicker? picker);
}

abstract interface class ScreenCaptureAdapter {
  String get platformLabel;

  Future<MediaStream> startScreenCapture({
    required StreamProfile profile,
    required bool captureAudio,
    DesktopCaptureSourcePicker? sourcePicker,
  });
}

void logScreenCapture(
  String step, {
  required String platform,
  String? status,
  MediaStream? stream,
  Object? error,
  StackTrace? stackTrace,
  Map<String, Object?> fields = const {},
}) {
  final parts = <String>[
    '[ScreenCapture]',
    'platform=$platform',
    'step=$step',
    if (status != null) 'status=$status',
    if (stream != null) 'streamId=${stream.id}',
    ...fields.entries.map((entry) => '${entry.key}=${entry.value}'),
    if (error != null) 'errorType=${error.runtimeType}',
    if (error != null) 'error=${_safeError(error)}',
  ];
  debugPrint(parts.join(' '));
  if (stackTrace != null) {
    debugPrintStack(stackTrace: stackTrace);
  }
}

Future<void> stopMediaStream(
  MediaStream? stream, {
  required String platform,
}) async {
  if (stream == null) {
    return;
  }
  logScreenCapture(
    'stopCapture-start',
    platform: platform,
    stream: stream,
    fields: {
      'trackCount': stream.getTracks().length,
      'videoTrackCount': stream.getVideoTracks().length,
      'audioTrackCount': stream.getAudioTracks().length,
    },
  );
  for (final track in stream.getTracks()) {
    try {
      await track.stop();
      logScreenCapture(
        'track-stop',
        platform: platform,
        fields: {'trackId': track.id, 'kind': track.kind},
      );
    } catch (error, stackTrace) {
      logScreenCapture(
        'track-stop-failed',
        platform: platform,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
  try {
    await stream.dispose();
    logScreenCapture('stream-dispose', platform: platform, stream: stream);
  } catch (error, stackTrace) {
    logScreenCapture(
      'stream-dispose-failed',
      platform: platform,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

MediaStream validateScreenStream(
  MediaStream stream, {
  required String platform,
}) {
  final videoTracks = stream.getVideoTracks();
  final audioTracks = stream.getAudioTracks();
  logScreenCapture(
    'getDisplayMedia-returned',
    platform: platform,
    stream: stream,
    fields: {
      'videoTrackCount': videoTracks.length,
      'audioTrackCount': audioTracks.length,
      'active': stream.active,
    },
  );

  if (videoTracks.isEmpty) {
    throw const StreamingException(
      StreamingErrorCode.emptyVideoTrack,
      '系统没有返回视频轨。',
    );
  }

  for (final track in videoTracks) {
    Map<String, dynamic> settings = const {};
    try {
      settings = track.getSettings();
    } catch (_) {
      settings = const {};
    }
    logScreenCapture(
      'video-track',
      platform: platform,
      fields: {
        'trackId': track.id,
        'enabled': track.enabled,
        'muted': track.muted,
        'settings': settings,
      },
    );
  }

  for (final track in audioTracks) {
    logScreenCapture(
      'audio-track',
      platform: platform,
      fields: {
        'trackId': track.id,
        'enabled': track.enabled,
        'muted': track.muted,
      },
    );
  }

  return stream;
}

StreamingException mapScreenCaptureException(
  Object error, {
  required String platform,
}) {
  if (error is StreamingException) {
    return error;
  }
  final text = error.toString().toLowerCase();
  if (text.contains('cancel') || text.contains('notallowed')) {
    return const StreamingException(
      StreamingErrorCode.permissionCancelled,
      '用户取消了屏幕共享。',
    );
  }
  if (text.contains('permission') || text.contains('denied')) {
    return const StreamingException(
      StreamingErrorCode.permissionDenied,
      '未获得屏幕录制权限。',
    );
  }
  if (text.contains('not found') || text.contains('notfound')) {
    return const StreamingException(
      StreamingErrorCode.screenCaptureUnavailable,
      '当前系统没有可用的屏幕捕获来源。',
    );
  }
  return StreamingException(
    StreamingErrorCode.unknown,
    '$platform 录屏失败，请查看诊断日志。',
    cause: error,
  );
}

String _safeError(Object error) {
  return error.toString().replaceAll(RegExp(r'Bearer\s+[^\s]+'), 'Bearer ***');
}
