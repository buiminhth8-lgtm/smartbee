import 'package:flutter/material.dart';

Future<String?> showCreateChapterDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      void submit() {
        final title = controller.text.trim();
        if (title.isNotEmpty) {
          Navigator.of(context).pop(title);
        }
      }

      return AlertDialog(
        title: const Text('新建章节'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
          decoration: const InputDecoration(labelText: '章节名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(onPressed: submit, child: const Text('创建')),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}
