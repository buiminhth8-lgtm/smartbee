enum PublishProtocol {
  whip,
  rtmp,
  rtsp;

  String get label => switch (this) {
    PublishProtocol.whip => 'WHIP',
    PublishProtocol.rtmp => 'RTMP',
    PublishProtocol.rtsp => 'RTSP',
  };

  bool get isImplemented => this == PublishProtocol.whip;
}
