import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class DesktopCaptureSourceDialog extends StatefulWidget {
  const DesktopCaptureSourceDialog({super.key, required this.sources});

  final List<DesktopCapturerSource> sources;

  @override
  State<DesktopCaptureSourceDialog> createState() =>
      _DesktopCaptureSourceDialogState();
}

class _DesktopCaptureSourceDialogState
    extends State<DesktopCaptureSourceDialog> {
  DesktopCapturerSource? _selectedSource;
  SourceType _sourceType = SourceType.Screen;

  @override
  Widget build(BuildContext context) {
    final sources = widget.sources
        .where((source) => source.type == _sourceType)
        .toList(growable: false);

    return AlertDialog(
      title: const Text('选择屏幕或窗口'),
      content: SizedBox(
        width: 720,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<SourceType>(
              segments: const [
                ButtonSegment(
                  value: SourceType.Screen,
                  icon: Icon(Icons.monitor_outlined),
                  label: Text('屏幕'),
                ),
                ButtonSegment(
                  value: SourceType.Window,
                  icon: Icon(Icons.web_asset_outlined),
                  label: Text('窗口'),
                ),
              ],
              selected: {_sourceType},
              onSelectionChanged: (selection) {
                setState(() {
                  _sourceType = selection.first;
                  _selectedSource = null;
                });
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: sources.isEmpty
                  ? const Center(child: Text('没有可用来源'))
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.28,
                          ),
                      itemCount: sources.length,
                      itemBuilder: (context, index) {
                        final source = sources[index];
                        return _SourceTile(
                          source: source,
                          selected: _selectedSource?.id == source.id,
                          onTap: () => setState(() => _selectedSource = source),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _selectedSource == null
              ? null
              : () => Navigator.of(context).pop(_selectedSource),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final DesktopCapturerSource source;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(7),
                ),
                child: source.thumbnail == null
                    ? const ColoredBox(
                        color: Color(0xFF202428),
                        child: Icon(Icons.desktop_windows_outlined),
                      )
                    : Image.memory(
                        source.thumbnail!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                source.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
