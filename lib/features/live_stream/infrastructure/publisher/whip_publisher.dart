import 'dart:async';
import 'dart:convert';

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

class WhipOfferRequestData {
  const WhipOfferRequestData({
    required this.uri,
    required this.headers,
    required this.bodyBytes,
    required this.offerSdp,
  });

  final Uri uri;
  final Map<String, String> headers;
  final List<int> bodyBytes;
  final String offerSdp;
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

void validateOfferSdp(String sdp) {
  if (sdp.isEmpty) {
    throw const StreamingException(
      StreamingErrorCode.invalidOfferSdp,
      'WHIP Offer SDP 为空。',
    );
  }

  if (!sdp.startsWith('v=0')) {
    throw const StreamingException(
      StreamingErrorCode.invalidOfferSdp,
      'WHIP Offer SDP 不是以 v=0 开头。',
    );
  }

  if (!sdp.contains('o=')) {
    throw const StreamingException(
      StreamingErrorCode.invalidOfferSdp,
      'WHIP Offer SDP 缺少 o= 字段。',
    );
  }

  if (!sdp.contains('s=')) {
    throw const StreamingException(
      StreamingErrorCode.invalidOfferSdp,
      'WHIP Offer SDP 缺少 s= 字段。',
    );
  }

  if (!sdp.contains('t=')) {
    throw const StreamingException(
      StreamingErrorCode.invalidOfferSdp,
      'WHIP Offer SDP 缺少 t= 字段。',
    );
  }

  if (!sdp.contains('m=video')) {
    throw const StreamingException(
      StreamingErrorCode.invalidOfferSdp,
      'WHIP Offer SDP 缺少 m=video 媒体描述。',
    );
  }

  final byteLength = utf8.encode(sdp).length;
  if (byteLength < 100) {
    throw StreamingException(
      StreamingErrorCode.invalidOfferSdp,
      'WHIP Offer SDP 长度异常：$byteLength bytes。',
    );
  }
}

String validateWhipOfferDescription(RTCSessionDescription? description) {
  final type = description?.type;
  final sdp = description?.sdp;
  if (type?.toLowerCase() != 'offer' || sdp == null || sdp.isEmpty) {
    throw const StreamingException(
      StreamingErrorCode.invalidOfferSdp,
      '本地 Offer SDP 无效，无法开始 WHIP 推流。',
    );
  }
  validateOfferSdp(sdp);
  return sdp;
}

List<int> buildWhipOfferBody(String localOfferSdp) {
  validateOfferSdp(localOfferSdp);
  return utf8.encode(localOfferSdp);
}

WhipOfferRequestData buildWhipOfferRequest({
  required Uri uri,
  required String offerSdp,
  String? bearerToken,
}) {
  final bodyBytes = buildWhipOfferBody(offerSdp);
  final token = bearerToken?.trim() ?? '';
  return WhipOfferRequestData(
    uri: uri,
    offerSdp: offerSdp,
    headers: <String, String>{
      'Content-Type': 'application/sdp',
      'Accept': 'application/sdp',
      'Content-Length': bodyBytes.length.toString(),
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    },
    bodyBytes: bodyBytes,
  );
}

Future<http.Response> postWhipOffer({
  required http.Client httpClient,
  required Uri whipUri,
  required String offerSdp,
  String? bearerToken,
}) async {
  final request = buildWhipOfferRequest(
    uri: whipUri,
    offerSdp: offerSdp,
    bearerToken: bearerToken,
  );

  debugPrint(
    '[WHIP] step=request-start '
    'method=POST '
    'uri=$whipUri '
    'contentType=${request.headers['Content-Type']} '
    'contentLength=${request.bodyBytes.length} '
    'sdpLength=${request.offerSdp.length} '
    'startsWithV0=${request.offerSdp.startsWith('v=0')} '
    'containsVideo=${request.offerSdp.contains('m=video')}',
  );

  final response = await httpClient.post(
    whipUri,
    headers: request.headers,
    body: request.bodyBytes,
  );

  debugPrint(
    '[WHIP] step=response-received '
    'status=${response.statusCode} '
    'contentType=${response.headers['content-type']} '
    'location=${response.headers['location']} '
    'bodyLength=${response.bodyBytes.length}',
  );

  if (response.statusCode != 200 && response.statusCode != 201) {
    debugPrint(
      '[WHIP] step=request-rejected '
      'status=${response.statusCode} '
      'body=${safeBodyPreview(response.body)}',
    );
  }

  return response;
}

void logOfferSummary(String sdp) {
  final lines = sdp.split(RegExp(r'\r?\n'));
  final mediaLines = lines.where((line) => line.startsWith('m=')).toList();
  final directions = lines
      .where(
        (line) =>
            line == 'a=sendonly' ||
            line == 'a=sendrecv' ||
            line == 'a=recvonly' ||
            line == 'a=inactive',
      )
      .toList();
  final candidates = lines
      .where((line) => line.startsWith('a=candidate:'))
      .length;
  final codecs = lines
      .where((line) => line.startsWith('a=rtpmap:'))
      .take(20)
      .toList();

  debugPrint(
    '[WHIP] step=offer-summary '
    'charLength=${sdp.length} '
    'byteLength=${utf8.encode(sdp).length} '
    'lineCount=${lines.length} '
    'mediaLines=$mediaLines '
    'directions=$directions '
    'candidateCount=$candidates',
  );
  for (final codec in codecs) {
    debugPrint('[WHIP] offer-codec=$codec');
  }
}

class SdpTextFormat {
  const SdpTextFormat({
    required this.length,
    required this.actualCrLfCount,
    required this.actualLfCount,
    required this.literalCrLfCount,
    required this.literalLfCount,
    required this.nullCharCount,
    required this.startsWithQuote,
    required this.endsWithQuote,
    required this.endsWithCrLf,
  });

  final int length;
  final int actualCrLfCount;
  final int actualLfCount;
  final int literalCrLfCount;
  final int literalLfCount;
  final int nullCharCount;
  final bool startsWithQuote;
  final bool endsWithQuote;
  final bool endsWithCrLf;
}

SdpTextFormat inspectSdpTextFormat(String sdp) {
  return SdpTextFormat(
    length: sdp.length,
    actualCrLfCount: RegExp('\r\n').allMatches(sdp).length,
    actualLfCount: RegExp('\n').allMatches(sdp).length,
    literalCrLfCount: RegExp(r'\\r\\n').allMatches(sdp).length,
    literalLfCount: RegExp(r'\\n').allMatches(sdp).length,
    nullCharCount: sdp.codeUnits.where((value) => value == 0).length,
    startsWithQuote: sdp.startsWith('"'),
    endsWithQuote: sdp.endsWith('"'),
    endsWithCrLf: sdp.endsWith('\r\n'),
  );
}

void logSdpTextFormat(String label, String sdp) {
  final format = inspectSdpTextFormat(sdp);
  debugPrint(
    '[WHIP] step=sdp-text-format '
    'label=$label '
    'length=${format.length} '
    'actualCrLfCount=${format.actualCrLfCount} '
    'actualLfCount=${format.actualLfCount} '
    'literalCrLfCount=${format.literalCrLfCount} '
    'literalLfCount=${format.literalLfCount} '
    'nullCharCount=${format.nullCharCount} '
    'startsWithQuote=${format.startsWithQuote} '
    'endsWithQuote=${format.endsWithQuote} '
    'endsWithCrLf=${format.endsWithCrLf}',
  );
}

class SdpStructureSummary {
  const SdpStructureSummary({
    required this.mediaLines,
    required this.mids,
    required this.bundleLines,
    required this.directions,
    required this.rtpMaps,
  });

  final List<String> mediaLines;
  final List<String> mids;
  final List<String> bundleLines;
  final List<String> directions;
  final List<String> rtpMaps;
}

SdpStructureSummary summarizeSdp(String sdp) {
  final lines = sdp.split(RegExp(r'\r?\n'));

  return SdpStructureSummary(
    mediaLines: lines.where((line) => line.startsWith('m=')).toList(),
    mids: lines.where((line) => line.startsWith('a=mid:')).toList(),
    bundleLines: lines
        .where((line) => line.startsWith('a=group:BUNDLE'))
        .toList(),
    directions: lines
        .where(
          (line) =>
              line == 'a=sendonly' ||
              line == 'a=sendrecv' ||
              line == 'a=recvonly' ||
              line == 'a=inactive',
        )
        .toList(),
    rtpMaps: lines.where((line) => line.startsWith('a=rtpmap:')).toList(),
  );
}

void logSdpStructure(String label, String sdp) {
  final summary = summarizeSdp(sdp);

  debugPrint(
    '[WHIP] step=sdp-structure '
    'label=$label '
    'length=${sdp.length} '
    'mediaLines=${summary.mediaLines} '
    'mids=${summary.mids} '
    'bundleLines=${summary.bundleLines} '
    'directions=${summary.directions}',
  );

  for (final codec in summary.rtpMaps.take(20)) {
    debugPrint('[WHIP] step=sdp-codec label=$label codec=$codec');
  }
}

int simpleSdpFingerprint(String value) {
  var hash = 17;
  for (final unit in value.codeUnits) {
    hash = 37 * hash + unit;
    hash &= 0x7fffffff;
  }
  return hash;
}

String mapWhipHttpError(int statusCode, String responseBody) {
  final body = responseBody.trim();
  if (statusCode == 400 && body.contains('"error":"EOF"')) {
    return 'MediaMTX 未读取到完整的 WHIP Offer SDP。'
        '请检查客户端请求体是否为空、是否被提前消费，'
        '或是否错误使用流式请求。';
  }

  return 'WHIP 请求失败：HTTP $statusCode，${safeBodyPreview(body)}';
}

String decodeWhipAnswer(List<int> bodyBytes) {
  late final String answerSdp;
  try {
    answerSdp = utf8.decode(bodyBytes, allowMalformed: false);
  } on FormatException catch (error) {
    throw StreamingException(
      StreamingErrorCode.invalidAnswerSdp,
      'MediaMTX 返回的 SDP Answer 不是有效 UTF-8：$error',
      cause: error,
    );
  }

  if (answerSdp.startsWith('\uFEFF')) {
    return answerSdp.substring(1);
  }
  return answerSdp;
}

String validateWhipAnswerResponse(http.Response response) {
  final contentType = response.headers['content-type']?.toLowerCase();
  final responseText = utf8.decode(response.bodyBytes, allowMalformed: true);

  if (response.statusCode != 201 && response.statusCode != 200) {
    throw StreamingException(
      _httpErrorCode(response.statusCode),
      mapWhipHttpError(response.statusCode, responseText),
    );
  }

  if (contentType == null || !contentType.startsWith('application/sdp')) {
    throw StreamingException(
      StreamingErrorCode.invalidAnswerSdp,
      'WHIP 返回的不是 application/sdp，请检查请求地址是否为 /流名称/whip。'
      '实际 Content-Type：${contentType ?? '<missing>'}，'
      '响应：${safeBodyPreview(responseText)}',
    );
  }

  final answerSdp = decodeWhipAnswer(response.bodyBytes);
  _validateAnswerSdp(answerSdp);
  return answerSdp;
}

RTCSessionDescription buildWhipAnswerDescription(String answerSdp) {
  final sdp = answerSdp.startsWith('\uFEFF')
      ? answerSdp.substring(1)
      : answerSdp;
  _validateAnswerSdp(sdp);
  return RTCSessionDescription(sdp, 'answer');
}

StreamingErrorCode _httpErrorCode(int statusCode) {
  return switch (statusCode) {
    401 || 403 => StreamingErrorCode.authenticationFailed,
    409 => StreamingErrorCode.publishConflict,
    _ => StreamingErrorCode.whipHttpFailed,
  };
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

class RemoteDescriptionReadiness {
  const RemoteDescriptionReadiness({
    required this.peerConnectionMatches,
    required this.remoteDescriptionApplied,
    required this.signalingStateIsHaveLocalOffer,
    required this.hasLocalDescription,
    required this.localTypeIsOffer,
    required this.hasLocalSdp,
  });

  final bool peerConnectionMatches;
  final bool remoteDescriptionApplied;
  final bool signalingStateIsHaveLocalOffer;
  final bool hasLocalDescription;
  final bool localTypeIsOffer;
  final bool hasLocalSdp;
}

void validateRemoteDescriptionReadiness(RemoteDescriptionReadiness readiness) {
  if (!readiness.peerConnectionMatches) {
    throw const StreamingException(
      StreamingErrorCode.invalidPeerConnectionState,
      'WHIP 协商过程中 PeerConnection 实例发生变化。',
    );
  }

  if (readiness.remoteDescriptionApplied) {
    throw const StreamingException(
      StreamingErrorCode.invalidPeerConnectionState,
      '当前 PeerConnection 已经成功设置过远端 Answer。',
    );
  }

  if (!readiness.hasLocalDescription) {
    throw const StreamingException(
      StreamingErrorCode.invalidOfferSdp,
      '设置远端 Answer 前 LocalDescription 不存在。',
    );
  }

  if (!readiness.localTypeIsOffer) {
    throw const StreamingException(
      StreamingErrorCode.invalidOfferSdp,
      '设置远端 Answer 前 LocalDescription 类型不是 offer。',
    );
  }

  if (!readiness.hasLocalSdp) {
    throw const StreamingException(
      StreamingErrorCode.invalidOfferSdp,
      '设置远端 Answer 前 Local Offer SDP 为空。',
    );
  }

  if (!readiness.signalingStateIsHaveLocalOffer) {
    throw const StreamingException(
      StreamingErrorCode.invalidPeerConnectionState,
      '设置远端 Answer 前 SignalingState 不是 have-local-offer。',
    );
  }
}

class WhipNegotiationGuard {
  bool _isStarting = false;
  bool _isPublishing = false;
  bool _remoteDescriptionApplied = false;
  int _generation = 0;

  bool get isStarting => _isStarting;
  bool get isPublishing => _isPublishing;
  bool get remoteDescriptionApplied => _remoteDescriptionApplied;
  int get generation => _generation;

  int begin() {
    if (_isStarting) {
      throw const StreamingException(
        StreamingErrorCode.alreadyStarting,
        'WHIP 推流正在启动。',
      );
    }
    if (_isPublishing) {
      throw const StreamingException(
        StreamingErrorCode.alreadyPublishing,
        'WHIP 推流已经启动。',
      );
    }

    _isStarting = true;
    _remoteDescriptionApplied = false;
    return ++_generation;
  }

  void ensureCurrent(int generation) {
    if (generation != _generation) {
      throw const StreamingException(
        StreamingErrorCode.operationCancelled,
        '本次 WHIP 协商已失效。',
      );
    }
  }

  void ensureRemoteDescriptionCanBeApplied(int generation) {
    ensureCurrent(generation);
    if (_remoteDescriptionApplied) {
      throw const StreamingException(
        StreamingErrorCode.invalidPeerConnectionState,
        '当前连接已经应用过远端 Answer。',
      );
    }
  }

  void markRemoteDescriptionApplied(int generation) {
    ensureRemoteDescriptionCanBeApplied(generation);
    _remoteDescriptionApplied = true;
  }

  void markPublishing(int generation) {
    ensureCurrent(generation);
    _isPublishing = true;
  }

  void finishStarting(int generation) {
    if (generation == _generation) {
      _isStarting = false;
    }
  }

  void reset() {
    _generation++;
    _isStarting = false;
    _isPublishing = false;
    _remoteDescriptionApplied = false;
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
  final WhipNegotiationGuard _negotiation = WhipNegotiationGuard();

  RTCPeerConnection? _peerConnection;
  Uri? _sessionUri;
  Timer? _statsTimer;
  DateTime? _startedAt;
  int _previousVideoBytes = 0;
  int _previousAudioBytes = 0;
  DateTime? _previousStatsAt;

  @override
  Stream<StreamPublisherEvent> get events => _events.stream;

  @override
  Stream<StreamStatistics> get statistics => _statistics.stream;

  @override
  bool get isPublishing => _negotiation.isPublishing;

  @override
  Future<void> start({
    required MediaStream stream,
    required StreamServerConfig config,
    required StreamProfile profile,
  }) async {
    final generation = _negotiation.begin();

    _events.add(
      const StreamPublisherEvent(StreamPublisherEventType.connecting),
    );
    try {
      final peerConnection = await createPeerConnection({
        'sdpSemantics': 'unified-plan',
        'iceServers': const <Map<String, Object>>[],
      });
      final peerConnectionId = identityHashCode(peerConnection);
      _peerConnection = peerConnection;
      _wirePeerConnectionEvents(peerConnection);
      _logWhip('peer-created', fields: {'pcId': peerConnectionId});

      for (final track in stream.getTracks()) {
        final sender = await peerConnection.addTrack(track, stream);
        _logWhip(
          'add-track',
          fields: {
            'pcId': peerConnectionId,
            'kind': track.kind,
            'trackId': track.id,
            'enabled': track.enabled,
          },
        );
        if (track.kind == 'video') {
          await _configureVideoSender(sender, profile);
        }
      }

      final offer = await peerConnection.createOffer({
        'offerToReceiveAudio': false,
        'offerToReceiveVideo': false,
      });
      _logWhip(
        'offer-created',
        fields: {
          'pcId': peerConnectionId,
          'type': offer.type,
          'sdpLength': offer.sdp?.length ?? 0,
        },
      );
      await peerConnection.setLocalDescription(offer);
      _logWhip('local-description-set', fields: {'pcId': peerConnectionId});
      await _waitForIceGathering(peerConnection);
      _logWhip(
        'ice-gathering-complete',
        fields: {
          'pcId': peerConnectionId,
          'state': _enumName(peerConnection.iceGatheringState),
        },
      );

      final localDescription = await peerConnection.getLocalDescription();
      final offerSdp = validateWhipOfferDescription(localDescription);
      final localSdpFingerprint = simpleSdpFingerprint(localDescription!.sdp!);
      final sentSdpFingerprint = simpleSdpFingerprint(offerSdp);
      _logWhip(
        'local-description-ready',
        fields: {
          'pcId': peerConnectionId,
          'type': localDescription.type,
          'sdpLength': offerSdp.length,
        },
      );
      _logWhip(
        'offer-fingerprint',
        fields: {
          'pcId': peerConnectionId,
          'local': localSdpFingerprint,
          'sent': sentSdpFingerprint,
          'matches': localSdpFingerprint == sentSdpFingerprint,
        },
      );
      logOfferSummary(offerSdp);
      logSdpTextFormat('local-offer', offerSdp);
      logSdpStructure('local-offer', offerSdp);

      final whipUri = Uri.parse(_urlBuilder.build(config).whip);
      _negotiation.ensureCurrent(generation);
      _logWhip(
        'whip-request',
        fields: {
          'pcId': peerConnectionId,
          'uri': whipUri,
          'offerFingerprint': sentSdpFingerprint,
        },
      );
      final response = await _postOffer(whipUri, config, offerSdp);
      _logWhip(
        'response-received',
        fields: {
          'pcId': peerConnectionId,
          'status': response.statusCode,
          'contentType': response.headers['content-type'],
          'location': response.headers['location'],
          'bodyLength': response.bodyBytes.length,
        },
      );
      _saveWhipSessionUri(whipUri, response);

      _negotiation.ensureCurrent(generation);
      final answerSdp = validateWhipAnswerResponse(response);
      _logWhip(
        'answer-validation',
        fields: {
          'pcId': peerConnectionId,
          'startsWithV0': answerSdp.startsWith('v=0'),
          'containsVideo': answerSdp.contains('m=video'),
          'answerLength': answerSdp.length,
          'preview': safeBodyPreview(answerSdp),
        },
      );
      logSdpTextFormat('remote-answer', answerSdp);
      logSdpStructure('remote-answer', answerSdp);

      final remoteDescription = buildWhipAnswerDescription(answerSdp);
      await _verifyReadyForRemoteDescription(peerConnection, peerConnectionId);
      _negotiation.ensureRemoteDescriptionCanBeApplied(generation);
      _logWhip(
        'setRemoteDescription-start',
        fields: {
          'pcId': peerConnectionId,
          'type': remoteDescription.type,
          'sdpLength': remoteDescription.sdp?.length ?? 0,
          'startsWithV0': answerSdp.startsWith('v=0'),
        },
      );
      try {
        await peerConnection.setRemoteDescription(remoteDescription);
      } catch (error, stackTrace) {
        final signalingState = await peerConnection.getSignalingState();
        final currentLocalDescription = await peerConnection
            .getLocalDescription();
        _logWhip(
          'setRemoteDescription-failed',
          error: error,
          stackTrace: stackTrace,
          fields: {
            'pcId': peerConnectionId,
            'signalingState': _enumName(signalingState),
            'localType': currentLocalDescription?.type,
            'localSdpLength': currentLocalDescription?.sdp?.length ?? 0,
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
      _negotiation.markRemoteDescriptionApplied(generation);
      _logWhip(
        'setRemoteDescription-success',
        fields: {
          'pcId': peerConnectionId,
          'remoteDescriptionApplied': _negotiation.remoteDescriptionApplied,
        },
      );

      _negotiation.ensureCurrent(generation);
      await _waitForIceConnected(peerConnection);
      _wirePeerConnectionEvents(peerConnection);
      _logWhip(
        'ice-connected',
        fields: {
          'pcId': peerConnectionId,
          'state': _enumName(peerConnection.iceConnectionState),
        },
      );
      _negotiation.markPublishing(generation);
      _startedAt = DateTime.now();
      _startStatisticsTimer(profile);
      _logWhip('publishing', fields: {'pcId': peerConnectionId});
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
    } finally {
      _negotiation.finishStarting(generation);
    }
  }

  Future<http.Response> _postOffer(
    Uri uri,
    StreamServerConfig config,
    String offerSdp,
  ) async {
    return postWhipOffer(
      httpClient: _client,
      whipUri: uri,
      offerSdp: offerSdp,
      bearerToken: config.bearerToken,
    ).timeout(const Duration(seconds: 12));
  }

  void _saveWhipSessionUri(Uri whipUri, http.Response response) {
    final location = response.headers['location'];
    if (location == null || location.trim().isEmpty) {
      return;
    }
    _sessionUri = whipUri.resolve(location.trim());
  }

  Future<void> _verifyReadyForRemoteDescription(
    RTCPeerConnection peerConnection,
    int peerConnectionId,
  ) async {
    final actualPeerConnectionId = identityHashCode(peerConnection);
    final signalingState = await peerConnection.getSignalingState();
    final currentLocalDescription = await peerConnection.getLocalDescription();
    final localSdp = currentLocalDescription?.sdp;

    _logWhip(
      'verify-before-remote',
      fields: {
        'pcId': actualPeerConnectionId,
        'expectedPcId': peerConnectionId,
        'signalingState': _enumName(signalingState),
        'localType': currentLocalDescription?.type,
        'localSdpLength': localSdp?.length ?? 0,
        'remoteDescriptionApplied': _negotiation.remoteDescriptionApplied,
      },
    );

    validateRemoteDescriptionReadiness(
      RemoteDescriptionReadiness(
        peerConnectionMatches: actualPeerConnectionId == peerConnectionId,
        remoteDescriptionApplied: _negotiation.remoteDescriptionApplied,
        signalingStateIsHaveLocalOffer:
            signalingState == RTCSignalingState.RTCSignalingStateHaveLocalOffer,
        hasLocalDescription: currentLocalDescription != null,
        localTypeIsOffer:
            currentLocalDescription?.type?.toLowerCase() == 'offer',
        hasLocalSdp: localSdp != null && localSdp.isNotEmpty,
      ),
    );
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
    final peerConnectionId = identityHashCode(peerConnection);
    peerConnection.onSignalingState = (state) {
      _logWhip(
        'signaling-state',
        fields: {'pcId': peerConnectionId, 'state': _enumName(state)},
      );
    };
    peerConnection.onConnectionState = (state) {
      _logWhip(
        'peer-connection-state',
        fields: {'pcId': peerConnectionId, 'state': _enumName(state)},
      );
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
      _logWhip(
        'ice-connection-state',
        fields: {'pcId': peerConnectionId, 'state': _enumName(state)},
      );
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

  @override
  Future<void> stop() async {
    final wasPublishing = _negotiation.isPublishing;
    _negotiation.reset();

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

    if (wasPublishing) {
      _events.add(const StreamPublisherEvent(StreamPublisherEventType.stopped));
    }
    _startedAt = null;
  }
}
