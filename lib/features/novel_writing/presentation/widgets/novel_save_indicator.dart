import 'package:flutter/material.dart';

import '../../domain/novel_save_status.dart';

class NovelSaveIndicator extends StatelessWidget {
  const NovelSaveIndicator({
    super.key,
    required this.status,
    required this.lastSavedAt,
    required this.onRetry,
  });

  final NovelSaveStatus status;
  final DateTime? lastSavedAt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (status) {
      NovelSaveStatus.idle => (Icons.info_outline, '未选择章节'),
      NovelSaveStatus.dirty => (Icons.edit_outlined, '有未保存修改'),
      NovelSaveStatus.saving => (Icons.sync, '保存中...'),
      NovelSaveStatus.saved => (Icons.check_circle_outline, _savedLabel()),
      NovelSaveStatus.failed => (Icons.error_outline, '保存失败，点击重试'),
    };

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == NovelSaveStatus.saving)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label),
      ],
    );

    if (status == NovelSaveStatus.failed) {
      return TextButton(onPressed: onRetry, child: child);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: child,
    );
  }

  String _savedLabel() {
    final savedAt = lastSavedAt;
    if (savedAt == null) {
      return '已保存';
    }
    final local = savedAt.toLocal();
    return '已保存 ${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
