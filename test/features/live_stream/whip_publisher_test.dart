import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smartbee/features/live_stream/domain/streaming_exception.dart';
import 'package:smartbee/features/live_stream/infrastructure/publisher/whip_publisher.dart';

void main() {
  const answerSdp =
      'v=0\r\n'
      'o=- 1 1 IN IP4 127.0.0.1\r\n'
      's=-\r\n'
      't=0 0\r\n'
      'm=video 9 UDP/TLS/RTP/SAVPF 96\r\n';

  test('builds remote description with sdp first and answer second', () {
    final description = buildWhipAnswerDescription(answerSdp);

    expect(description.sdp, answerSdp.trim());
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

    expect(parsed, answerSdp.trim());
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
}
