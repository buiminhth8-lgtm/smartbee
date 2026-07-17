import '../domain/stream_server_config.dart';
import '../domain/streaming_exception.dart';

class StreamConfigValidator {
  const StreamConfigValidator();

  void validate(StreamServerConfig config) {
    final host = config.host.trim();
    final streamName = config.streamName.trim();

    if (host.isEmpty ||
        host.contains(' ') ||
        host.contains('/') ||
        host.contains('\\') ||
        host.length > 253) {
      throw const StreamingException(
        StreamingErrorCode.invalidServerConfig,
        '服务器地址不合法，请填写 IP、localhost 或域名。',
      );
    }

    if (config.webrtcPort < 1 || config.webrtcPort > 65535) {
      throw const StreamingException(
        StreamingErrorCode.invalidServerConfig,
        '端口必须在 1 到 65535 之间。',
      );
    }

    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(streamName)) {
      throw const StreamingException(
        StreamingErrorCode.invalidServerConfig,
        '流名称只能包含字母、数字、点、下划线和短横线，且不能以符号开头。',
      );
    }
  }
}
