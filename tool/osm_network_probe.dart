// ignore_for_file: avoid_print

import 'dart:io';

import 'package:smartbee/features/map/infrastructure/map_tile_network_config.dart';

Future<void> main() async {
  const proxy = String.fromEnvironment('MAP_HTTP_PROXY');
  const tileUrlTemplate = String.fromEnvironment('MAP_TILE_URL_TEMPLATE');

  final tileSource = resolveMapTileSourceConfig(
    explicitUrlTemplate: tileUrlTemplate,
  );
  final uri = tileSource.probeUri;

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);

  late final String resolvedProxy;
  if (proxy.trim().isNotEmpty) {
    resolvedProxy = normalizeMapProxyConfig(proxy).rule;
    client.findProxy = (_) => resolvedProxy;
  } else {
    resolvedProxy = resolveMapProxyForUri(uri, Platform.environment);
    client.findProxy = (requestUri) {
      return resolveMapProxyForUri(requestUri, Platform.environment);
    };
  }

  print('MAP_HTTP_PROXY=$proxy');
  print('MAP_TILE_URL_TEMPLATE=$tileUrlTemplate');
  print('tileUrlTemplate=${tileSource.urlTemplate}');
  print('probeUri=$uri');
  print('HTTP_PROXY=${_redactProxy(Platform.environment['HTTP_PROXY'])}');
  print('HTTPS_PROXY=${_redactProxy(Platform.environment['HTTPS_PROXY'])}');
  print('NO_PROXY=${Platform.environment['NO_PROXY']}');
  print('resolvedProxy=${_redactProxyRule(resolvedProxy)}');

  final stopwatch = Stopwatch()..start();

  try {
    final request = await client.getUrl(uri);
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'SmartBee-Network-Probe/1.0',
    );

    final response = await request.close();
    var bytes = 0;

    await for (final chunk in response) {
      bytes += chunk.length;
    }

    stopwatch.stop();
    print('status=${response.statusCode}');
    print('bytes=$bytes');
    print('elapsedMs=${stopwatch.elapsedMilliseconds}');
  } catch (error, stackTrace) {
    stopwatch.stop();
    print('failedAfterMs=${stopwatch.elapsedMilliseconds}');
    print('error=$error');
    print(stackTrace);
  } finally {
    client.close(force: true);
  }
}

String? _redactProxy(String? value) {
  if (value == null || value.trim().isEmpty) {
    return value;
  }

  try {
    return normalizeMapProxyConfig(value).description;
  } on ArgumentError {
    return '<invalid-or-unsupported>';
  }
}

String _redactProxyRule(String value) {
  if (value == 'DIRECT') {
    return value;
  }

  if (!value.startsWith('PROXY ')) {
    return '<invalid-or-unsupported>';
  }

  return 'PROXY ${_redactProxy(value.substring('PROXY '.length))}';
}
