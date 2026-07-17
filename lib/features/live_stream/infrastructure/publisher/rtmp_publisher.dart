import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../domain/stream_profile.dart';
import '../../domain/stream_server_config.dart';
import '../../domain/stream_statistics.dart';
import '../../domain/streaming_exception.dart';
import 'stream_publisher.dart';

class RtmpPublisher implements StreamPublisher {
  final _events = const Stream<StreamPublisherEvent>.empty();
  final _statistics = const Stream<StreamStatistics>.empty();

  @override
  Stream<StreamPublisherEvent> get events => _events;

  @override
  bool get isPublishing => false;

  @override
  Stream<StreamStatistics> get statistics => _statistics;

  @override
  Future<void> start({
    required MediaStream stream,
    required StreamServerConfig config,
    required StreamProfile profile,
  }) {
    throw const StreamingException(
      StreamingErrorCode.unsupportedProtocol,
      '当前平台暂未实现直接推送，请使用 WHIP 或服务器协议转换。',
    );
  }

  @override
  Future<void> stop() async {}
}
