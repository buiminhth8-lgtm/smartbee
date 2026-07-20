import 'package:flutter_test/flutter_test.dart';
import 'package:smartbee/features/map/infrastructure/map_tile_http_client.dart';

void main() {
  group('normalizeMapProxy', () {
    test('accepts proxy host and port', () {
      expect(normalizeMapProxy('127.0.0.1:7890'), '127.0.0.1:7890');
    });

    test('removes http scheme from proxy', () {
      expect(normalizeMapProxy('http://127.0.0.1:7890'), '127.0.0.1:7890');
    });

    test('removes https scheme from proxy', () {
      expect(normalizeMapProxy('https://127.0.0.1:7890'), '127.0.0.1:7890');
    });

    test('removes trailing slash', () {
      expect(normalizeMapProxy('http://127.0.0.1:7890/'), '127.0.0.1:7890');
    });

    test('rejects proxy without port', () {
      expect(() => normalizeMapProxy('127.0.0.1'), throwsArgumentError);
    });

    test('rejects invalid proxy port', () {
      expect(() => normalizeMapProxy('127.0.0.1:70000'), throwsArgumentError);
    });

    test('rejects empty proxy host', () {
      expect(() => normalizeMapProxy(':7890'), throwsArgumentError);
    });
  });

  group('resolveMapProxyForUri', () {
    final tileUri = Uri.parse(
      'https://tile.openstreetmap.org/12/3373/1553.png',
    );

    test('uses HTTPS_PROXY for HTTPS tile URLs', () {
      expect(
        resolveMapProxyForUri(tileUri, const <String, String>{
          'HTTPS_PROXY': '127.0.0.1:7890',
        }),
        'PROXY 127.0.0.1:7890',
      );
    });

    test('falls back to direct without proxy environment', () {
      expect(
        resolveMapProxyForUri(tileUri, const <String, String>{}),
        'DIRECT',
      );
    });

    test('honors NO_PROXY', () {
      expect(
        resolveMapProxyForUri(tileUri, const <String, String>{
          'HTTPS_PROXY': '127.0.0.1:7890',
          'NO_PROXY': 'tile.openstreetmap.org',
        }),
        'DIRECT',
      );
    });
  });

  test('suppresses repeated tile errors', () {
    var currentTime = DateTime(2026);
    final messages = <String>[];
    final logger = MapTileErrorLogger(
      now: () => currentTime,
      logSink: messages.add,
    );

    logger.log(StateError('first'), tile: 'tile-1');
    logger.log(StateError('second'), tile: 'tile-2');
    logger.log(StateError('third'), tile: 'tile-3');

    expect(messages, hasLength(1));
    expect(logger.suppressedCount, 2);

    currentTime = currentTime.add(const Duration(seconds: 3));
    logger.log(StateError('fourth'), tile: 'tile-4');

    expect(messages, hasLength(2));
    expect(messages.last, contains('suppressed=2'));
    expect(logger.suppressedCount, 0);
  });
}
