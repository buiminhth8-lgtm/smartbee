import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
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
    final proxyDescription = configuredProxy.isEmpty
        ? 'browser'
        : 'browser-ignores-explicit-proxy';

    if (configuredProxy.isNotEmpty) {
      debugPrint(
        '[MapTile] step=browser-proxy-ignored '
        'reason=browser-network-stack-controls-proxy',
      );
    }

    final retryClient = RetryClient(
      http.Client(),
      retries: 1,
      when: (response) =>
          response.statusCode >= 500 && response.statusCode < 600,
      whenError: (_, _) => false,
    );

    final reportingClient = MapTileReportingClient(
      inner: retryClient,
      onNetworkError: onNetworkError,
    );

    final tileProvider = NetworkTileProvider(
      httpClient: reportingClient,
      silenceExceptions: true,
      attemptDecodeOfHttpErrorResponses: false,
    );

    debugPrint(
      '[MapTile] step=http-client-created '
      'proxy=$proxyDescription '
      'tileSource=${tileSource.description} '
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
}
