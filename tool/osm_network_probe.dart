// ignore_for_file: avoid_print

import 'dart:io';

Future<void> main() async {
  const proxy = String.fromEnvironment('MAP_HTTP_PROXY');
  final uri = Uri.parse('https://tile.openstreetmap.org/12/3373/1553.png');

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);

  late final String resolvedProxy;
  if (proxy.trim().isNotEmpty) {
    final normalizedProxy = _normalizeProxy(proxy);
    resolvedProxy = 'PROXY $normalizedProxy';
    client.findProxy = (_) => resolvedProxy;
  } else {
    resolvedProxy = _resolveProxyFromEnvironment(uri, Platform.environment);
    client.findProxy = (requestUri) {
      return _resolveProxyFromEnvironment(requestUri, Platform.environment);
    };
  }

  print('MAP_HTTP_PROXY=$proxy');
  print('HTTP_PROXY=${Platform.environment['HTTP_PROXY']}');
  print('HTTPS_PROXY=${Platform.environment['HTTPS_PROXY']}');
  print('NO_PROXY=${Platform.environment['NO_PROXY']}');
  print('resolvedProxy=$resolvedProxy');

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

String _resolveProxyFromEnvironment(Uri uri, Map<String, String> environment) {
  if (_matchesNoProxy(uri.host, environment)) {
    return 'DIRECT';
  }

  final proxyValue =
      environment['HTTPS_PROXY'] ??
      environment['https_proxy'] ??
      environment['HTTP_PROXY'] ??
      environment['http_proxy'];

  if (proxyValue == null || proxyValue.trim().isEmpty) {
    return 'DIRECT';
  }

  return 'PROXY ${_normalizeProxy(proxyValue)}';
}

String _normalizeProxy(String value) {
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
