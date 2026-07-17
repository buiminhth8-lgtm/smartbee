import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../domain/capture_source_type.dart';
import '../../domain/stream_session_state.dart';
import '../../infrastructure/capture/screen_capture_adapter.dart';

class StreamPreview extends StatefulWidget {
  const StreamPreview({
    super.key,
    required this.stream,
    required this.sourceType,
    required this.status,
    required this.errorMessage,
    required this.mirror,
    this.onRendererDisposed,
  });

  final MediaStream? stream;
  final CaptureSourceType sourceType;
  final StreamSessionStatus status;
  final String? errorMessage;
  final bool mirror;
  final VoidCallback? onRendererDisposed;

  @override
  State<StreamPreview> createState() => _StreamPreviewState();
}

class _StreamPreviewState extends State<StreamPreview> {
  late final RTCVideoRenderer _renderer;
  bool _ready = false;
  Object? _rendererError;

  @override
  void initState() {
    super.initState();
    _renderer = RTCVideoRenderer();
    _initRenderer();
  }

  Future<void> _initRenderer() async {
    try {
      logScreenCapture(
        'renderer-initialize-start',
        platform: _platformLabel,
        status: widget.status.name,
      );
      await _renderer.initialize();
      if (!mounted) {
        await _renderer.dispose();
        return;
      }
      _renderer.srcObject = widget.stream;
      logScreenCapture(
        'renderer-bind',
        platform: _platformLabel,
        status: widget.status.name,
        stream: widget.stream,
      );
      setState(() => _ready = true);
    } catch (error, stackTrace) {
      logScreenCapture(
        'renderer-initialize-failed',
        platform: _platformLabel,
        status: widget.status.name,
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() => _rendererError = error);
      }
    }
  }

  @override
  void didUpdateWidget(covariant StreamPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream?.id != widget.stream?.id && _ready) {
      _renderer.srcObject = widget.stream;
      logScreenCapture(
        'renderer-update-srcObject',
        platform: _platformLabel,
        status: widget.status.name,
        stream: widget.stream,
      );
    }
  }

  @override
  void dispose() {
    _renderer.srcObject = null;
    _renderer.dispose();
    logScreenCapture(
      'renderer-dispose',
      platform: _platformLabel,
      status: widget.status.name,
    );
    widget.onRendererDisposed?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasStream = widget.stream != null;
    final hasError =
        widget.errorMessage != null &&
        widget.status == StreamSessionStatus.failed;
    final rendererError = _rendererError;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFF101418)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (rendererError != null)
                _PreviewPlaceholder(
                  icon: Icons.error_outline,
                  text: '预览渲染器初始化失败',
                )
              else if (_ready && hasStream)
                RTCVideoView(
                  _renderer,
                  mirror: widget.mirror,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                )
              else
                _PreviewPlaceholder(
                  icon: hasError
                      ? Icons.error_outline
                      : widget.sourceType == CaptureSourceType.camera
                      ? Icons.videocam_outlined
                      : Icons.desktop_windows_outlined,
                  text: hasError
                      ? widget.errorMessage!
                      : widget.status.isBusy
                      ? '正在准备预览'
                      : '暂无预览画面',
                ),
              Positioned(
                left: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.54),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      widget.status.label,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _platformLabel => widget.sourceType == CaptureSourceType.camera
      ? 'camera-preview'
      : 'screen-preview';
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 44),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
