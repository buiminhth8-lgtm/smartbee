const defaultMapTileUrlTemplate =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

const defaultMapTileProbeZ = 12;
const defaultMapTileProbeX = 3373;
const defaultMapTileProbeY = 1553;

class MapTileSourceConfig {
  const MapTileSourceConfig({
    required this.urlTemplate,
    required this.probeUri,
    required this.description,
  });

  final String urlTemplate;
  final Uri probeUri;
  final String description;
}

class MapProxyConfig {
  const MapProxyConfig({
    required this.rule,
    required this.address,
    required this.description,
  });

  final String rule;
  final String address;
  final String description;
}

MapTileSourceConfig resolveMapTileSourceConfig({String? explicitUrlTemplate}) {
  final configuredTemplate =
      (explicitUrlTemplate ??
              const String.fromEnvironment('MAP_TILE_URL_TEMPLATE'))
          .trim();
  final urlTemplate = normalizeMapTileUrlTemplate(configuredTemplate);
  final probeUri = buildMapTileProbeUri(urlTemplate);
  final description = '${probeUri.scheme}://${probeUri.host}';

  return MapTileSourceConfig(
    urlTemplate: urlTemplate,
    probeUri: probeUri,
    description: description,
  );
}

String normalizeMapTileUrlTemplate(String value) {
  final result = value.trim().isEmpty
      ? defaultMapTileUrlTemplate
      : value.trim();
  final probeUri = buildMapTileProbeUri(result);

  if (!result.contains('{z}') ||
      !result.contains('{x}') ||
      !result.contains('{y}')) {
    throw ArgumentError.value(
      value,
      'MAP_TILE_URL_TEMPLATE',
      '地图瓦片地址模板必须包含 {z}、{x} 和 {y} 占位符。',
    );
  }

  if (probeUri.scheme != 'https' && probeUri.scheme != 'http') {
    throw ArgumentError.value(
      value,
      'MAP_TILE_URL_TEMPLATE',
      '地图瓦片地址模板只支持 http 或 https。',
    );
  }

  if (probeUri.host.isEmpty) {
    throw ArgumentError.value(
      value,
      'MAP_TILE_URL_TEMPLATE',
      '地图瓦片地址模板必须包含主机名。',
    );
  }

  return result;
}

Uri buildMapTileProbeUri(
  String urlTemplate, {
  int z = defaultMapTileProbeZ,
  int x = defaultMapTileProbeX,
  int y = defaultMapTileProbeY,
}) {
  final url = urlTemplate
      .replaceAll('{z}', z.toString())
      .replaceAll('{x}', x.toString())
      .replaceAll('{y}', y.toString())
      .replaceAll('{s}', 'a');

  final uri = Uri.tryParse(url);
  if (uri == null) {
    throw ArgumentError.value(
      urlTemplate,
      'MAP_TILE_URL_TEMPLATE',
      '地图瓦片地址模板无法解析为 URL。',
    );
  }

  return uri;
}

String normalizeMapProxy(String value) {
  return normalizeMapProxyConfig(value).address;
}

MapProxyConfig normalizeMapProxyConfig(String value) {
  final original = value.trim();
  if (original.isEmpty) {
    throw ArgumentError.value(value, 'MAP_HTTP_PROXY', '地图代理不能为空。');
  }

  final lower = original.toLowerCase();
  if (lower.startsWith('socks://') ||
      lower.startsWith('socks4://') ||
      lower.startsWith('socks5://') ||
      lower.startsWith('pac+')) {
    throw ArgumentError.value(
      value,
      'MAP_HTTP_PROXY',
      'Dart HttpClient 的地图瓦片代理仅支持 HTTP CONNECT 代理，不支持 SOCKS 或 PAC；请使用 http://host:port 或 host:port。',
    );
  }

  var result = original;

  if (lower.startsWith('http://')) {
    result = result.substring('http://'.length);
  } else if (lower.startsWith('https://')) {
    // HTTPS_PROXY 表示“给 HTTPS 目标使用的代理”，Dart HttpClient 仍按 HTTP CONNECT 代理连接。
    result = result.substring('https://'.length);
  } else if (original.contains('://')) {
    throw ArgumentError.value(
      value,
      'MAP_HTTP_PROXY',
      '地图代理只支持 http://host:port 或 host:port。',
    );
  }

  final slashIndex = result.indexOf('/');
  if (slashIndex >= 0) {
    result = result.substring(0, slashIndex);
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

  final host = _formatProxyHost(uri.host);
  final address = '$host:${uri.port}';
  final userInfo = uri.userInfo;
  final authPrefix = userInfo.isEmpty ? '' : '$userInfo@';
  final safeAuthPrefix = userInfo.isEmpty ? '' : '${_maskUserInfo(userInfo)}@';

  return MapProxyConfig(
    rule: 'PROXY $authPrefix$address',
    address: address,
    description: '$safeAuthPrefix$address',
  );
}

String resolveMapProxyForUri(Uri uri, Map<String, String> environment) {
  if (_matchesNoProxy(uri.host, environment)) {
    return 'DIRECT';
  }

  final proxyValue = _proxyValueForScheme(uri.scheme, environment);
  if (proxyValue == null || proxyValue.trim().isEmpty) {
    return 'DIRECT';
  }

  return normalizeMapProxyConfig(proxyValue).rule;
}

String describeMapProxyForUri(Uri uri, Map<String, String> environment) {
  final resolved = resolveMapProxyForUri(uri, environment);
  if (resolved == 'DIRECT') {
    return 'direct';
  }

  final proxyValue = _proxyValueForScheme(uri.scheme, environment);
  if (proxyValue == null || proxyValue.trim().isEmpty) {
    return 'direct';
  }

  return 'environment:${normalizeMapProxyConfig(proxyValue).description}';
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

String _formatProxyHost(String host) {
  if (host.contains(':') && !host.startsWith('[')) {
    return '[$host]';
  }
  return host;
}

String _maskUserInfo(String userInfo) {
  final separator = userInfo.indexOf(':');
  if (separator <= 0) {
    return '***';
  }

  return '${userInfo.substring(0, separator)}:***';
}
