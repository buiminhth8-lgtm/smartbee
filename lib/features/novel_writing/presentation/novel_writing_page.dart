import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/novel_writing_controller.dart';
import '../domain/novel_save_status.dart';
import '../domain/novel_volume.dart';
import 'dialogs/create_chapter_dialog.dart';
import 'dialogs/create_novel_dialog.dart';
import 'dialogs/create_volume_dialog.dart';
import 'widgets/novel_editor.dart';
import 'widgets/novel_empty_state.dart';
import 'widgets/novel_outline_panel.dart';
import 'widgets/novel_save_indicator.dart';
import 'widgets/novel_status_bar.dart';

class NovelWritingPage extends StatefulWidget {
  const NovelWritingPage({super.key, required this.controller});

  final NovelWritingController controller;

  @override
  State<NovelWritingPage> createState() => _NovelWritingPageState();
}

class _NovelWritingPageState extends State<NovelWritingPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onInactive: _flushBestEffort,
      onPause: _flushBestEffort,
      onDetach: _flushBestEffort,
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    unawaited(widget.controller.close());
    super.dispose();
  }

  void _flushBestEffort() {
    unawaited(widget.controller.flush().catchError((_) {}));
  }

  Future<void> _createNovel() async {
    final result = await showCreateNovelDialog(context);
    if (result == null) {
      return;
    }
    await widget.controller.createNovel(
      title: result.title,
      author: result.author,
      synopsis: result.synopsis,
    );
  }

  Future<void> _createVolume() async {
    final title = await showCreateVolumeDialog(context);
    if (title != null) {
      await widget.controller.createVolume(title);
    }
  }

  Future<void> _createChapter([String? volumeId]) async {
    final state = widget.controller.state;
    final volumes = state.selectedProject?.volumes ?? const <NovelVolume>[];
    final targetVolumeId =
        volumeId ?? (volumes.isEmpty ? null : volumes.first.id);
    if (targetVolumeId == null) {
      return;
    }
    final title = await showCreateChapterDialog(context);
    if (title != null) {
      await widget.controller.createChapter(
        volumeId: targetVolumeId,
        title: title,
      );
    }
  }

  Future<void> _renameVolume(NovelVolume volume) async {
    final title = await showCreateVolumeDialog(context);
    if (title != null) {
      await widget.controller.renameVolume(volumeId: volume.id, title: title);
    }
  }

  Future<void> _confirmDeleteVolume(String volumeId) async {
    if (await _confirm('删除分卷会同时删除其中章节，是否继续？')) {
      await widget.controller.deleteVolume(volumeId);
    }
  }

  Future<void> _confirmDeleteChapter(String chapterId) async {
    if (await _confirm('确定删除这个章节？')) {
      await widget.controller.deleteChapter(chapterId);
    }
  }

  Future<bool> _confirm(String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认操作'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('确定'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        return Shortcuts(
          shortcuts: <ShortcutActivator, Intent>{
            const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                const _SaveIntent(),
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
                const _SaveIntent(),
            const SingleActivator(LogicalKeyboardKey.keyN, control: true):
                const _NewChapterIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _SaveIntent: CallbackAction<_SaveIntent>(
                onInvoke: (_) {
                  unawaited(widget.controller.saveNow().catchError((_) {}));
                  return null;
                },
              ),
              _NewChapterIntent: CallbackAction<_NewChapterIntent>(
                onInvoke: (_) {
                  unawaited(_createChapter());
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final outline = NovelOutlinePanel(
                    projects: state.projects,
                    chaptersById: state.chaptersById,
                    selectedProject: state.selectedProject,
                    selectedChapter: state.selectedChapter,
                    onSelectProject: (id) =>
                        unawaited(widget.controller.selectNovel(id)),
                    onSelectChapter: (id) =>
                        unawaited(widget.controller.selectChapter(id)),
                    onCreateNovel: () => unawaited(_createNovel()),
                    onCreateVolume: () => unawaited(_createVolume()),
                    onCreateChapter: (volumeId) =>
                        unawaited(_createChapter(volumeId)),
                    onRenameVolume: (volume) =>
                        unawaited(_renameVolume(volume)),
                    onDeleteVolume: (id) => unawaited(_confirmDeleteVolume(id)),
                    onDeleteChapter: (id) =>
                        unawaited(_confirmDeleteChapter(id)),
                    onMoveChapter: (chapterId, delta) => unawaited(
                      widget.controller.moveChapter(
                        chapterId: chapterId,
                        delta: delta,
                      ),
                    ),
                  );

                  return Scaffold(
                    key: _scaffoldKey,
                    appBar: AppBar(
                      leading: wide
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.menu),
                              onPressed: () =>
                                  _scaffoldKey.currentState?.openDrawer(),
                            ),
                      title: const Text('小说写作'),
                      actions: [
                        NovelSaveIndicator(
                          status: state.saveStatus,
                          lastSavedAt: state.lastSavedAt,
                          onRetry: () =>
                              unawaited(widget.controller.retrySave()),
                        ),
                        IconButton(
                          tooltip: '新建作品',
                          onPressed: _createNovel,
                          icon: const Icon(Icons.add_box_outlined),
                        ),
                        IconButton(
                          tooltip: '新建分卷',
                          onPressed: state.selectedProject == null
                              ? null
                              : _createVolume,
                          icon: const Icon(Icons.create_new_folder_outlined),
                        ),
                        IconButton(
                          tooltip: '新建章节',
                          onPressed: state.selectedProject == null
                              ? null
                              : () => _createChapter(),
                          icon: const Icon(Icons.note_add_outlined),
                        ),
                        IconButton(
                          tooltip: '立即保存',
                          onPressed: state.saveStatus == NovelSaveStatus.saving
                              ? null
                              : () => unawaited(
                                  widget.controller.saveNow().catchError(
                                    (_) {},
                                  ),
                                ),
                          icon: state.saveStatus == NovelSaveStatus.saved
                              ? const Icon(Icons.check)
                              : const Icon(Icons.save_outlined),
                        ),
                      ],
                    ),
                    drawer: wide ? null : Drawer(child: outline),
                    body: state.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : state.projects.isEmpty
                        ? NovelEmptyState(onCreateNovel: _createNovel)
                        : Row(
                            children: [
                              if (wide)
                                SizedBox(
                                  width: 300,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: Theme.of(context).dividerColor,
                                        ),
                                      ),
                                    ),
                                    child: outline,
                                  ),
                                ),
                              Expanded(
                                child: Column(
                                  children: [
                                    if (state.errorMessage != null)
                                      MaterialBanner(
                                        content: Text(state.errorMessage!),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              unawaited(
                                                widget.controller.retrySave(),
                                              );
                                            },
                                            child: const Text('重试'),
                                          ),
                                        ],
                                      ),
                                    Expanded(
                                      child: NovelEditor(
                                        chapter: state.selectedChapter,
                                        onTitleChanged: (title) {
                                          unawaited(
                                            widget.controller.renameChapter(
                                              title,
                                            ),
                                          );
                                        },
                                        onContentChanged: widget
                                            .controller
                                            .updateChapterContent,
                                      ),
                                    ),
                                    NovelStatusBar(
                                      content:
                                          state.selectedChapter?.content ?? '',
                                      lastSavedAt: state.lastSavedAt,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _NewChapterIntent extends Intent {
  const _NewChapterIntent();
}
