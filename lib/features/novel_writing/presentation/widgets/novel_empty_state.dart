import 'package:flutter/material.dart';

class NovelEmptyState extends StatelessWidget {
  const NovelEmptyState({
    super.key,
    required this.onCreateNovel,
    this.message = '还没有小说作品',
  });

  final VoidCallback onCreateNovel;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_outlined, size: 56),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('创建一个作品，开始写作'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreateNovel,
            icon: const Icon(Icons.add),
            label: const Text('新建小说'),
          ),
        ],
      ),
    );
  }
}
