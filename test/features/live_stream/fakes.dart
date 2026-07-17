import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:smartbee/features/live_stream/domain/capture_source_type.dart';
import 'package:smartbee/features/live_stream/domain/stream_profile.dart';
import 'package:smartbee/features/live_stream/domain/stream_server_config.dart';
import 'package:smartbee/features/live_stream/domain/stream_statistics.dart';
import 'package:smartbee/features/live_stream/infrastructure/capture/media_capture_service.dart';
import 'package:smartbee/features/live_stream/infrastructure/publisher/stream_publisher.dart';
import 'package:smartbee/features/live_stream/infrastructure/publisher/whip_publisher.dart';
import 'package:smartbee/features/live_stream/infrastructure/storage/stream_config_storage.dart';

class FakeMediaCaptureService implements MediaCaptureService {
  FakeMediaCaptureService({
    this.screenCaptureThrows,
    this.screenStreamHasVideo = true,
  });

  MediaStream? _stream;
  bool stopped = false;
  int cameraCaptureCount = 0;
  int screenCaptureCount = 0;
  Object? screenCaptureThrows;
  bool screenStreamHasVideo;

  @override
  MediaStream? get currentStream => _stream;

  @override
  Future<List<MediaDeviceInfo>> getVideoInputDevices() async {
    return [
      MediaDeviceInfo(
        deviceId: 'camera-1',
        label: 'Camera',
        kind: 'videoinput',
      ),
    ];
  }

  @override
  Future<MediaStream> startCameraCapture({
    required StreamProfile profile,
    String? deviceId,
  }) async {
    stopped = false;
    cameraCaptureCount++;
    _stream = FakeMediaStream('camera-stream');
    return _stream!;
  }

  @override
  Future<MediaStream> startScreenCapture({
    required StreamProfile profile,
    bool captureAudio = false,
  }) async {
    screenCaptureCount++;
    final error = screenCaptureThrows;
    if (error != null) {
      throw error;
    }
    stopped = false;
    _stream = FakeMediaStream(
      'screen-stream',
      includeVideo: screenStreamHasVideo,
    );
    return _stream!;
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    for (final track
        in _stream?.getVideoTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = enabled;
    }
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    for (final track
        in _stream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = enabled;
    }
  }

  @override
  Future<void> stopCapture() async {
    stopped = true;
    _stream = null;
  }

  @override
  Future<void> switchCamera() async {}
}

class FakeStreamPublisher implements StreamPublisher {
  FakeStreamPublisher({
    this.failOnStart = false,
    this.failureMessage = 'fake failure',
  });

  final bool failOnStart;
  final String failureMessage;
  final StreamController<StreamPublisherEvent> eventController =
      StreamController<StreamPublisherEvent>.broadcast();
  final StreamController<StreamStatistics> statisticsController =
      StreamController<StreamStatistics>.broadcast();
  bool stopped = false;
  bool started = false;

  @override
  Stream<StreamPublisherEvent> get events => eventController.stream;

  @override
  bool get isPublishing => started && !stopped;

  @override
  Stream<StreamStatistics> get statistics => statisticsController.stream;

  @override
  Future<void> start({
    required MediaStream stream,
    required StreamServerConfig config,
    required StreamProfile profile,
  }) async {
    if (failOnStart) {
      throw Exception(failureMessage);
    }
    stopped = false;
    started = true;
    eventController.add(
      const StreamPublisherEvent(StreamPublisherEventType.publishing),
    );
  }

  @override
  Future<void> stop() async {
    stopped = true;
    eventController.add(
      const StreamPublisherEvent(StreamPublisherEventType.stopped),
    );
  }

  void fail() {
    eventController.add(
      const StreamPublisherEvent(
        StreamPublisherEventType.failed,
        message: 'failed',
      ),
    );
  }
}

class FakeStreamConfigStorage implements StreamConfigStorage {
  StoredStreamConfig? stored;

  @override
  Future<StoredStreamConfig?> load() async => stored;

  @override
  Future<void> save({
    required StreamServerConfig serverConfig,
    required StreamProfile profile,
    required CaptureSourceType sourceType,
  }) async {
    stored = StoredStreamConfig(
      serverConfig: serverConfig,
      profile: profile,
      sourceType: sourceType,
    );
  }
}

StreamPublisherFactory fakePublisherFactory(StreamPublisher publisher) {
  return StreamPublisherFactory((protocol) => publisher);
}

class FakeMediaStream extends MediaStream {
  FakeMediaStream(String id, {bool includeVideo = true}) : super(id, 'fake') {
    _tracks = [
      if (includeVideo) FakeMediaStreamTrack(id: '$id-video', kind: 'video'),
      FakeMediaStreamTrack(id: '$id-audio', kind: 'audio'),
    ];
  }

  late final List<MediaStreamTrack> _tracks;

  @override
  bool? get active => true;

  @override
  Future<void> addTrack(
    MediaStreamTrack track, {
    bool addToNative = true,
  }) async {
    _tracks.add(track);
  }

  @override
  Future<MediaStream> clone() async => FakeMediaStream('$id-clone');

  @override
  Future<void> dispose() async {}

  @override
  Future<void> getMediaTracks() async {}

  @override
  List<MediaStreamTrack> getAudioTracks() {
    return _tracks.where((track) => track.kind == 'audio').toList();
  }

  @override
  MediaStreamTrack? getTrackById(String trackId) {
    return _tracks.where((track) => track.id == trackId).firstOrNull;
  }

  @override
  List<MediaStreamTrack> getTracks() => List.of(_tracks);

  @override
  List<MediaStreamTrack> getVideoTracks() {
    return _tracks.where((track) => track.kind == 'video').toList();
  }

  @override
  Future<void> removeTrack(
    MediaStreamTrack track, {
    bool removeFromNative = true,
  }) async {
    _tracks.remove(track);
  }
}

class FakeMediaStreamTrack extends MediaStreamTrack {
  FakeMediaStreamTrack({required this.id, required this.kind});

  @override
  final String id;

  @override
  final String kind;

  @override
  String? get label => id;

  @override
  bool enabled = true;

  @override
  bool? get muted => false;

  @override
  Future<void> dispose() async {}

  @override
  Map<String, dynamic> getSettings() => const {};

  @override
  Future<void> stop() async {
    onEnded?.call();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}
