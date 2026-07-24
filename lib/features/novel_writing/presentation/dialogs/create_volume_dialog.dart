import 'package:flutter/material.dart';

Future<String?> showCreateVolumeDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _CreateVolumeDialog(),
  );
}

class _CreateVolumeDialog extends StatefulWidget {
  const _CreateVolumeDialog();

  @override
  State<_CreateVolumeDialog> createState() => _CreateVolumeDialogState();
}

class _CreateVolumeDialogState extends State<_CreateVolumeDialog> {
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
      title: const Text('新建分卷'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(labelText: '卷名'),
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
