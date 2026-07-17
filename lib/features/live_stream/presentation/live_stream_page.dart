import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../application/live_stream_controller.dart';
import '../application/stream_url_builder.dart';
import '../domain/capture_source_type.dart';
import '../domain/publish_protocol.dart';
import '../domain/stream_session_state.dart';
import 'dialogs/desktop_capture_source_dialog.dart';
import 'dialogs/permission_help_dialog.dart';
import 'widgets/server_config_panel.dart';
import 'widgets/source_selector.dart';
import 'widgets/stream_control_bar.dart';
import 'widgets/stream_log_panel.dart';
import 'widgets/stream_output_urls.dart';
import 'widgets/stream_preview.dart';
import 'widgets/stream_profile_panel.dart';
import 'widgets/stream_statistics_panel.dart';

class LiveStreamPage extends StatefulWidget {
  const LiveStreamPage({super.key, required this.controller});

  final LiveStreamController controller;

  @override
  State<LiveStreamPage> createState() => _LiveStreamPageState();
}

class _LiveStreamPageState extends State<LiveStreamPage> {
  LiveStreamController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.setDesktopCaptureSourcePicker(_selectDesktopSource);
  }

  @override
  void dispose() {
    controller.setDesktopCaptureSourcePicker(null);
    super.dispose();
  }

  Future<DesktopCapturerSource?> _selectDesktopSource(
    List<DesktopCapturerSource> sources,
  ) {
    return showDialog<DesktopCapturerSource>(
      context: context,
      builder: (context) => DesktopCaptureSourceDialog(sources: sources),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final urls = const StreamUrlBuilder().build(state.config);
        return Scaffold(
          appBar: AppBar(
            title: const Text('实时推流'),
            actions: [
              IconButton(
                tooltip: '权限说明',
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const PermissionHelpDialog(),
                  );
                },
                icon: const Icon(Icons.help_outline),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TopRow(
                        sourceType: state.sourceType,
                        protocol: state.protocol,
                        onSourceChanged: controller.setSourceType,
                        onProtocolChanged: controller.setProtocol,
                      ),
                      const SizedBox(height: 16),
                      StreamPreview(
                        stream: controller.currentStream,
                        sourceType: state.sourceType,
                        status: state.status,
                        errorMessage: state.errorMessage,
                        mirror:
                            state.sourceType == CaptureSourceType.camera &&
                            state.profile.frontCamera,
                      ),
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          state.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: controller.openPreview,
                              icon: const Icon(Icons.refresh),
                              label: const Text('重试'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await controller.setSourceType(
                                  CaptureSourceType.camera,
                                );
                                await controller.openPreview();
                              },
                              icon: const Icon(Icons.videocam_outlined),
                              label: const Text('返回摄像头预览'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showDiagnostics(context, state),
                              icon: const Icon(Icons.info_outline),
                              label: const Text('查看诊断信息'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      StreamControlBar(
                        status: state.status,
                        sourceType: state.sourceType,
                        profile: state.profile,
                        onPreview: controller.openPreview,
                        onStart: controller.startPublishing,
                        onStop: controller.stopPublishing,
                        onSwitchCamera: controller.switchCamera,
                        onToggleMic: () => controller.setMicrophoneEnabled(
                          !state.profile.microphoneEnabled,
                        ),
                        onToggleVideo: () => controller.setCameraEnabled(
                          !state.profile.cameraEnabled,
                        ),
                        onFullscreen: () =>
                            _showFullscreenPreview(context, state),
                      ),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final twoColumns = constraints.maxWidth >= 900;
                          final config = ServerConfigPanel(
                            config: state.config,
                            onChanged: controller.updateConfig,
                          );
                          final profile = StreamProfilePanel(
                            profile: state.profile,
                            onChanged: controller.updateProfile,
                          );
                          if (!twoColumns) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                config,
                                const SizedBox(height: 24),
                                profile,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: config),
                              const SizedBox(width: 24),
                              Expanded(child: profile),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      StreamOutputUrlsWidget(urls: urls),
                      const SizedBox(height: 24),
                      StreamStatisticsPanel(
                        statistics: state.currentStatistics,
                      ),
                      const SizedBox(height: 24),
                      StreamLogPanel(logs: state.logs),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFullscreenPreview(BuildContext context, StreamSessionState state) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: const Text('全屏预览'),
            ),
            body: Center(
              child: StreamPreview(
                stream: controller.currentStream,
                sourceType: state.sourceType,
                status: state.status,
                errorMessage: state.errorMessage,
                mirror:
                    state.sourceType == CaptureSourceType.camera &&
                    state.profile.frontCamera,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDiagnostics(BuildContext context, StreamSessionState state) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('诊断信息'),
          content: SelectableText(
            '来源：${state.sourceType.label}\n'
            '状态：${state.status.label}\n'
            '错误摘要：${state.errorMessage ?? '-'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.sourceType,
    required this.protocol,
    required this.onSourceChanged,
    required this.onProtocolChanged,
  });

  final CaptureSourceType sourceType;
  final PublishProtocol protocol;
  final ValueChanged<CaptureSourceType> onSourceChanged;
  final ValueChanged<PublishProtocol> onProtocolChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SourceSelector(value: sourceType, onChanged: onSourceChanged),
        SegmentedButton<PublishProtocol>(
          segments: const [
            ButtonSegment(value: PublishProtocol.whip, label: Text('WHIP')),
            ButtonSegment(value: PublishProtocol.rtmp, label: Text('RTMP')),
            ButtonSegment(value: PublishProtocol.rtsp, label: Text('RTSP')),
          ],
          selected: {protocol},
          onSelectionChanged: (selection) => onProtocolChanged(selection.first),
        ),
        if (!protocol.isImplemented)
          const Text('当前平台暂未实现直接推送，请使用 WHIP 或服务器协议转换。'),
      ],
    );
  }
}
