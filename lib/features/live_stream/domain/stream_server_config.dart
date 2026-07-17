class StreamServerConfig {
  const StreamServerConfig({
    required this.host,
    required this.webrtcPort,
    required this.streamName,
    required this.useHttps,
    required this.bearerToken,
  });

  factory StreamServerConfig.defaults() {
    return const StreamServerConfig(
      host: '127.0.0.1',
      webrtcPort: 8889,
      streamName: 'smartbee',
      useHttps: false,
      bearerToken: '',
    );
  }

  final String host;
  final int webrtcPort;
  final String streamName;
  final bool useHttps;
  final String bearerToken;

  String get scheme => useHttps ? 'https' : 'http';
  bool get hasBearerToken => bearerToken.trim().isNotEmpty;

  StreamServerConfig copyWith({
    String? host,
    int? webrtcPort,
    String? streamName,
    bool? useHttps,
    String? bearerToken,
  }) {
    return StreamServerConfig(
      host: host ?? this.host,
      webrtcPort: webrtcPort ?? this.webrtcPort,
      streamName: streamName ?? this.streamName,
      useHttps: useHttps ?? this.useHttps,
      bearerToken: bearerToken ?? this.bearerToken,
    );
  }

  Map<String, Object?> toJson({bool includeToken = false}) {
    return {
      'host': host,
      'webrtcPort': webrtcPort,
      'streamName': streamName,
      'useHttps': useHttps,
      if (includeToken) 'bearerToken': bearerToken,
    };
  }

  factory StreamServerConfig.fromJson(Map<String, Object?> json) {
    final defaults = StreamServerConfig.defaults();
    return StreamServerConfig(
      host: json['host'] as String? ?? defaults.host,
      webrtcPort: json['webrtcPort'] as int? ?? defaults.webrtcPort,
      streamName: json['streamName'] as String? ?? defaults.streamName,
      useHttps: json['useHttps'] as bool? ?? defaults.useHttps,
      bearerToken: '',
    );
  }
}
