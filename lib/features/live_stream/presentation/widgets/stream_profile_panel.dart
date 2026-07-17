import 'package:flutter/material.dart';

import '../../domain/stream_profile.dart';

class StreamProfilePanel extends StatelessWidget {
  const StreamProfilePanel({
    super.key,
    required this.profile,
    required this.onChanged,
  });

  final StreamProfile profile;
  final ValueChanged<StreamProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('视频配置', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DropdownMenu<String>(
              label: const Text('分辨率'),
              initialSelection: profile.resolutionLabel,
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: '640x360', label: '640x360'),
                DropdownMenuEntry(value: '1280x720', label: '1280x720'),
                DropdownMenuEntry(value: '1920x1080', label: '1920x1080'),
              ],
              onSelected: (value) {
                final parts = value!.split('x');
                onChanged(
                  profile.copyWith(
                    width: int.parse(parts[0]),
                    height: int.parse(parts[1]),
                  ),
                );
              },
            ),
            DropdownMenu<int>(
              label: const Text('帧率'),
              initialSelection: profile.fps,
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 15, label: '15'),
                DropdownMenuEntry(value: 24, label: '24'),
                DropdownMenuEntry(value: 30, label: '30'),
                DropdownMenuEntry(value: 60, label: '60'),
              ],
              onSelected: (value) => onChanged(profile.copyWith(fps: value)),
            ),
            DropdownMenu<int>(
              label: const Text('视频码率'),
              initialSelection: profile.videoBitrateKbps,
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 500, label: '500 kbps'),
                DropdownMenuEntry(value: 1000, label: '1000 kbps'),
                DropdownMenuEntry(value: 2000, label: '2000 kbps'),
                DropdownMenuEntry(value: 4000, label: '4000 kbps'),
              ],
              onSelected: (value) =>
                  onChanged(profile.copyWith(videoBitrateKbps: value)),
            ),
            DropdownMenu<int>(
              label: const Text('音频码率'),
              initialSelection: profile.audioBitrateKbps,
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 64, label: '64 kbps'),
                DropdownMenuEntry(value: 96, label: '96 kbps'),
                DropdownMenuEntry(value: 128, label: '128 kbps'),
              ],
              onSelected: (value) =>
                  onChanged(profile.copyWith(audioBitrateKbps: value)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              selected: profile.sendAudio,
              label: const Text('发送音频'),
              onSelected: (selected) =>
                  onChanged(profile.copyWith(sendAudio: selected)),
            ),
            FilterChip(
              selected: profile.frontCamera,
              label: const Text('前置摄像头'),
              onSelected: (selected) =>
                  onChanged(profile.copyWith(frontCamera: selected)),
            ),
          ],
        ),
      ],
    );
  }
}
