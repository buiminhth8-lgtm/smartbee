import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbee/features/map/infrastructure/map_tile_http_client.dart';

void main() {
  group('map tile source config', () {
    test('uses default OpenStreetMap tile template', () {
      final config = resolveMapTileSourceConfig();

      expect(config.urlTemplate, defaultMapTileUrlTemplate);
      expect(
        config.probeUri.toString(),
        'https://tile.openstreetmap.org/12/3373/1553.png',
      );
      expect(config.description, 'https://tile.openstreetmap.org');
    });

    test('accepts HTTP tile template for local diagnostics', () {
      final config = resolveMapTileSourceConfig(
        explicitUrlTemplate: 'http://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );

      expect(
        config.probeUri.toString(),
        'http://tile.openstreetmap.org/12/3373/1553.png',
      );
    });

    test('rejects tile template without coordinate placeholders', () {
      expect(
        () => normalizeMapTileUrlTemplate(
          'https://tile.openstreetmap.org/static.png',
        ),
        throwsArgumentError,
      );
    });

    test('rejects unsupported tile template scheme', () {
      expect(
        () => normalizeMapTileUrlTemplate('file:///tiles/{z}/{x}/{y}.png'),
        throwsArgumentError,
      );
    });
  });

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

    test('rejects socks proxy because dart io expects HTTP proxy', () {
      expect(
        () => normalizeMapProxy('socks5://127.0.0.1:7890'),
        throwsArgumentError,
      );
    });

    test('masks proxy password in description', () {
      final proxy = normalizeMapProxyConfig(
        'http://user:secret@proxy.test:8080',
      );

      expect(proxy.rule, 'PROXY user:secret@proxy.test:8080');
      expect(proxy.description, 'user:***@proxy.test:8080');
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

  test(
    'reporting client notifies network errors without swallowing them',
    () async {
      final events = <String>[];
      final inner = _ThrowingClient();
      final client = MapTileReportingClient(
        inner: inner,
        onNetworkError: (uri, error, stackTrace) {
          events.add('$uri|${error.runtimeType}');
        },
      );

      await expectLater(
        client.get(
          Uri.parse('https://tile.openstreetmap.org/12/3373/1553.png'),
        ),
        throwsStateError,
      );

      client.close();

      expect(events, hasLength(1));
      expect(events.single, contains('tile.openstreetmap.org'));
      expect(inner.closed, isTrue);
    },
  );
}

class _ThrowingClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw StateError('offline');
  }

  @override
  void close() {
    closed = true;
  }
}
