import 'package:flutter/material.dart';

class CreateNovelDialogResult {
  const CreateNovelDialogResult({
    required this.title,
    required this.author,
    required this.synopsis,
  });

  final String title;
  final String author;
  final String synopsis;
}

Future<CreateNovelDialogResult?> showCreateNovelDialog(BuildContext context) {
  return showDialog<CreateNovelDialogResult>(
    context: context,
    builder: (context) => const _CreateNovelDialog(),
  );
}

class _CreateNovelDialog extends StatefulWidget {
  const _CreateNovelDialog();

  @override
  State<_CreateNovelDialog> createState() => _CreateNovelDialogState();
}

class _CreateNovelDialogState extends State<_CreateNovelDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _synopsisController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _synopsisController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      CreateNovelDialogResult(
        title: title,
        author: _authorController.text.trim(),
        synopsis: _synopsisController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建小说'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: '书名'),
            ),
            TextField(
              controller: _authorController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: '作者（可选）'),
            ),
            TextField(
              controller: _synopsisController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '简介（可选）'),
            ),
          ],
        ),
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
