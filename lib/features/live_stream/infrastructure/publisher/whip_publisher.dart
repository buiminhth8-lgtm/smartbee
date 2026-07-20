import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

import '../../application/stream_url_builder.dart';
import '../../domain/publish_protocol.dart';
import '../../domain/stream_profile.dart';
import '../../domain/stream_server_config.dart';
import '../../domain/stream_statistics.dart';
import '../../domain/streaming_exception.dart';
import 'rtmp_publisher.dart';
import 'rtsp_publisher.dart';
import 'stream_publisher.dart';

typedef StreamPublisherCreator =
    StreamPublisher Function(PublishProtocol protocol);

class StreamPublisherFactory {
  const StreamPublisherFactory(this._creator);

  factory StreamPublisherFactory.defaults() {
    return StreamPublisherFactory((protocol) {
      return switch (protocol) {
        PublishProtocol.whip => WhipPublisher(),
        PublishProtocol.rtmp => RtmpPublisher(),
        PublishProtocol.rtsp => RtspPublisher(),
      };
    });
  }

  final StreamPublisherCreator _creator;

  StreamPublisher create(PublishProtocol protocol) => _creator(protocol);
}

String safeBodyPreview(String value, {int maxLength = 200}) {
  if (value.isEmpty) {
    return '<empty>';
  }

  final normalized = value
      .replaceAll(RegExp(r'Bearer\s+[^\s]+'), 'Bearer ***')
      .replaceAll('\r', r'\r')
      .replaceAll('\n', r'\n');

  if (normalized.length <= maxLength) {
    return normalized;
  }

  return '${normalized.substring(0, maxLength)}...';
}

String validateWhipOfferDescription(RTCSessionDescription? description) {
  final type = description?.type;
  final sdp = description?.sdp?.trim();
  if (type?.toLowerCase() != 'offer' || sdp == null || sdp.isEmpty) {
    throw const StreamingException(
      StreamingErrorCode.invalidOfferSdp,
      '本地 Offer SDP 无效，无法开始 WHIP 推流。',
    );
  }
  if (!sdp.startsWith('v=0')) {
    throw StreamingException(
      StreamingErrorCode.invalidOfferSdp,
      '本地 Offer SDP 格式无效：${safeBodyPreview(sdp)}',
    );
  }
  return sdp;
}

String validateWhipAnswerResponse(http.Response response) {
  final contentType = response.headers['content-type']?.toLowerCase();
  final answerSdp = _normalizeSdp(response.body);

  if (response.statusCode != 201 && response.statusCode != 200) {
    throw StreamingException(
      _httpErrorCode(response.statusCode),
      'WHIP 请求失败：HTTP ${response.statusCode}，'
      '响应：${safeBodyPreview(answerSdp.isEmpty ? response.body : answerSdp)}',
    );
  }

  if (contentType == null || !contentType.startsWith('application/sdp')) {
    throw StreamingException(
      StreamingErrorCode.invalidAnswerSdp,
      'WHIP 返回的不是 application/sdp，请检查请求地址是否为 /流名称/whip。'
      '实际 Content-Type：${contentType ?? '<missing>'}，'
      '响应：${safeBodyPreview(answerSdp)}',
    );
  }

  _validateAnswerSdp(answerSdp);
  return answerSdp;
}

RTCSessionDescription buildWhipAnswerDescription(String answerSdp) {
  final normalized = _normalizeSdp(answerSdp);
  _validateAnswerSdp(normalized);
  return RTCSessionDescription(normalized, 'answer');
}

StreamingErrorCode _httpErrorCode(int statusCode) {
  return switch (statusCode) {
    401 || 403 => StreamingErrorCode.authenticationFailed,
    409 => StreamingErrorCode.publishConflict,
    _ => StreamingErrorCode.whipHttpFailed,
  };
}

String _normalizeSdp(String value) {
  var sdp = value.trim();
  if (sdp.startsWith('\uFEFF')) {
    sdp = sdp.substring(1).trim();
  }
  return sdp;
}

void _validateAnswerSdp(String answerSdp) {
  if (answerSdp.isEmpty) {
    throw const StreamingException(
      StreamingErrorCode.invalidAnswerSdp,
      'WHIP 服务器返回了空 SDP Answer。',
    );
  }

  if (!answerSdp.startsWith('v=0')) {
    throw StreamingException(
      StreamingErrorCode.invalidAnswerSdp,
      'WHIP 服务器返回的内容不是有效 SDP，'
      '响应开头：${safeBodyPreview(answerSdp)}',
    );
  }
}

class WhipPublisher implements StreamPublisher {
  WhipPublisher({http.Client? client, StreamUrlBuilder? urlBuilder})
    : _client = client ?? http.Client(),
      _urlBuilder = urlBuilder ?? const StreamUrlBuilder();

  final http.Client _client;
  final StreamUrlBuilder _urlBuilder;

  final StreamController<StreamPublisherEvent> _events =
      StreamController<StreamPublisherEvent>.broadcast();
  final StreamController<StreamStatistics> _statistics =
      StreamController<StreamStatistics>.broadcast();

  RTCPeerConnection? _peerConnection;
  Uri? _sessionUri;
  Timer? _statsTimer;
  DateTime? _startedAt;
  bool _isPublishing = false;
  int _previousVideoBytes = 0;
  int _previousAudioBytes = 0;
  DateTime? _previousStatsAt;

  @override
  Stream<StreamPublisherEvent> get events => _events.stream;

  @override
  Stream<StreamStatistics> get statistics => _statistics.stream;

  @override
  bool get isPublishing => _isPublishing;

  @override
  Future<void> start({
    required MediaStream stream,
    required StreamServerConfig config,
    required StreamProfile profile,
  }) async {
    if (_isPublishing) {
      return;
    }

    _events.add(
      const StreamPublisherEvent(StreamPublisherEventType.connecting),
    );
    try {
      final peerConnection = await createPeerConnection({
        'sdpSemantics': 'unified-plan',
        'iceServers': const <Map<String, Object>>[],
      });
      _peerConnection = peerConnection;
      _wirePeerConnectionEvents(peerConnection);

      for (final track in stream.getTracks()) {
        final sender = await peerConnection.addTrack(track, stream);
        if (track.kind == 'video') {
          await _configureVideoSender(sender, profile);
        }
      }

      final offer = await peerConnection.createOffer({
        'offerToReceiveAudio': false,
        'offerToReceiveVideo': false,
      });
      offer.sdp = _preferH264(offer.sdp ?? '');
      _logWhip(
        'offer-created',
        fields: {'type': offer.type, 'sdpLength': offer.sdp?.length ?? 0},
      );
      await peerConnection.setLocalDescription(offer);
      _logWhip('local-description-set');
      await _waitForIceGathering(peerConnection);
      _logWhip(
        'ice-gathering-complete',
        fields: {'state': _enumName(peerConnection.iceGatheringState)},
      );

      final localDescription = await peerConnection.getLocalDescription();
      final offerSdp = validateWhipOfferDescription(localDescription);
      _logWhip(
        'local-description-ready',
        fields: {'type': localDescription?.type, 'sdpLength': offerSdp.length},
      );

      final whipUri = Uri.parse(_urlBuilder.build(config).whip);
      final response = await _postOffer(whipUri, config, offerSdp);
      _logWhip(
        'response-received',
        fields: {
          'status': response.statusCode,
          'contentType': response.headers['content-type'],
          'location': response.headers['location'],
          'bodyLength': response.body.length,
        },
      );

      final answerSdp = validateWhipAnswerResponse(response);
      _logWhip(
        'answer-validation',
        fields: {
          'startsWithV0': answerSdp.startsWith('v=0'),
          'containsVideo': answerSdp.contains('m=video'),
          'answerLength': answerSdp.length,
          'preview': safeBodyPreview(answerSdp),
        },
      );

      final remoteDescription = buildWhipAnswerDescription(answerSdp);
      _logWhip(
        'setRemoteDescription-start',
        fields: {
          'type': remoteDescription.type,
          'sdpLength': remoteDescription.sdp?.length ?? 0,
          'startsWithV0': answerSdp.startsWith('v=0'),
        },
      );
      try {
        await peerConnection.setRemoteDescription(remoteDescription);
      } catch (error, stackTrace) {
        _logWhip(
          'setRemoteDescription-failed',
          error: error,
          stackTrace: stackTrace,
          fields: {
            'remoteType': remoteDescription.type,
            'answerLength': answerSdp.length,
            'startsWithV0': answerSdp.startsWith('v=0'),
          },
        );
        throw StreamingException(
          StreamingErrorCode.setRemoteDescriptionFailed,
          '服务器返回的 SDP Answer 无法设置到 PeerConnection。',
          cause: error,
        );
      }
      _logWhip('setRemoteDescription-success');

      final location = response.headers['location'];
      if (location != null && location.trim().isNotEmpty) {
        _sessionUri = whipUri.resolve(location.trim());
      }

      await _waitForIceConnected(peerConnection);
      _wirePeerConnectionEvents(peerConnection);
      _logWhip(
        'ice-connected',
        fields: {'state': _enumName(peerConnection.iceConnectionState)},
      );
      _isPublishing = true;
      _startedAt = DateTime.now();
      _startStatisticsTimer(profile);
      _logWhip('publishing');
      _events.add(
        const StreamPublisherEvent(StreamPublisherEventType.publishing),
      );
    } on TimeoutException catch (error) {
      await stop();
      throw StreamingException(
        StreamingErrorCode.serverUnreachable,
        '连接超时，服务器不可达。',
        cause: error,
      );
    } catch (error, stackTrace) {
      await stop();
      if (error is StreamingException) {
        rethrow;
      }

      _logWhip('start-failed', error: error, stackTrace: stackTrace);
      throw StreamingException(
        StreamingErrorCode.sdpNegotiationFailed,
        '媒体协商失败，请检查服务器 WHIP 配置和网络。',
        cause: error,
      );
    }
  }

  Future<http.Response> _postOffer(
    Uri uri,
    StreamServerConfig config,
    String offerSdp,
  ) async {
    final headers = <String, String>{
      'Content-Type': 'application/sdp',
      'Accept': 'application/sdp',
      if (config.hasBearerToken)
        'Authorization': 'Bearer ${config.bearerToken.trim()}',
    };
    _logWhip(
      'whip-request-start',
      fields: {
        'url': uri,
        'offerLength': offerSdp.length,
        'hasBearerToken': config.hasBearerToken,
      },
    );
    final response = await _client
        .post(uri, headers: headers, body: offerSdp)
        .timeout(const Duration(seconds: 12));

    return response;
  }

  Future<void> _configureVideoSender(
    RTCRtpSender sender,
    StreamProfile profile,
  ) async {
    final parameters = sender.parameters;
    final encodings = parameters.encodings;
    if (encodings == null || encodings.isEmpty) {
      parameters.encodings = [
        RTCRtpEncoding(
          maxBitrate: profile.videoBitrateKbps * 1000,
          maxFramerate: profile.fps,
          scaleResolutionDownBy: 1,
        ),
      ];
    } else {
      encodings.first.maxBitrate = profile.videoBitrateKbps * 1000;
      encodings.first.maxFramerate = profile.fps;
      encodings.first.scaleResolutionDownBy = 1;
    }
    parameters.degradationPreference = RTCDegradationPreference.BALANCED;
    await sender.setParameters(parameters);
  }

  Future<void> _waitForIceGathering(RTCPeerConnection peerConnection) async {
    if (peerConnection.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }

    final completer = Completer<void>();
    peerConnection.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !completer.isCompleted) {
        completer.complete();
      }
    };

    try {
      await completer.future.timeout(const Duration(seconds: 8));
    } on TimeoutException catch (error) {
      throw StreamingException(
        StreamingErrorCode.iceGatheringTimeout,
        'ICE 候选收集超时，无法发送完整 WHIP Offer。',
        cause: error,
      );
    }
  }

  Future<void> _waitForIceConnected(RTCPeerConnection peerConnection) async {
    if (_isIceConnected(peerConnection.iceConnectionState)) {
      return;
    }
    if (peerConnection.iceConnectionState ==
        RTCIceConnectionState.RTCIceConnectionStateFailed) {
      throw const StreamingException(
        StreamingErrorCode.iceConnectionFailed,
        'ICE 连接失败，无法建立 WebRTC 推流连接。',
      );
    }

    final completer = Completer<void>();
    peerConnection.onIceConnectionState = (state) {
      if (_isIceConnected(state) && !completer.isCompleted) {
        completer.complete();
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed &&
          !completer.isCompleted) {
        completer.completeError(
          const StreamingException(
            StreamingErrorCode.iceConnectionFailed,
            'ICE 连接失败，无法建立 WebRTC 推流连接。',
          ),
        );
      }
    };

    try {
      await completer.future.timeout(const Duration(seconds: 12));
    } on TimeoutException catch (error) {
      throw StreamingException(
        StreamingErrorCode.iceConnectionTimeout,
        'ICE 连接超时，请检查 MediaMTX WebRTC 端口、UDP 端口和网络。',
        cause: error,
      );
    }
  }

  bool _isIceConnected(RTCIceConnectionState? state) {
    return state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        state == RTCIceConnectionState.RTCIceConnectionStateCompleted;
  }

  void _wirePeerConnectionEvents(RTCPeerConnection peerConnection) {
    peerConnection.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _events.add(
          const StreamPublisherEvent(
            StreamPublisherEventType.failed,
            message: 'PeerConnection failed',
          ),
        );
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _events.add(
          const StreamPublisherEvent(
            StreamPublisherEventType.disconnected,
            message: 'PeerConnection disconnected',
          ),
        );
      }
    };
    peerConnection.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _events.add(
          const StreamPublisherEvent(
            StreamPublisherEventType.failed,
            message: 'ICE failed',
          ),
        );
      }
    };
  }

  void _startStatisticsTimer(StreamProfile profile) {
    _statsTimer?.cancel();
    _previousStatsAt = null;
    _previousVideoBytes = 0;
    _previousAudioBytes = 0;
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final peerConnection = _peerConnection;
      if (peerConnection == null) {
        return;
      }
      try {
        final reports = await peerConnection.getStats();
        _statistics.add(_parseStatistics(reports, profile, peerConnection));
      } catch (_) {
        // Stats are diagnostic only; never tear down a working session for a
        // transient stats read failure.
      }
    });
  }

  StreamStatistics _parseStatistics(
    List<StatsReport> reports,
    StreamProfile profile,
    RTCPeerConnection peerConnection,
  ) {
    var videoBytes = 0;
    var audioBytes = 0;
    var packetsLost = 0;
    var framesPerSecond = 0.0;
    var roundTripTimeMs = 0.0;
    var candidateType = '-';
    var videoCodec = 'H264/VP8';
    var audioCodec = 'Opus';

    for (final report in reports) {
      final values = report.values;
      final type = report.type.toLowerCase();
      final kind = '${values['kind'] ?? values['mediaType'] ?? ''}';

      if (type == 'outbound-rtp') {
        final bytes = _asInt(values['bytesSent']);
        if (kind == 'video') {
          videoBytes += bytes;
          framesPerSecond = _asDouble(
            values['framesPerSecond'] ?? values['framesEncoded'],
          );
        } else if (kind == 'audio') {
          audioBytes += bytes;
        }
        packetsLost += _asInt(values['packetsLost']);
      }

      if (type.contains('candidate-pair') &&
          values['currentRoundTripTime'] != null) {
        roundTripTimeMs = _asDouble(values['currentRoundTripTime']) * 1000;
      }

      if (type.contains('local-candidate') && values['candidateType'] != null) {
        candidateType = '${values['candidateType']}';
      }

      if (type == 'codec') {
        final mime = '${values['mimeType'] ?? ''}';
        if (mime.toLowerCase().contains('video')) {
          videoCodec = mime.split('/').last;
        } else if (mime.toLowerCase().contains('audio')) {
          audioCodec = mime.split('/').last;
        }
      }
    }

    final now = DateTime.now();
    final previousAt = _previousStatsAt;
    var sendBitrateKbps = 0.0;
    if (previousAt != null) {
      final elapsedSeconds =
          now.difference(previousAt).inMilliseconds.clamp(1, 60000) / 1000;
      final deltaBytes =
          (videoBytes + audioBytes) -
          (_previousVideoBytes + _previousAudioBytes);
      sendBitrateKbps = deltaBytes > 0
          ? deltaBytes * 8 / 1000 / elapsedSeconds
          : 0;
    }
    _previousStatsAt = now;
    _previousVideoBytes = videoBytes;
    _previousAudioBytes = audioBytes;

    return StreamStatistics(
      timestamp: now,
      elapsed: _startedAt == null ? Duration.zero : now.difference(_startedAt!),
      statusLabel: '推流中',
      width: profile.width,
      height: profile.height,
      framesPerSecond: framesPerSecond > 0 && framesPerSecond < 240
          ? framesPerSecond
          : profile.fps.toDouble(),
      sendBitrateKbps: sendBitrateKbps,
      videoBytesSent: videoBytes,
      audioBytesSent: audioBytes,
      packetsLost: packetsLost,
      roundTripTimeMs: roundTripTimeMs,
      videoCodec: videoCodec,
      audioCodec: audioCodec,
      iceState: '${peerConnection.iceConnectionState}'.split('.').last,
      peerConnectionState: '${peerConnection.connectionState}'.split('.').last,
      candidateType: candidateType,
    );
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    return int.tryParse('$value') ?? 0;
  }

  double _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }

  void _logWhip(
    String step, {
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    final parts = <String>[
      '[WHIP]',
      'step=$step',
      ...fields.entries.map(
        (entry) => '${entry.key}=${_safeLogValue(entry.value)}',
      ),
      if (error != null) 'errorType=${error.runtimeType}',
      if (error != null) 'error=${_safeLogValue(error)}',
    ];
    debugPrint(parts.join(' '));
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _safeLogValue(Object? value) {
    return '$value'.replaceAll(RegExp(r'Bearer\s+[^\s]+'), 'Bearer ***');
  }

  String _enumName(Object? value) {
    if (value == null) {
      return 'unknown';
    }
    return '$value'.split('.').last;
  }

  String _preferH264(String sdp) {
    final lines = sdp.split('\r\n');
    final h264Payloads = <String>[];
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.startsWith('a=rtpmap:') && lower.contains('h264/')) {
        h264Payloads.add(line.substring(9).split(' ').first);
      }
    }
    if (h264Payloads.isEmpty) {
      return sdp;
    }
    return lines
        .map((line) {
          if (!line.startsWith('m=video ')) {
            return line;
          }
          final parts = line.split(' ');
          final header = parts.take(3);
          final payloads = parts.skip(3).toList();
          final ordered = [
            ...h264Payloads.where(payloads.contains),
            ...payloads.where((payload) => !h264Payloads.contains(payload)),
          ];
          return [...header, ...ordered].join(' ');
        })
        .join('\r\n');
  }

  @override
  Future<void> stop() async {
    _statsTimer?.cancel();
    _statsTimer = null;

    final sessionUri = _sessionUri;
    _sessionUri = null;
    if (sessionUri != null) {
      unawaited(
        _client
            .delete(sessionUri)
            .timeout(const Duration(seconds: 5))
            .catchError((_) {
              return http.Response('', 0);
            }),
      );
    }

    final peerConnection = _peerConnection;
    _peerConnection = null;
    if (peerConnection != null) {
      await peerConnection.close();
      await peerConnection.dispose();
    }

    if (_isPublishing) {
      _events.add(const StreamPublisherEvent(StreamPublisherEventType.stopped));
    }
    _isPublishing = false;
    _startedAt = null;
  }
}
