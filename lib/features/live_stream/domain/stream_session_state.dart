import 'capture_source_type.dart';
import 'publish_protocol.dart';
import 'stream_profile.dart';
import 'stream_server_config.dart';
import 'stream_statistics.dart';

enum StreamSessionStatus {
  idle,
  requestingPermission,
  preparingCapture,
  previewing,
  connecting,
  publishing,
  reconnecting,
  stopping,
  stopped,
  failed;

  String get label => switch (this) {
    StreamSessionStatus.idle => '空闲',
    StreamSessionStatus.requestingPermission => '请求权限',
    StreamSessionStatus.preparingCapture => '准备采集',
    StreamSessionStatus.previewing => '预览中',
    StreamSessionStatus.connecting => '连接中',
    StreamSessionStatus.publishing => '推流中',
    StreamSessionStatus.reconnecting => '重连中',
    StreamSessionStatus.stopping => '停止中',
    StreamSessionStatus.stopped => '已停止',
    StreamSessionStatus.failed => '失败',
  };

  bool get isBusy => switch (this) {
    StreamSessionStatus.requestingPermission ||
    StreamSessionStatus.preparingCapture ||
    StreamSessionStatus.connecting ||
    StreamSessionStatus.reconnecting ||
    StreamSessionStatus.stopping => true,
    _ => false,
  };
}

class StreamSessionState {
  const StreamSessionState({
    required this.status,
    required this.sourceType,
    required this.protocol,
    required this.config,
    required this.profile,
    required this.logs,
    required this.statisticsHistory,
    required this.currentStatistics,
    this.errorMessage,
    this.startedAt,
    this.retryAttempt = 0,
  });

  factory StreamSessionState.initial() {
    return StreamSessionState(
      status: StreamSessionStatus.idle,
      sourceType: CaptureSourceType.camera,
      protocol: PublishProtocol.whip,
      config: StreamServerConfig.defaults(),
      profile: StreamProfile.defaults(),
      logs: const [],
      statisticsHistory: const [],
      currentStatistics: StreamStatistics.empty(),
    );
  }

  final StreamSessionStatus status;
  final CaptureSourceType sourceType;
  final PublishProtocol protocol;
  final StreamServerConfig config;
  final StreamProfile profile;
  final List<String> logs;
  final List<StreamStatistics> statisticsHistory;
  final StreamStatistics currentStatistics;
  final String? errorMessage;
  final DateTime? startedAt;
  final int retryAttempt;

  bool get hasPreview =>
      status == StreamSessionStatus.previewing ||
      status == StreamSessionStatus.connecting ||
      status == StreamSessionStatus.publishing ||
      status == StreamSessionStatus.reconnecting;

  bool get isPublishing =>
      status == StreamSessionStatus.publishing ||
      status == StreamSessionStatus.reconnecting ||
      status == StreamSessionStatus.connecting;

  StreamSessionState copyWith({
    StreamSessionStatus? status,
    CaptureSourceType? sourceType,
    PublishProtocol? protocol,
    StreamServerConfig? config,
    StreamProfile? profile,
    List<String>? logs,
    List<StreamStatistics>? statisticsHistory,
    StreamStatistics? currentStatistics,
    String? errorMessage,
    bool clearError = false,
    DateTime? startedAt,
    bool clearStartedAt = false,
    int? retryAttempt,
  }) {
    return StreamSessionState(
      status: status ?? this.status,
      sourceType: sourceType ?? this.sourceType,
      protocol: protocol ?? this.protocol,
      config: config ?? this.config,
      profile: profile ?? this.profile,
      logs: logs ?? this.logs,
      statisticsHistory: statisticsHistory ?? this.statisticsHistory,
      currentStatistics: currentStatistics ?? this.currentStatistics,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
      retryAttempt: retryAttempt ?? this.retryAttempt,
    );
  }
}
