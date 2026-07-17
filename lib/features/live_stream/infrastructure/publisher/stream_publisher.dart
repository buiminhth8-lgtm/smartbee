import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../domain/stream_profile.dart';
import '../../domain/stream_server_config.dart';
import '../../domain/stream_statistics.dart';

enum StreamPublisherEventType {
  connecting,
  publishing,
  disconnected,
  failed,
  stopped,
}

class StreamPublisherEvent {
  const StreamPublisherEvent(this.type, {this.message, this.error});

  final StreamPublisherEventType type;
  final String? message;
  final Object? error;
}

abstract interface class StreamPublisher {
  Future<void> start({
    required MediaStream stream,
    required StreamServerConfig config,
    required StreamProfile profile,
  });

  Future<void> stop();

  Stream<StreamPublisherEvent> get events;

  Stream<StreamStatistics> get statistics;

  bool get isPublishing;
}
