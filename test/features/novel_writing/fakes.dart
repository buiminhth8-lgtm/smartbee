import 'package:smartbee/features/novel_writing/domain/novel_chapter.dart';
import 'package:smartbee/features/novel_writing/domain/novel_project.dart';
import 'package:smartbee/features/novel_writing/domain/novel_repository.dart';
import 'package:smartbee/features/novel_writing/domain/novel_volume.dart';

class FakeNovelRepository implements NovelRepository {
  final List<NovelProject> projects = <NovelProject>[];
  final Map<String, NovelChapter> chapters = <String, NovelChapter>{};
  int saveChapterCount = 0;
  bool failNextSave = false;
  int _counter = 0;

  @override
  Future<List<NovelProject>> loadProjects() async => projects.toList();

  @override
  Future<NovelProject> createProject({
    required String title,
    String author = '',
    String synopsis = '',
  }) async {
    final now = DateTime.utc(2026, 1, 1, 12, 0, _counter++);
    final projectId = 'project-$_counter';
    final volumeId = 'volume-$_counter';
    final chapterId = 'chapter-$_counter';
    final chapter = NovelChapter(
      id: chapterId,
      novelId: projectId,
      volumeId: volumeId,
      title: NovelChapter.defaultTitle,
      content: '',
      order: 0,
      revision: 0,
      createdAt: now,
      updatedAt: now,
    );
    final project = NovelProject(
      id: projectId,
      title: title,
      author: author,
      synopsis: synopsis,
      createdAt: now,
      updatedAt: now,
      lastOpenedChapterId: chapterId,
      volumes: <NovelVolume>[
        NovelVolume(
          id: volumeId,
          novelId: projectId,
          title: NovelVolume.defaultTitle,
          order: 0,
          chapterIds: <String>[chapterId],
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    projects.insert(0, project);
    chapters[chapter.id] = chapter;
    return project;
  }

  @override
  Future<void> saveProject(NovelProject project) async {
    final index = projects.indexWhere(
      (candidate) => candidate.id == project.id,
    );
    if (index >= 0) {
      projects[index] = project;
    } else {
      projects.add(project);
    }
  }

  @override
  Future<void> deleteProject(String projectId) async {
    projects.removeWhere((project) => project.id == projectId);
    chapters.removeWhere((_, chapter) => chapter.novelId == projectId);
  }

  @override
  Future<NovelChapter?> loadChapter({
    required String projectId,
    required String chapterId,
  }) async {
    return chapters[chapterId];
  }

  @override
  Future<void> saveChapter(NovelChapter chapter) async {
    saveChapterCount++;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('save failed');
    }
    chapters[chapter.id] = chapter;
  }

  @override
  Future<void> deleteChapter({
    required String projectId,
    required String chapterId,
  }) async {
    chapters.remove(chapterId);
  }
}
