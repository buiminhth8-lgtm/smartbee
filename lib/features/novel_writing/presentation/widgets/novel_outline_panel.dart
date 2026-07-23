import 'package:flutter/material.dart';

import '../../domain/novel_chapter.dart';
import '../../domain/novel_project.dart';
import '../../domain/novel_volume.dart';

class NovelOutlinePanel extends StatelessWidget {
  const NovelOutlinePanel({
    super.key,
    required this.projects,
    required this.chaptersById,
    required this.selectedProject,
    required this.selectedChapter,
    required this.onSelectProject,
    required this.onSelectChapter,
    required this.onCreateNovel,
    required this.onCreateVolume,
    required this.onCreateChapter,
    required this.onRenameVolume,
    required this.onDeleteVolume,
    required this.onDeleteChapter,
    required this.onMoveChapter,
  });

  final List<NovelProject> projects;
  final Map<String, NovelChapter> chaptersById;
  final NovelProject? selectedProject;
  final NovelChapter? selectedChapter;
  final ValueChanged<String> onSelectProject;
  final ValueChanged<String> onSelectChapter;
  final VoidCallback onCreateNovel;
  final VoidCallback onCreateVolume;
  final ValueChanged<String> onCreateChapter;
  final ValueChanged<NovelVolume> onRenameVolume;
  final ValueChanged<String> onDeleteVolume;
  final ValueChanged<String> onDeleteChapter;
  final void Function(String chapterId, int delta) onMoveChapter;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedProject?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '作品',
                      border: OutlineInputBorder(),
                    ),
                    items: projects
                        .map(
                          (project) => DropdownMenuItem(
                            value: project.id,
                            child: Text(
                              project.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      if (id != null) {
                        onSelectProject(id);
                      }
                    },
                  ),
                ),
                IconButton(
                  tooltip: '新建小说',
                  onPressed: onCreateNovel,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          if (selectedProject != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: OutlinedButton.icon(
                onPressed: onCreateVolume,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('新建分卷'),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: selectedProject == null
                ? const Center(child: Text('暂无作品'))
                : ListView(
                    children: [
                      for (final volume in selectedProject!.volumes)
                        ExpansionTile(
                          key: PageStorageKey(volume.id),
                          initiallyExpanded: true,
                          title: Text(
                            volume.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'new':
                                  onCreateChapter(volume.id);
                                case 'rename':
                                  onRenameVolume(volume);
                                case 'delete':
                                  onDeleteVolume(volume.id);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'new', child: Text('新建章节')),
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('重命名分卷'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('删除分卷'),
                              ),
                            ],
                          ),
                          children: [
                            for (final chapterId in volume.chapterIds)
                              _ChapterTile(
                                chapter: chaptersById[chapterId],
                                chapterId: chapterId,
                                selected: selectedChapter?.id == chapterId,
                                onSelect: () => onSelectChapter(chapterId),
                                onDelete: () => onDeleteChapter(chapterId),
                                onMoveUp: () => onMoveChapter(chapterId, -1),
                                onMoveDown: () => onMoveChapter(chapterId, 1),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 12,
                                bottom: 8,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => onCreateChapter(volume.id),
                                  icon: const Icon(Icons.note_add_outlined),
                                  label: const Text('新建章节'),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.chapter,
    required this.chapterId,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final NovelChapter? chapter;
  final String chapterId;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      dense: true,
      title: Text(chapter?.title ?? '章节加载失败', overflow: TextOverflow.ellipsis),
      subtitle: chapter == null
          ? Text(chapterId, overflow: TextOverflow.ellipsis)
          : null,
      onTap: onSelect,
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'up':
              onMoveUp();
            case 'down':
              onMoveDown();
            case 'delete':
              onDelete();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'up', child: Text('上移')),
          PopupMenuItem(value: 'down', child: Text('下移')),
          PopupMenuItem(value: 'delete', child: Text('删除章节')),
        ],
      ),
    );
  }
}
