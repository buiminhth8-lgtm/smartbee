class StreamProfile {
  const StreamProfile({
    required this.width,
    required this.height,
    required this.fps,
    required this.videoBitrateKbps,
    required this.audioBitrateKbps,
    required this.microphoneEnabled,
    required this.cameraEnabled,
    required this.sendAudio,
    required this.frontCamera,
  });

  factory StreamProfile.defaults() {
    return const StreamProfile(
      width: 1280,
      height: 720,
      fps: 30,
      videoBitrateKbps: 2000,
      audioBitrateKbps: 128,
      microphoneEnabled: true,
      cameraEnabled: true,
      sendAudio: true,
      frontCamera: true,
    );
  }

  final int width;
  final int height;
  final int fps;
  final int videoBitrateKbps;
  final int audioBitrateKbps;
  final bool microphoneEnabled;
  final bool cameraEnabled;
  final bool sendAudio;
  final bool frontCamera;

  String get resolutionLabel => '${width}x$height';

  StreamProfile copyWith({
    int? width,
    int? height,
    int? fps,
    int? videoBitrateKbps,
    int? audioBitrateKbps,
    bool? microphoneEnabled,
    bool? cameraEnabled,
    bool? sendAudio,
    bool? frontCamera,
  }) {
    return StreamProfile(
      width: width ?? this.width,
      height: height ?? this.height,
      fps: fps ?? this.fps,
      videoBitrateKbps: videoBitrateKbps ?? this.videoBitrateKbps,
      audioBitrateKbps: audioBitrateKbps ?? this.audioBitrateKbps,
      microphoneEnabled: microphoneEnabled ?? this.microphoneEnabled,
      cameraEnabled: cameraEnabled ?? this.cameraEnabled,
      sendAudio: sendAudio ?? this.sendAudio,
      frontCamera: frontCamera ?? this.frontCamera,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'width': width,
      'height': height,
      'fps': fps,
      'videoBitrateKbps': videoBitrateKbps,
      'audioBitrateKbps': audioBitrateKbps,
      'microphoneEnabled': microphoneEnabled,
      'cameraEnabled': cameraEnabled,
      'sendAudio': sendAudio,
      'frontCamera': frontCamera,
    };
  }

  factory StreamProfile.fromJson(Map<String, Object?> json) {
    final defaults = StreamProfile.defaults();
    return StreamProfile(
      width: json['width'] as int? ?? defaults.width,
      height: json['height'] as int? ?? defaults.height,
      fps: json['fps'] as int? ?? defaults.fps,
      videoBitrateKbps:
          json['videoBitrateKbps'] as int? ?? defaults.videoBitrateKbps,
      audioBitrateKbps:
          json['audioBitrateKbps'] as int? ?? defaults.audioBitrateKbps,
      microphoneEnabled:
          json['microphoneEnabled'] as bool? ?? defaults.microphoneEnabled,
      cameraEnabled: json['cameraEnabled'] as bool? ?? defaults.cameraEnabled,
      sendAudio: json['sendAudio'] as bool? ?? defaults.sendAudio,
      frontCamera: json['frontCamera'] as bool? ?? defaults.frontCamera,
    );
  }
}
