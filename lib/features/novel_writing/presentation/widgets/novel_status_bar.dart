import 'package:flutter/material.dart';

import '../../application/novel_text_statistics.dart';

class NovelStatusBar extends StatelessWidget {
  const NovelStatusBar({
    super.key,
    required this.content,
    required this.lastSavedAt,
  });

  final String content;
  final DateTime? lastSavedAt;

  @override
  Widget build(BuildContext context) {
    final statistics = NovelTextStatistics.calculate(content);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Wrap(
        spacing: 20,
        children: [
          Text('字数（不含空白）：${statistics.characterCount}'),
          Text('段落：${statistics.paragraphCount}'),
          Text('最后保存：${_formatTime(lastSavedAt)}'),
        ],
      ),
    );
  }

  String _formatTime(DateTime? value) {
    if (value == null) {
      return '--:--:--';
    }
    final local = value.toLocal();
    return '${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
