import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../domain/stream_profile.dart';
import '../../domain/streaming_exception.dart';
import 'android_screen_capture_adapter.dart';
import 'apple_screen_capture_adapter.dart';
import 'desktop_screen_capture_adapter.dart';
import 'linux_screen_capture_adapter.dart';
import 'media_capture_service.dart';
import 'screen_capture_adapter.dart';
import 'web_screen_capture_adapter.dart';

class WebRtcMediaCaptureService
    implements MediaCaptureService, DesktopCaptureSourcePickerHost {
  MediaStream? _currentStream;
  DesktopCaptureSourcePicker? _desktopCaptureSourcePicker;

  @override
  MediaStream? get currentStream => _currentStream;

  @visibleForTesting
  String get debugScreenCapturePlatformLabel =>
      _screenCaptureAdapter().platformLabel;

  @override
  set desktopCaptureSourcePicker(DesktopCaptureSourcePicker? picker) {
    _desktopCaptureSourcePicker = picker;
  }

  @override
  Future<List<MediaDeviceInfo>> getVideoInputDevices() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      return devices.where((device) => device.kind == 'videoinput').toList();
    } catch (error) {
      throw normalizeStreamingException(error);
    }
  }

  @override
  Future<MediaStream> startCameraCapture({
    required StreamProfile profile,
    String? deviceId,
  }) async {
    await stopCapture();
    logScreenCapture(
      'camera-start',
      platform: _platformLabel,
      fields: {
        'width': profile.width,
        'height': profile.height,
        'fps': profile.fps,
        'sendAudio': profile.sendAudio,
      },
    );
    try {
      final videoConstraints = <String, dynamic>{
        'width': {'ideal': profile.width},
        'height': {'ideal': profile.height},
        'frameRate': {'ideal': profile.fps},
        'facingMode': profile.frontCamera ? 'user' : 'environment',
        if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      };

      final constraints = <String, dynamic>{
        'audio': profile.sendAudio
            ? {
                'echoCancellation': true,
                'noiseSuppression': true,
                'autoGainControl': true,
              }
            : false,
        'video': profile.cameraEnabled ? videoConstraints : false,
      };

      final stream = await navigator.mediaDevices.getUserMedia(constraints);
      if (stream.getVideoTracks().isEmpty && profile.cameraEnabled) {
        throw const StreamingException(
          StreamingErrorCode.cameraNotFound,
          '没有找到可用摄像头。',
        );
      }
      for (final track in stream.getAudioTracks()) {
        track.enabled = profile.microphoneEnabled && profile.sendAudio;
      }
      for (final track in stream.getVideoTracks()) {
        track.enabled = profile.cameraEnabled;
      }
      _currentStream = stream;
      logScreenCapture(
        'camera-returned',
        platform: _platformLabel,
        stream: stream,
        fields: {
          'videoTrackCount': stream.getVideoTracks().length,
          'audioTrackCount': stream.getAudioTracks().length,
        },
      );
      return stream;
    } catch (error, stackTrace) {
      logScreenCapture(
        'camera-failed',
        platform: _platformLabel,
        error: error,
        stackTrace: stackTrace,
      );
      await stopCapture();
      throw normalizeStreamingException(error);
    }
  }

  @override
  Future<MediaStream> startScreenCapture({
    required StreamProfile profile,
    bool captureAudio = false,
  }) async {
    await stopCapture();
    try {
      final adapter = _screenCaptureAdapter();
      logScreenCapture(
        'adapter-selected',
        platform: adapter.platformLabel,
        status: 'preparingCapture',
      );
      final stream = await adapter.startScreenCapture(
        profile: profile,
        captureAudio: captureAudio,
        sourcePicker: _desktopCaptureSourcePicker,
      );
      for (final track in stream.getAudioTracks()) {
        track.enabled = profile.microphoneEnabled && profile.sendAudio;
      }
      _currentStream = stream;
      return stream;
    } catch (error) {
      await stopCapture();
      throw normalizeStreamingException(error);
    }
  }

  @override
  Future<void> switchCamera() async {
    final videoTracks = _currentStream?.getVideoTracks() ?? const [];
    if (videoTracks.isEmpty) {
      throw const StreamingException(
        StreamingErrorCode.cameraNotFound,
        '没有可切换的摄像头。',
      );
    }
    await Helper.switchCamera(videoTracks.first);
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    for (final track in _currentStream?.getAudioTracks() ?? const []) {
      track.enabled = enabled;
    }
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    for (final track in _currentStream?.getVideoTracks() ?? const []) {
      track.enabled = enabled;
    }
  }

  @override
  Future<void> stopCapture() async {
    final stream = _currentStream;
    _currentStream = null;
    await stopMediaStream(stream, platform: _platformLabel);
  }

  ScreenCaptureAdapter _screenCaptureAdapter() {
    if (kIsWeb || WebRTC.platformIsWeb) {
      return WebScreenCaptureAdapter();
    }
    if (WebRTC.platformIsAndroid) {
      return AndroidScreenCaptureAdapter();
    }
    if (WebRTC.platformIsWindows) {
      return const DesktopScreenCaptureAdapter(platformLabel: 'windows');
    }
    if (WebRTC.platformIsLinux) {
      return const LinuxScreenCaptureAdapter();
    }
    if (WebRTC.platformIsMacOS || WebRTC.platformIsIOS) {
      return AppleScreenCaptureAdapter();
    }
    throw const StreamingException(
      StreamingErrorCode.unsupportedPlatform,
      '当前平台暂不支持屏幕捕获。',
    );
  }

  String get _platformLabel {
    if (kIsWeb || WebRTC.platformIsWeb) {
      return 'web';
    }
    if (WebRTC.platformIsAndroid) {
      return 'android';
    }
    if (WebRTC.platformIsWindows) {
      return 'windows';
    }
    if (WebRTC.platformIsLinux) {
      return 'linux';
    }
    if (WebRTC.platformIsMacOS) {
      return 'macos';
    }
    if (WebRTC.platformIsIOS) {
      return 'ios';
    }
    return 'unknown';
  }
}
