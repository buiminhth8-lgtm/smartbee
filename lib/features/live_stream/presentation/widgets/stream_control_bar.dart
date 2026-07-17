import 'package:flutter/material.dart';

import '../../domain/capture_source_type.dart';
import '../../domain/stream_profile.dart';
import '../../domain/stream_session_state.dart';

class StreamControlBar extends StatelessWidget {
  const StreamControlBar({
    super.key,
    required this.status,
    required this.sourceType,
    required this.profile,
    required this.onPreview,
    required this.onStart,
    required this.onStop,
    required this.onSwitchCamera,
    required this.onToggleMic,
    required this.onToggleVideo,
    required this.onFullscreen,
  });

  final StreamSessionStatus status;
  final CaptureSourceType sourceType;
  final StreamProfile profile;
  final VoidCallback onPreview;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleVideo;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    final isPublishing =
        status == StreamSessionStatus.publishing ||
        status == StreamSessionStatus.connecting ||
        status == StreamSessionStatus.reconnecting;
    final busy = status.isBusy;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: busy || isPublishing ? null : onPreview,
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('打开预览'),
        ),
        FilledButton.icon(
          onPressed: busy || isPublishing ? null : onStart,
          icon: const Icon(Icons.podcasts),
          label: const Text('开始推流'),
        ),
        OutlinedButton.icon(
          onPressed: busy && !isPublishing ? null : onStop,
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('停止推流'),
        ),
        IconButton.filledTonal(
          tooltip: '切换摄像头',
          onPressed: sourceType == CaptureSourceType.camera
              ? onSwitchCamera
              : null,
          icon: const Icon(Icons.cameraswitch_outlined),
        ),
        IconButton.filledTonal(
          tooltip: profile.microphoneEnabled ? '静音' : '取消静音',
          onPressed: onToggleMic,
          icon: Icon(
            profile.microphoneEnabled
                ? Icons.mic_outlined
                : Icons.mic_off_outlined,
          ),
        ),
        IconButton.filledTonal(
          tooltip: profile.cameraEnabled ? '关闭视频' : '开启视频',
          onPressed: sourceType == CaptureSourceType.camera
              ? onToggleVideo
              : null,
          icon: Icon(
            profile.cameraEnabled
                ? Icons.videocam_outlined
                : Icons.videocam_off_outlined,
          ),
        ),
        IconButton.filledTonal(
          tooltip: '全屏预览',
          onPressed: onFullscreen,
          icon: const Icon(Icons.fullscreen),
        ),
      ],
    );
  }
}
