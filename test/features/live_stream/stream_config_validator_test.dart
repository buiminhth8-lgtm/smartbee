import 'package:flutter_test/flutter_test.dart';
import 'package:smartbee/features/live_stream/application/stream_config_validator.dart';
import 'package:smartbee/features/live_stream/domain/stream_server_config.dart';
import 'package:smartbee/features/live_stream/domain/streaming_exception.dart';

void main() {
  const validator = StreamConfigValidator();

  test('默认配置正确', () {
    final config = StreamServerConfig.defaults();
    expect(config.host, '127.0.0.1');
    expect(config.webrtcPort, 8889);
    expect(config.streamName, 'smartbee');
    expect(config.useHttps, isFalse);
    validator.validate(config);
  });

  test('非法Host被拒绝', () {
    expect(
      () => validator.validate(
        StreamServerConfig.defaults().copyWith(host: 'bad host'),
      ),
      throwsA(isA<StreamingException>()),
    );
  });

  test('非法端口被拒绝', () {
    expect(
      () => validator.validate(
        StreamServerConfig.defaults().copyWith(webrtcPort: 70000),
      ),
      throwsA(isA<StreamingException>()),
    );
  });

  test('非法流名称被拒绝', () {
    expect(
      () => validator.validate(
        StreamServerConfig.defaults().copyWith(streamName: '-bad'),
      ),
      throwsA(isA<StreamingException>()),
    );
  });
}
