import 'package:flutter/material.dart';

import '../../domain/novel_chapter.dart';

class NovelEditor extends StatefulWidget {
  const NovelEditor({
    super.key,
    required this.chapter,
    required this.onTitleChanged,
    required this.onContentChanged,
  });

  final NovelChapter? chapter;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onContentChanged;

  @override
  State<NovelEditor> createState() => _NovelEditorState();
}

class _NovelEditorState extends State<NovelEditor> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();
  bool _isApplyingControllerState = false;

  @override
  void initState() {
    super.initState();
    _applyChapter(widget.chapter);
    _titleController.addListener(_handleTitleChanged);
    _contentController.addListener(_handleContentChanged);
  }

  @override
  void didUpdateWidget(covariant NovelEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapter?.id != widget.chapter?.id) {
      _applyChapter(widget.chapter);
    }
  }

  void _applyChapter(NovelChapter? chapter) {
    _isApplyingControllerState = true;
    _titleController.text = chapter?.title ?? '';
    _contentController.text = chapter?.content ?? '';
    _isApplyingControllerState = false;
  }

  void _handleTitleChanged() {
    if (_isApplyingControllerState || widget.chapter == null) {
      return;
    }
    widget.onTitleChanged(_titleController.text);
  }

  void _handleContentChanged() {
    if (_isApplyingControllerState || widget.chapter == null) {
      return;
    }
    widget.onContentChanged(_contentController.text);
  }

  @override
  void dispose() {
    _titleController.removeListener(_handleTitleChanged);
    _contentController.removeListener(_handleContentChanged);
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chapter == null) {
      return const Center(child: Text('请选择或新建章节'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            style: Theme.of(context).textTheme.headlineSmall,
            decoration: const InputDecoration(
              labelText: '章节标题',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _contentController,
              focusNode: _contentFocusNode,
              expands: true,
              minLines: null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: '正文',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
