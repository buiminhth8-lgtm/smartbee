import 'novel_chapter.dart';
import 'novel_project.dart';

abstract interface class NovelRepository {
  Future<List<NovelProject>> loadProjects();

  Future<NovelProject> createProject({
    required String title,
    String author,
    String synopsis,
  });

  Future<void> saveProject(NovelProject project);

  Future<void> deleteProject(String projectId);

  Future<NovelChapter?> loadChapter({
    required String projectId,
    required String chapterId,
  });

  Future<void> saveChapter(NovelChapter chapter);

  Future<void> deleteChapter({
    required String projectId,
    required String chapterId,
  });
}
