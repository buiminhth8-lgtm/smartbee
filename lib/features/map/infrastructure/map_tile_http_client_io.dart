import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/io_client.dart';
import 'package:http/retry.dart';

import 'map_tile_http_client_common.dart';

class MapTileHttpClientFactory {
  const MapTileHttpClientFactory._();

  static final Uri _diagnosticTileUri = Uri.parse(
    'https://tile.openstreetmap.org/12/3373/1553.png',
  );

  static MapTileHttpClientBundle create({String? explicitProxy}) {
    final configuredProxy =
        (explicitProxy ?? const String.fromEnvironment('MAP_HTTP_PROXY'))
            .trim();

    final nativeClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12)
      ..idleTimeout = const Duration(seconds: 30)
      ..maxConnectionsPerHost = 6;

    late final String proxyDescription;

    if (configuredProxy.isNotEmpty) {
      final normalizedProxy = normalizeMapProxy(configuredProxy);
      nativeClient.findProxy = (_) => 'PROXY $normalizedProxy';
      proxyDescription = 'explicit:$normalizedProxy';
    } else {
      nativeClient.findProxy = (uri) {
        try {
          return resolveMapProxyForUri(uri, Platform.environment);
        } catch (error) {
          debugPrint(
            '[MapTile] step=environment-proxy-invalid '
            'errorType=${error.runtimeType} '
            'error=$error',
          );
          return 'DIRECT';
        }
      };
      proxyDescription = _describeEnvironmentProxy();
    }

    final ioClient = IOClient(nativeClient);
    final retryClient = RetryClient(
      ioClient,
      retries: 1,
      when: (response) =>
          response.statusCode >= 500 && response.statusCode < 600,
      whenError: (_, _) => false,
      onRetry: (request, response, retryCount) {
        debugPrint(
          '[MapTile] step=retry '
          'retryCount=$retryCount '
          'uri=${request.url} '
          'status=${response?.statusCode}',
        );
      },
    );

    // This client is intentionally scoped to map tiles only.
    // Do not reuse it for WHIP or localhost MediaMTX requests.
    final tileProvider = NetworkTileProvider(httpClient: retryClient);

    debugPrint(
      '[MapTile] step=http-client-created '
      'proxy=$proxyDescription '
      'connectionTimeoutSeconds=12 '
      'idleTimeoutSeconds=30 '
      'maxConnectionsPerHost=6 '
      'retries=1',
    );

    return MapTileHttpClientBundle(
      httpClient: retryClient,
      tileProvider: tileProvider,
      proxyDescription: proxyDescription,
    );
  }

  static String _describeEnvironmentProxy() {
    try {
      return describeMapProxyForUri(_diagnosticTileUri, Platform.environment);
    } catch (error) {
      debugPrint(
        '[MapTile] step=environment-proxy-description-failed '
        'errorType=${error.runtimeType} '
        'error=$error',
      );
      return 'direct';
    }
  }
}
