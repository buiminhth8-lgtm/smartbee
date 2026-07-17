import 'package:flutter_test/flutter_test.dart';
import 'package:smartbee/features/live_stream/application/stream_url_builder.dart';
import 'package:smartbee/features/live_stream/domain/stream_server_config.dart';

void main() {
  test('输出URL构造正确', () {
    final urls = const StreamUrlBuilder().build(StreamServerConfig.defaults());
    expect(urls.whip, 'http://127.0.0.1:8889/smartbee/whip');
    expect(urls.rtsp, 'rtsp://127.0.0.1:8554/smartbee');
    expect(urls.rtmp, 'rtmp://127.0.0.1:1935/smartbee');
    expect(urls.hls, 'http://127.0.0.1:8888/smartbee/index.m3u8');
    expect(urls.webrtc, 'http://127.0.0.1:8889/smartbee');
  });
}
