import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../domain/capture_source_type.dart';
import '../domain/publish_protocol.dart';
import '../domain/stream_profile.dart';
import '../domain/stream_server_config.dart';
import '../domain/stream_session_state.dart';
import '../domain/stream_statistics.dart';
import '../domain/streaming_exception.dart';
import '../infrastructure/capture/media_capture_service.dart';
import '../infrastructure/capture/screen_capture_adapter.dart';
import '../infrastructure/publisher/stream_publisher.dart';
import '../infrastructure/publisher/whip_publisher.dart';
import '../infrastructure/storage/stream_config_storage.dart';
import 'stream_config_validator.dart';

class LiveStreamController extends ChangeNotifier {
  LiveStreamController({
    required this.captureService,
    required this.publisherFactory,
    required this.storage,
    this.validator = const StreamConfigValidator(),
  });

  final MediaCaptureService captureService;
  final StreamPublisherFactory publisherFactory;
  final StreamConfigStorage storage;
  final StreamConfigValidator validator;

  StreamSessionState _state = StreamSessionState.initial();
  StreamPublisher? _publisher;
  StreamSubscription<StreamPublisherEvent>? _publisherEvents;
  StreamSubscription<StreamStatistics>? _statisticsEvents;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _userStopped = false;
  bool _exiting = false;
  bool _isOpeningPreview = false;
  final Queue<String> _logs = Queue<String>();
  final Queue<StreamStatistics> _statistics = Queue<StreamStatistics>();

  StreamSessionState get state => _state;
  MediaStream? get currentStream => captureService.currentStream;

  void setDesktopCaptureSourcePicker(DesktopCaptureSourcePicker? picker) {
    final service = captureService;
    if (service is DesktopCaptureSourcePickerHost) {
      (service as DesktopCaptureSourcePickerHost).desktopCaptureSourcePicker =
          picker;
    }
  }

  Future<void> loadSavedConfig() async {
    final stored = await storage.load();
    if (stored == null || _disposed) {
      return;
    }
    _setState(
      _state.copyWith(
        config: stored.serverConfig,
        profile: stored.profile,
        sourceType: stored.sourceType,
      ),
    );
  }

  Future<void> updateConfig(StreamServerConfig config) async {
    _setState(_state.copyWith(config: config, clearError: true));
    await _persist();
  }

  Future<void> updateProfile(StreamProfile profile) async {
    _setState(_state.copyWith(profile: profile, clearError: true));
    await _persist();
    await captureService.setMicrophoneEnabled(profile.microphoneEnabled);
    await captureService.setCameraEnabled(profile.cameraEnabled);
  }

  Future<void> setSourceType(CaptureSourceType sourceType) async {
    if (_state.isPublishing) {
      _addLog('推流中不能切换采集来源，请先停止推流。');
      return;
    }
    _setState(_state.copyWith(sourceType: sourceType, clearError: true));
    await _persist();
  }

  void setProtocol(PublishProtocol protocol) {
    _setState(_state.copyWith(protocol: protocol, clearError: true));
  }

  Future<void> openPreview() async {
    if (_isOpeningPreview || _state.status.isBusy || _state.isPublishing) {
      return;
    }
    _isOpeningPreview = true;
    _userStopped = false;
    _setState(
      _state.copyWith(
        status: StreamSessionStatus.requestingPermission,
        clearError: true,
      ),
    );

    try {
      _setState(_state.copyWith(status: StreamSessionStatus.preparingCapture));
      await _startCaptureForCurrentSource();
      final stream = captureService.currentStream;
      if (stream == null || stream.getVideoTracks().isEmpty) {
        throw const StreamingException(
          StreamingErrorCode.emptyVideoTrack,
          '系统没有返回视频轨。',
        );
      }
      _addLog('${_state.sourceType.label}预览已打开');
      _setState(_state.copyWith(status: StreamSessionStatus.previewing));
      debugPrint('[ScreenCapture] step=openPreview-success status=previewing');
    } catch (error, stackTrace) {
      final exception = normalizeStreamingException(error);
      if (exception.code == StreamingErrorCode.permissionCancelled) {
        _addLog(exception.message);
        debugPrint(
          '[ScreenCapture] step=openPreview-cancelled '
          'status=idle errorType=${error.runtimeType} '
          'error=${exception.message}',
        );
        debugPrintStack(stackTrace: stackTrace);
        _setState(
          _state.copyWith(status: StreamSessionStatus.idle, clearError: true),
        );
        return;
      }
      _addLog('采集失败：${exception.message}');
      debugPrint(
        '[ScreenCapture] step=openPreview-failed '
        'status=${StreamSessionStatus.failed.name} errorType=${error.runtimeType} '
        'error=${exception.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      _setState(
        _state.copyWith(
          status: StreamSessionStatus.failed,
          errorMessage: exception.message,
        ),
      );
    } finally {
      _isOpeningPreview = false;
    }
  }

  Future<void> startPublishing() async {
    if (_state.isPublishing || _state.status.isBusy) {
      return;
    }

    try {
      validator.validate(_state.config);
      _userStopped = false;
      _setState(
        _state.copyWith(
          status: StreamSessionStatus.preparingCapture,
          clearError: true,
          startedAt: DateTime.now(),
        ),
      );

      var stream = captureService.currentStream;
      if (stream == null) {
        await _startCaptureForCurrentSource();
        stream = captureService.currentStream;
      }
      if (stream == null) {
        throw const StreamingException(
          StreamingErrorCode.captureStoppedBySystem,
          '没有可用的媒体流，请先打开预览。',
        );
      }

      _setState(_state.copyWith(status: StreamSessionStatus.connecting));
      final publisher = publisherFactory.create(_state.protocol);
      await _bindPublisher(publisher);
      await publisher.start(
        stream: stream,
        config: _state.config,
        profile: _state.profile,
      );
      _publisher = publisher;
      _setState(
        _state.copyWith(
          status: StreamSessionStatus.publishing,
          retryAttempt: 0,
        ),
      );
      _addLog('WHIP 推流已开始');
    } catch (error) {
      final exception = normalizeStreamingException(error);
      _addLog('推流失败：${exception.message}');
      _setState(
        _state.copyWith(
          status: StreamSessionStatus.failed,
          errorMessage: exception.message,
        ),
      );
      await _publisher?.stop();
    }
  }

  Future<void> stopPublishing({bool userInitiated = true}) async {
    if (userInitiated) {
      _userStopped = true;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (!_state.isPublishing &&
        _state.status != StreamSessionStatus.previewing &&
        _publisher == null &&
        captureService.currentStream == null) {
      _setState(
        _state.copyWith(
          status: StreamSessionStatus.stopped,
          clearStartedAt: true,
        ),
      );
      return;
    }

    _setState(_state.copyWith(status: StreamSessionStatus.stopping));
    await _publisherEvents?.cancel();
    await _statisticsEvents?.cancel();
    _publisherEvents = null;
    _statisticsEvents = null;
    await _publisher?.stop();
    _publisher = null;
    await captureService.stopCapture();
    _addLog('推流和采集已停止');
    _setState(
      _state.copyWith(
        status: StreamSessionStatus.stopped,
        clearStartedAt: true,
        retryAttempt: 0,
      ),
    );
  }

  Future<void> switchCamera() async {
    try {
      await captureService.switchCamera();
      _addLog('已切换摄像头');
    } catch (error) {
      final exception = normalizeStreamingException(error);
      _addLog('切换摄像头失败：${exception.message}');
      _setState(_state.copyWith(errorMessage: exception.message));
    }
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    await updateProfile(_state.profile.copyWith(microphoneEnabled: enabled));
    _addLog(enabled ? '麦克风已开启' : '麦克风已静音');
  }

  Future<void> setCameraEnabled(bool enabled) async {
    await updateProfile(_state.profile.copyWith(cameraEnabled: enabled));
    _addLog(enabled ? '视频已开启' : '视频已关闭');
  }

  Future<void> _startCaptureForCurrentSource() async {
    if (_state.sourceType == CaptureSourceType.camera) {
      await captureService.startCameraCapture(profile: _state.profile);
    } else {
      await captureService.startScreenCapture(
        profile: _state.profile,
        captureAudio: false,
      );
      _wireScreenStopHandler();
    }
  }

  Future<void> _bindPublisher(StreamPublisher publisher) async {
    await _publisherEvents?.cancel();
    await _statisticsEvents?.cancel();
    _publisherEvents = publisher.events.listen(_handlePublisherEvent);
    _statisticsEvents = publisher.statistics.listen(_handleStatistics);
  }

  void _handlePublisherEvent(StreamPublisherEvent event) {
    if (_disposed) {
      return;
    }
    switch (event.type) {
      case StreamPublisherEventType.publishing:
        _setState(
          _state.copyWith(
            status: StreamSessionStatus.publishing,
            retryAttempt: 0,
          ),
        );
      case StreamPublisherEventType.disconnected:
      case StreamPublisherEventType.failed:
        _scheduleReconnect(event.message ?? '连接断开');
      case StreamPublisherEventType.stopped:
        if (!_userStopped) {
          _setState(_state.copyWith(status: StreamSessionStatus.stopped));
        }
      case StreamPublisherEventType.connecting:
        _setState(_state.copyWith(status: StreamSessionStatus.connecting));
    }
  }

  void _handleStatistics(StreamStatistics statistics) {
    _statistics.add(statistics);
    while (_statistics.length > 60) {
      _statistics.removeFirst();
    }
    _setState(
      _state.copyWith(
        currentStatistics: statistics,
        statisticsHistory: List.unmodifiable(_statistics),
      ),
    );
  }

  void _scheduleReconnect(String reason) {
    if (_userStopped || _exiting || _disposed) {
      return;
    }
    final attempt = _state.retryAttempt + 1;
    if (attempt > 5) {
      _addLog('自动重连已达到最大次数');
      _setState(
        _state.copyWith(
          status: StreamSessionStatus.failed,
          errorMessage: '网络连接失败，已停止自动重连。',
        ),
      );
      return;
    }

    final delay = Duration(seconds: 1 << (attempt - 1));
    _addLog('$reason，${delay.inSeconds} 秒后第 $attempt 次重连');
    _setState(
      _state.copyWith(
        status: StreamSessionStatus.reconnecting,
        retryAttempt: attempt,
      ),
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (_userStopped || _exiting || _disposed) {
        return;
      }
      try {
        await _publisher?.stop();
        final stream = captureService.currentStream;
        if (stream == null) {
          throw const StreamingException(
            StreamingErrorCode.captureStoppedBySystem,
            '采集已停止，无法重连。',
          );
        }
        final publisher = publisherFactory.create(_state.protocol);
        await _bindPublisher(publisher);
        _publisher = publisher;
        await publisher.start(
          stream: stream,
          config: _state.config,
          profile: _state.profile,
        );
        _addLog('自动重连成功');
        _setState(
          _state.copyWith(
            status: StreamSessionStatus.publishing,
            retryAttempt: 0,
          ),
        );
      } catch (error) {
        final exception = normalizeStreamingException(error);
        _addLog('重连失败：${exception.message}');
        _scheduleReconnect(exception.message);
      }
    });
  }

  void _wireScreenStopHandler() {
    final tracks = captureService.currentStream?.getVideoTracks() ?? const [];
    for (final track in tracks) {
      track.onEnded = () {
        if (_disposed) {
          return;
        }
        _addLog('系统已终止屏幕共享');
        unawaited(stopPublishing(userInitiated: false));
        _setState(
          _state.copyWith(
            status: StreamSessionStatus.stopped,
            errorMessage: '录屏已被系统停止。',
          ),
        );
      };
    }
  }

  Future<void> _persist() {
    return storage.save(
      serverConfig: _state.config,
      profile: _state.profile,
      sourceType: _state.sourceType,
    );
  }

  void _addLog(String message) {
    final sanitized = _sanitize(message);
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    _logs.add('[$stamp] $sanitized');
    while (_logs.length > 200) {
      _logs.removeFirst();
    }
    _setState(_state.copyWith(logs: List.unmodifiable(_logs)));
  }

  String _sanitize(String message) {
    final token = _state.config.bearerToken.trim();
    if (token.isEmpty) {
      return message;
    }
    return message.replaceAll(token, '***');
  }

  void _setState(StreamSessionState state) {
    if (_disposed) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _exiting = true;
    _reconnectTimer?.cancel();
    _publisherEvents?.cancel();
    _statisticsEvents?.cancel();
    _publisher?.stop();
    captureService.stopCapture();
    super.dispose();
  }
}
