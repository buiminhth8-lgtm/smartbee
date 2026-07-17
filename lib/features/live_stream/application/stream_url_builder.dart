import '../domain/stream_server_config.dart';

class StreamOutputUrls {
  const StreamOutputUrls({
    required this.whip,
    required this.rtsp,
    required this.rtmp,
    required this.hls,
    required this.webrtc,
  });

  final String whip;
  final String rtsp;
  final String rtmp;
  final String hls;
  final String webrtc;
}

class StreamUrlBuilder {
  const StreamUrlBuilder();

  StreamOutputUrls build(StreamServerConfig config) {
    final host = config.host.trim();
    final stream = Uri.encodeComponent(config.streamName.trim());
    final httpScheme = config.useHttps ? 'https' : 'http';
    return StreamOutputUrls(
      whip: '$httpScheme://$host:${config.webrtcPort}/$stream/whip',
      rtsp: 'rtsp://$host:8554/$stream',
      rtmp: 'rtmp://$host:1935/$stream',
      hls: '$httpScheme://$host:8888/$stream/index.m3u8',
      webrtc: '$httpScheme://$host:${config.webrtcPort}/$stream',
    );
  }
}
