import 'package:flutter/material.dart';

import '../../domain/stream_statistics.dart';

class StreamStatisticsPanel extends StatelessWidget {
  const StreamStatisticsPanel({super.key, required this.statistics});

  final StreamStatistics statistics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('推流统计', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatTile(label: '状态', value: statistics.statusLabel),
            _StatTile(label: '时长', value: _formatDuration(statistics.elapsed)),
            _StatTile(label: '分辨率', value: statistics.resolutionLabel),
            _StatTile(
              label: '帧率',
              value: statistics.framesPerSecond.toStringAsFixed(1),
            ),
            _StatTile(
              label: '发送码率',
              value: '${statistics.sendBitrateKbps.toStringAsFixed(0)} kbps',
            ),
            _StatTile(label: '视频字节', value: '${statistics.videoBytesSent}'),
            _StatTile(label: '音频字节', value: '${statistics.audioBytesSent}'),
            _StatTile(label: '丢包', value: '${statistics.packetsLost}'),
            _StatTile(
              label: 'RTT',
              value: '${statistics.roundTripTimeMs.toStringAsFixed(0)} ms',
            ),
            _StatTile(label: '视频编码', value: statistics.videoCodec),
            _StatTile(label: '音频编码', value: statistics.audioCodec),
            _StatTile(label: 'ICE', value: statistics.iceState),
            _StatTile(label: 'PC', value: statistics.peerConnectionState),
            _StatTile(label: '候选', value: statistics.candidateType),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
