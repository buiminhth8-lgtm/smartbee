class StreamStatistics {
  const StreamStatistics({
    required this.timestamp,
    required this.elapsed,
    required this.statusLabel,
    required this.width,
    required this.height,
    required this.framesPerSecond,
    required this.sendBitrateKbps,
    required this.videoBytesSent,
    required this.audioBytesSent,
    required this.packetsLost,
    required this.roundTripTimeMs,
    required this.videoCodec,
    required this.audioCodec,
    required this.iceState,
    required this.peerConnectionState,
    required this.candidateType,
  });

  factory StreamStatistics.empty() {
    return StreamStatistics(
      timestamp: DateTime.now(),
      elapsed: Duration.zero,
      statusLabel: '空闲',
      width: 0,
      height: 0,
      framesPerSecond: 0,
      sendBitrateKbps: 0,
      videoBytesSent: 0,
      audioBytesSent: 0,
      packetsLost: 0,
      roundTripTimeMs: 0,
      videoCodec: '-',
      audioCodec: '-',
      iceState: '-',
      peerConnectionState: '-',
      candidateType: '-',
    );
  }

  final DateTime timestamp;
  final Duration elapsed;
  final String statusLabel;
  final int width;
  final int height;
  final double framesPerSecond;
  final double sendBitrateKbps;
  final int videoBytesSent;
  final int audioBytesSent;
  final int packetsLost;
  final double roundTripTimeMs;
  final String videoCodec;
  final String audioCodec;
  final String iceState;
  final String peerConnectionState;
  final String candidateType;

  String get resolutionLabel =>
      width > 0 && height > 0 ? '${width}x$height' : '-';
}
