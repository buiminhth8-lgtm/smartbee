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
  final titleController = TextEditingController();
  final authorController = TextEditingController();
  final synopsisController = TextEditingController();

  return showDialog<CreateNovelDialogResult>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('新建小说'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '书名'),
              ),
              TextField(
                controller: authorController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '作者（可选）'),
              ),
              TextField(
                controller: synopsisController,
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
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) {
                return;
              }
              Navigator.of(context).pop(
                CreateNovelDialogResult(
                  title: title,
                  author: authorController.text.trim(),
                  synopsis: synopsisController.text.trim(),
                ),
              );
            },
            child: const Text('创建'),
          ),
        ],
      );
    },
  ).whenComplete(() {
    titleController.dispose();
    authorController.dispose();
    synopsisController.dispose();
  });
}
