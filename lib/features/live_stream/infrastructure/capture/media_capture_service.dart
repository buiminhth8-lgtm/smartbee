import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../domain/stream_profile.dart';

abstract interface class MediaCaptureService {
  Future<List<MediaDeviceInfo>> getVideoInputDevices();

  Future<MediaStream> startCameraCapture({
    required StreamProfile profile,
    String? deviceId,
  });

  Future<MediaStream> startScreenCapture({
    required StreamProfile profile,
    bool captureAudio = false,
  });

  Future<void> switchCamera();

  Future<void> setMicrophoneEnabled(bool enabled);

  Future<void> setCameraEnabled(bool enabled);

  Future<void> stopCapture();

  MediaStream? get currentStream;
}
