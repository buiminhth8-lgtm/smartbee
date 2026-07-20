import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

class MapTileHttpClientBundle {
  MapTileHttpClientBundle({
    required this.httpClient,
    required this.tileProvider,
    required this.proxyDescription,
  });

  final http.Client httpClient;
  final TileProvider tileProvider;
  final String proxyDescription;

  void close() {
    httpClient.close();
  }
}

String normalizeMapProxy(String value) {
  var result = value.trim();

  if (result.startsWith('http://')) {
    result = result.substring('http://'.length);
  }

  if (result.startsWith('https://')) {
    result = result.substring('https://'.length);
  }

  if (result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }

  final uri = Uri.tryParse('http://$result');

  if (uri == null ||
      uri.host.isEmpty ||
      !uri.hasPort ||
      uri.port < 1 ||
      uri.port > 65535) {
    throw ArgumentError.value(
      value,
      'MAP_HTTP_PROXY',
      '代理格式应为 host:port，例如 127.0.0.1:7890。',
    );
  }

  return '${uri.host}:${uri.port}';
}

String resolveMapProxyForUri(Uri uri, Map<String, String> environment) {
  if (_matchesNoProxy(uri.host, environment)) {
    return 'DIRECT';
  }

  final proxyValue = _proxyValueForScheme(uri.scheme, environment);
  if (proxyValue == null || proxyValue.trim().isEmpty) {
    return 'DIRECT';
  }

  return 'PROXY ${normalizeMapProxy(proxyValue)}';
}

String describeMapProxyForUri(Uri uri, Map<String, String> environment) {
  final resolved = resolveMapProxyForUri(uri, environment);
  if (resolved == 'DIRECT') {
    return 'direct';
  }

  return 'environment:${resolved.substring('PROXY '.length)}';
}

String? _proxyValueForScheme(String scheme, Map<String, String> environment) {
  final upperScheme = scheme.toUpperCase();
  if (upperScheme == 'HTTPS') {
    return environment['HTTPS_PROXY'] ??
        environment['https_proxy'] ??
        environment['HTTP_PROXY'] ??
        environment['http_proxy'];
  }

  return environment['HTTP_PROXY'] ??
      environment['http_proxy'] ??
      environment['HTTPS_PROXY'] ??
      environment['https_proxy'];
}

bool _matchesNoProxy(String host, Map<String, String> environment) {
  final noProxy = environment['NO_PROXY'] ?? environment['no_proxy'];
  if (noProxy == null || noProxy.trim().isEmpty) {
    return false;
  }

  final normalizedHost = _stripHostPort(host).toLowerCase();
  for (final rawEntry in noProxy.split(',')) {
    var entry = _stripHostPort(rawEntry.trim()).toLowerCase();
    if (entry.isEmpty) {
      continue;
    }
    if (entry == '*') {
      return true;
    }
    if (entry.startsWith('.')) {
      entry = entry.substring(1);
      if (normalizedHost == entry || normalizedHost.endsWith('.$entry')) {
        return true;
      }
      continue;
    }
    if (normalizedHost == entry || normalizedHost.endsWith('.$entry')) {
      return true;
    }
  }

  return false;
}

String _stripHostPort(String value) {
  var result = value.trim();
  if (result.startsWith('[') && result.contains(']')) {
    return result.substring(1, result.indexOf(']'));
  }

  final colonCount = ':'.allMatches(result).length;
  if (colonCount == 1) {
    result = result.substring(0, result.indexOf(':'));
  }
  return result;
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
