import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/io_client.dart';
import 'package:http/retry.dart';

import 'map_tile_http_client_common.dart';

class MapTileHttpClientFactory {
  const MapTileHttpClientFactory._();

  static MapTileHttpClientBundle create({
    String? explicitProxy,
    String? explicitTileUrlTemplate,
    MapTileNetworkErrorCallback? onNetworkError,
  }) {
    final tileSource = resolveMapTileSourceConfig(
      explicitUrlTemplate: explicitTileUrlTemplate,
    );
    final configuredProxy =
        (explicitProxy ?? const String.fromEnvironment('MAP_HTTP_PROXY'))
            .trim();

    final nativeClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12)
      ..idleTimeout = const Duration(seconds: 30)
      ..maxConnectionsPerHost = 6;

    late final String proxyDescription;

    if (configuredProxy.isNotEmpty) {
      final normalizedProxy = normalizeMapProxyConfig(configuredProxy);
      nativeClient.findProxy = (_) => normalizedProxy.rule;
      proxyDescription = 'explicit:${normalizedProxy.description}';
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
      proxyDescription = _describeEnvironmentProxy(tileSource.probeUri);
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
    final reportingClient = MapTileReportingClient(
      inner: retryClient,
      onNetworkError: onNetworkError,
    );

    // This client is intentionally scoped to map tiles only.
    // Do not reuse it for WHIP or localhost MediaMTX requests.
    final tileProvider = NetworkTileProvider(
      httpClient: reportingClient,
      silenceExceptions: true,
      attemptDecodeOfHttpErrorResponses: false,
    );

    debugPrint(
      '[MapTile] step=http-client-created '
      'proxy=$proxyDescription '
      'tileSource=${tileSource.description} '
      'tileProbeUri=${tileSource.probeUri} '
      'connectionTimeoutSeconds=12 '
      'idleTimeoutSeconds=30 '
      'maxConnectionsPerHost=6 '
      'retries=1',
    );

    return MapTileHttpClientBundle(
      httpClient: reportingClient,
      tileProvider: tileProvider,
      proxyDescription: proxyDescription,
      tileUrlTemplate: tileSource.urlTemplate,
      tileSourceDescription: tileSource.description,
    );
  }

  static String _describeEnvironmentProxy(Uri diagnosticUri) {
    try {
      return describeMapProxyForUri(diagnosticUri, Platform.environment);
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
