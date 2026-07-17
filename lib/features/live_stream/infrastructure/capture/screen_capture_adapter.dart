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
  await disposeMediaStreamSafely(stream, platform: platform);
}

Future<void> disposeMediaStreamSafely(
  MediaStream stream, {
  required String platform,
}) async {
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
        fields: {'trackId': track.id},
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

MediaStreamTrack validateScreenStream(
  MediaStream stream, {
  required String platform,
}) {
  final tracks = stream.getTracks();
  final videoTracks = stream.getVideoTracks();
  final audioTracks = stream.getAudioTracks();
  logScreenCapture(
    'validate-stream',
    platform: platform,
    stream: stream,
    fields: {
      'trackCount': tracks.length,
      'videoTrackCount': videoTracks.length,
      'audioTrackCount': audioTracks.length,
    },
  );

  if (tracks.isEmpty) {
    throw StreamingException(
      StreamingErrorCode.emptyVideoTrack,
      '$platform 屏幕采集返回了空媒体流。',
    );
  }

  if (videoTracks.isEmpty) {
    throw StreamingException(
      StreamingErrorCode.emptyVideoTrack,
      '$platform 屏幕采集没有返回视频轨。',
    );
  }

  final videoTrack = videoTracks.first;
  if (videoTrack.kind != 'video') {
    throw StreamingException(
      StreamingErrorCode.emptyVideoTrack,
      '$platform 屏幕采集返回了无效的视频轨。',
    );
  }

  logScreenCapture(
    'validate-stream-success',
    platform: platform,
    stream: stream,
    fields: {
      'trackId': videoTrack.id,
      'trackKind': videoTrack.kind,
      'trackEnabled': videoTrack.enabled,
      'trackLabel': videoTrack.label,
    },
  );

  return videoTrack;
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
