import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

export 'map_tile_network_config.dart';

typedef MapTileNetworkErrorCallback =
    void Function(Uri uri, Object error, StackTrace stackTrace);

class MapTileHttpClientBundle {
  MapTileHttpClientBundle({
    required this.httpClient,
    required this.tileProvider,
    required this.proxyDescription,
    required this.tileUrlTemplate,
    required this.tileSourceDescription,
  });

  final http.Client httpClient;
  final TileProvider tileProvider;
  final String proxyDescription;
  final String tileUrlTemplate;
  final String tileSourceDescription;

  void close() {
    httpClient.close();
  }
}

typedef MapTileClock = DateTime Function();
typedef MapTileLogSink = void Function(String message);

class MapTileErrorLogger {
  MapTileErrorLogger({
    this.minimumInterval = const Duration(seconds: 3),
    MapTileClock? now,
    MapTileLogSink? logSink,
  }) : _now = now ?? DateTime.now,
       _logSink = logSink ?? debugPrint;

  final Duration minimumInterval;
  final MapTileClock _now;
  final MapTileLogSink _logSink;

  DateTime? _lastLoggedAt;
  int _suppressedCount = 0;

  @visibleForTesting
  int get suppressedCount => _suppressedCount;

  void log(Object error, {Object? tile}) {
    final now = _now();
    final last = _lastLoggedAt;

    if (last != null && now.difference(last) < minimumInterval) {
      _suppressedCount++;
      return;
    }

    _logSink(
      '[MapTile] step=tile-load-failed '
      'tile=$tile '
      'suppressed=$_suppressedCount '
      'errorType=${error.runtimeType} '
      'error=$error',
    );

    _lastLoggedAt = now;
    _suppressedCount = 0;
  }
}

class MapTileReportingClient extends http.BaseClient {
  MapTileReportingClient({required this.inner, this.onNetworkError});

  final http.Client inner;
  final MapTileNetworkErrorCallback? onNetworkError;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      return await inner.send(request);
    } catch (error, stackTrace) {
      onNetworkError?.call(request.url, error, stackTrace);
      rethrow;
    }
  }

  @override
  void close() {
    inner.close();
  }
}
