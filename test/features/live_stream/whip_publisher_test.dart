import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartbee/features/live_stream/domain/streaming_exception.dart';
import 'package:smartbee/features/live_stream/infrastructure/publisher/whip_publisher.dart';

void main() {
  final whipUri = Uri.parse('http://127.0.0.1:8889/smartbee/whip');
  const answerSdp =
      'v=0\r\n'
      'o=- 1 1 IN IP4 127.0.0.1\r\n'
      's=-\r\n'
      't=0 0\r\n'
      'm=video 9 UDP/TLS/RTP/SAVPF 96\r\n';
  const offerSdp =
      'v=0\r\n'
      'o=- 1 1 IN IP4 127.0.0.1\r\n'
      's=-\r\n'
      't=0 0\r\n'
      'a=group:BUNDLE 0\r\n'
      'm=video 9 UDP/TLS/RTP/SAVPF 96\r\n'
      'c=IN IP4 0.0.0.0\r\n'
      'a=mid:0\r\n'
      'a=sendonly\r\n'
      'a=rtpmap:96 VP8/90000\r\n'
      'a=rtcp-mux\r\n';

  test('builds remote description with sdp first and answer second', () {
    final description = buildWhipAnswerDescription(answerSdp);

    expect(description.sdp, answerSdp);
    expect(description.type, 'answer');
    expect(description.sdp, startsWith('v=0'));
  });

  test('rejects empty WHIP answer SDP', () {
    expect(
      () => buildWhipAnswerDescription(''),
      throwsA(
        isA<StreamingException>().having(
          (error) => error.code,
          'code',
          StreamingErrorCode.invalidAnswerSdp,
        ),
      ),
    );
  });

  test('rejects HTML returned instead of SDP', () {
    expect(
      () => buildWhipAnswerDescription('<html>404 Not Found</html>'),
      throwsA(
        isA<StreamingException>().having(
          (error) => error.code,
          'code',
          StreamingErrorCode.invalidAnswerSdp,
        ),
      ),
    );
  });

  test('removes UTF-8 BOM from WHIP answer', () {
    final description = buildWhipAnswerDescription('\uFEFF$answerSdp');

    expect(description.sdp, startsWith('v=0'));
    expect(description.type, 'answer');
  });

  test('accepts application/sdp WHIP response', () {
    final response = http.Response(
      answerSdp,
      201,
      headers: const {'content-type': 'application/sdp'},
    );

    final parsed = validateWhipAnswerResponse(response);

    expect(parsed, answerSdp);
  });

  test('rejects non-SDP WHIP response content type', () {
    final response = http.Response(
      '<html>404 Not Found</html>',
      200,
      headers: const {'content-type': 'text/html'},
    );

    expect(
      () => validateWhipAnswerResponse(response),
      throwsA(
        isA<StreamingException>().having(
          (error) => error.code,
          'code',
          StreamingErrorCode.invalidAnswerSdp,
        ),
      ),
    );
  });

  test('rejects WHIP HTTP failure with body preview', () {
    final response = http.Response(
      'not found',
      404,
      headers: const {'content-type': 'text/plain'},
    );

    expect(
      () => validateWhipAnswerResponse(response),
      throwsA(
        isA<StreamingException>()
            .having(
              (error) => error.code,
              'code',
              StreamingErrorCode.whipHttpFailed,
            )
            .having((error) => error.message, 'message', contains('HTTP 404')),
      ),
    );
  });

  test('maps MediaMTX EOF to request body diagnostic', () {
    expect(
      mapWhipHttpError(400, '{"status":"error","error":"EOF"}'),
      contains('未读取到完整的 WHIP Offer SDP'),
    );
  });

  test('WHIP request body contains offer SDP', () {
    final request = buildWhipOfferRequest(uri: whipUri, offerSdp: offerSdp);
    final decoded = utf8.decode(request.bodyBytes);

    expect(request.bodyBytes, isNotEmpty);
    expect(decoded, offerSdp);
  });

  test('WHIP request sends exact local offer SDP', () {
    const localOffer =
        'v=0\r\n'
        'o=- 1 1 IN IP4 127.0.0.1\r\n'
        's=-\r\n'
        't=0 0\r\n'
        'a=group:BUNDLE 0\r\n'
        'm=video 9 UDP/TLS/RTP/SAVPF 96\r\n'
        'a=mid:0\r\n'
        'a=sendonly\r\n'
        'a=rtpmap:96 VP8/90000\r\n';

    final body = buildWhipOfferBody(localOffer);

    expect(utf8.decode(body), localOffer);
  });

  test('WHIP request content type is application/sdp', () {
    final request = buildWhipOfferRequest(uri: whipUri, offerSdp: offerSdp);

    expect(request.headers['Content-Type'], 'application/sdp');
    expect(request.headers['Accept'], 'application/sdp');
  });

  test('WHIP request content length matches body bytes', () {
    final request = buildWhipOfferRequest(uri: whipUri, offerSdp: offerSdp);

    expect(
      request.headers['Content-Length'],
      request.bodyBytes.length.toString(),
    );
  });

  test('WHIP request rejects empty SDP', () {
    expect(
      () => buildWhipOfferRequest(uri: whipUri, offerSdp: ''),
      throwsA(isA<StreamingException>()),
    );
  });

  test('WHIP request rejects whitespace-only SDP', () {
    expect(
      () => buildWhipOfferRequest(uri: whipUri, offerSdp: '   \r\n'),
      throwsA(isA<StreamingException>()),
    );
  });

  test('WHIP request does not JSON wrap SDP', () {
    final request = buildWhipOfferRequest(uri: whipUri, offerSdp: offerSdp);
    final decoded = utf8.decode(request.bodyBytes);

    expect(decoded, startsWith('v=0'));
    expect(decoded, isNot(startsWith('"')));
    expect(decoded, isNot(contains('"sdp"')));
  });

  test('WHIP request preserves local SDP line endings', () {
    final lfOffer = offerSdp.replaceAll('\r\n', '\n');
    final request = buildWhipOfferRequest(uri: whipUri, offerSdp: lfOffer);
    final decoded = utf8.decode(request.bodyBytes);

    expect(decoded, lfOffer);
  });

  test('WHIP answer preserves original SDP text', () {
    const answer =
        'v=0\r\n'
        'o=- 2 2 IN IP4 127.0.0.1\r\n'
        's=-\r\n'
        't=0 0\r\n'
        'a=group:BUNDLE 0\r\n'
        'm=video 9 UDP/TLS/RTP/SAVPF 96\r\n'
        'a=mid:0\r\n'
        'a=recvonly\r\n'
        'a=rtpmap:96 VP8/90000\r\n';

    final decoded = decodeWhipAnswer(utf8.encode(answer));

    expect(decoded, answer);
  });

  test('WHIP answer removes BOM only', () {
    const answer =
        '\uFEFFv=0\r\n'
        'o=- 2 2 IN IP4 127.0.0.1\r\n'
        's=-\r\n'
        't=0 0\r\n';

    final decoded = decodeWhipAnswer(utf8.encode(answer));

    expect(decoded.startsWith('v=0'), isTrue);
    expect(decoded.endsWith('\r\n'), isTrue);
  });

  test('detects escaped literal CRLF', () {
    const invalid = r'v=0\r\no=- 1 1 IN IP4 127.0.0.1\r\n';

    final format = inspectSdpTextFormat(invalid);

    expect(format.literalCrLfCount, greaterThan(0));
    expect(format.actualLfCount, 0);
  });

  test('summarizes SDP media sections', () {
    const sdp =
        'v=0\r\n'
        'a=group:BUNDLE 0\r\n'
        'm=video 9 UDP/TLS/RTP/SAVPF 96\r\n'
        'a=mid:0\r\n'
        'a=sendonly\r\n'
        'a=rtpmap:96 VP8/90000\r\n';

    final summary = summarizeSdp(sdp);

    expect(summary.mediaLines, hasLength(1));
    expect(summary.mids, contains('a=mid:0'));
    expect(summary.bundleLines, contains('a=group:BUNDLE 0'));
  });

  test('sent offer fingerprint matches local description', () {
    const offer =
        'v=0\r\n'
        'o=- 1 1 IN IP4 127.0.0.1\r\n';

    expect(simpleSdpFingerprint(offer), simpleSdpFingerprint(offer));
  });

  test('WHIP negotiation guard rejects duplicate start', () {
    final guard = WhipNegotiationGuard();

    final generation = guard.begin();

    expect(
      guard.begin,
      throwsA(
        isA<StreamingException>().having(
          (error) => error.code,
          'code',
          StreamingErrorCode.alreadyStarting,
        ),
      ),
    );
    expect(guard.isStarting, isTrue);
    expect(guard.isPublishing, isFalse);

    guard.finishStarting(generation);
    guard.markPublishing(generation);

    expect(
      guard.begin,
      throwsA(
        isA<StreamingException>().having(
          (error) => error.code,
          'code',
          StreamingErrorCode.alreadyPublishing,
        ),
      ),
    );
  });

  test('posts complete SDP bytes to WHIP endpoint', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      expect(_header(request.headers, 'content-type'), 'application/sdp');
      expect(request.bodyBytes, isNotEmpty);
      expect(utf8.decode(request.bodyBytes), startsWith('v=0'));
      expect(utf8.decode(request.bodyBytes), contains('\r\nm=video'));
      return http.Response(
        answerSdp,
        201,
        headers: const {
          'content-type': 'application/sdp',
          'location': '/smartbee/whip/session',
        },
      );
    });

    await postWhipOffer(
      httpClient: client,
      whipUri: whipUri,
      offerSdp: offerSdp,
    );

    expect(capturedRequest.bodyBytes, isNotEmpty);
    expect(
      _header(capturedRequest.headers, 'content-length'),
      capturedRequest.bodyBytes.length.toString(),
    );
  });
}

String? _header(Map<String, String> headers, String name) {
  final lowerName = name.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == lowerName) {
      return entry.value;
    }
  }
  return null;
}
