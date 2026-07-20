import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

import 'map_tile_http_client_common.dart';

class MapTileHttpClientFactory {
  const MapTileHttpClientFactory._();

  static MapTileHttpClientBundle create({String? explicitProxy}) {
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

    final tileProvider = NetworkTileProvider(httpClient: retryClient);

    debugPrint(
      '[MapTile] step=http-client-created '
      'proxy=$proxyDescription '
      'retries=1',
    );

    return MapTileHttpClientBundle(
      httpClient: retryClient,
      tileProvider: tileProvider,
      proxyDescription: proxyDescription,
    );
  }
}
