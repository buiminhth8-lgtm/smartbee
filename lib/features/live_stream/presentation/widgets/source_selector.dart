import 'package:flutter/material.dart';

import '../../domain/capture_source_type.dart';

class SourceSelector extends StatelessWidget {
  const SourceSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final CaptureSourceType value;
  final ValueChanged<CaptureSourceType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<CaptureSourceType>(
      segments: const [
        ButtonSegment(
          value: CaptureSourceType.camera,
          icon: Icon(Icons.videocam_outlined),
          label: Text('摄像头'),
        ),
        ButtonSegment(
          value: CaptureSourceType.screen,
          icon: Icon(Icons.desktop_windows_outlined),
          label: Text('屏幕'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
