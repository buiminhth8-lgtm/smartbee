import 'package:flutter/material.dart';

Future<String?> showCreateChapterDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _CreateChapterDialog(),
  );
}

class _CreateChapterDialog extends StatefulWidget {
  const _CreateChapterDialog();

  @override
  State<_CreateChapterDialog> createState() => _CreateChapterDialogState();
}

class _CreateChapterDialogState extends State<_CreateChapterDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isNotEmpty) {
      Navigator.of(context).pop(title);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建章节'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(labelText: '章节名'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('创建')),
      ],
    );
  }
}
