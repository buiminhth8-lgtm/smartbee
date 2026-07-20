import 'dart:async';

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
      await peerConnection.setLocalDescription(offer);
      await _waitForIceGathering(peerConnection);

      final localDescription = await peerConnection.getLocalDescription();
      final offerSdp = localDescription?.sdp ?? offer.sdp;
      if (offerSdp == null || offerSdp.trim().isEmpty) {
        throw const StreamingException(
          StreamingErrorCode.sdpNegotiationFailed,
          '本地 SDP 创建失败，无法开始推流。',
        );
      }

      final response = await _postOffer(config, offerSdp);
      final answerSdp = response.body.trim();
      if (answerSdp.isEmpty) {
        throw const StreamingException(
          StreamingErrorCode.sdpNegotiationFailed,
          '服务器没有返回 SDP Answer。',
        );
      }

      await peerConnection.setRemoteDescription(
        RTCSessionDescription(answerSdp, 'answer'),
      );
      final location = response.headers['location'];
      if (location != null && location.isNotEmpty) {
        _sessionUri = Uri.parse(location).isAbsolute
            ? Uri.parse(location)
            : Uri.parse(_urlBuilder.build(config).whip).resolve(location);
      }

      _isPublishing = true;
      _startedAt = DateTime.now();
      _startStatisticsTimer(profile);
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
    } catch (error) {
      await stop();
      if (error is StreamingException) {
        rethrow;
      }

        print('媒体协商失败，请检查服务器 WHIP 配置和网络。'+error.toString());

      throw StreamingException(
        StreamingErrorCode.sdpNegotiationFailed,
        '媒体协商失败，请检查服务器 WHIP 配置和网络。'+error.toString(),
        cause: error,
      );
    }
  }

  Future<http.Response> _postOffer(
    StreamServerConfig config,
    String offerSdp,
  ) async {
    final uri = Uri.parse(_urlBuilder.build(config).whip);
    final headers = <String, String>{
      'content-type': 'application/sdp',
      'accept': 'application/sdp',
      if (config.hasBearerToken)
        'authorization': 'Bearer ${config.bearerToken.trim()}',
    };
    final response = await _client
        .post(uri, headers: headers, body: offerSdp)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    throw _httpError(response.statusCode);
  }

  StreamingException _httpError(int statusCode) {
    return switch (statusCode) {
      401 || 403 => const StreamingException(
        StreamingErrorCode.authenticationFailed,
        '鉴权失败，请检查 Bearer Token。',
      ),
      404 => const StreamingException(
        StreamingErrorCode.serverUnreachable,
        '推流地址不存在，请检查 MediaMTX WHIP 路径。',
      ),
      409 => const StreamingException(
        StreamingErrorCode.publishConflict,
        '同名流正在推送，请更换流名称或停止已有推流。',
      ),
      _ => StreamingException(
        StreamingErrorCode.serverUnreachable,
        '服务器返回 HTTP $statusCode，推流失败。',
      ),
    };
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

    await completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {},
    );
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
