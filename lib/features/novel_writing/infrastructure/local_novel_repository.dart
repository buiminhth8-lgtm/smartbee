import 'package:uuid/uuid.dart';

import '../domain/novel_chapter.dart';
import '../domain/novel_project.dart';
import '../domain/novel_repository.dart';
import '../domain/novel_volume.dart';
import '../domain/novel_writing_exception.dart';
import 'storage/novel_storage_common.dart';

class LocalNovelRepository implements NovelRepository {
  LocalNovelRepository({
    required NovelStorage storage,
    Uuid? uuid,
    DateTime Function()? now,
  }) : this._(storage: storage, uuid: uuid, now: now);

  LocalNovelRepository._({
    required this._storage,
    Uuid? uuid,
    DateTime Function()? now,
  }) : _uuid = uuid ?? const Uuid(),
       _now = now ?? (() => DateTime.now().toUtc());

  final NovelStorage _storage;
  final Uuid _uuid;
  final DateTime Function() _now;

  @override
  Future<List<NovelProject>> loadProjects() async {
    final ids = await _storage.loadProjectIds();
    final projects = <NovelProject>[];
    for (final id in ids) {
      final manifest = await _storage.loadProjectManifest(id);
      if (manifest == null) {
        throw const NovelWritingException(
          type: NovelWritingExceptionType.projectNotFound,
          message: '小说作品不存在。',
        );
      }
      projects.add(NovelProject.fromJson(manifest));
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  @override
  Future<NovelProject> createProject({
    required String title,
    String author = '',
    String synopsis = '',
  }) async {
    final now = _now();
    final projectId = _uuid.v4();
    final volumeId = _uuid.v4();
    final chapterId = _uuid.v4();
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
    final volume = NovelVolume(
      id: volumeId,
      novelId: projectId,
      title: NovelVolume.defaultTitle,
      order: 0,
      chapterIds: <String>[chapterId],
      createdAt: now,
      updatedAt: now,
    );
    final project = NovelProject(
      id: projectId,
      title: _nonEmpty(title, NovelProject.defaultTitle),
      author: author.trim(),
      synopsis: synopsis.trim(),
      createdAt: now,
      updatedAt: now,
      volumes: <NovelVolume>[volume],
      lastOpenedChapterId: chapterId,
    );

    final ids = await _storage.loadProjectIds();
    await _storage.saveProjectIds(<String>[projectId, ...ids]);
    await saveProject(project);
    await saveChapter(chapter);
    return project;
  }

  @override
  Future<void> saveProject(NovelProject project) {
    return _storage.saveProjectManifest(
      projectId: project.id,
      manifest: project.toJson(),
    );
  }

  @override
  Future<void> deleteProject(String projectId) async {
    await _storage.deleteProject(projectId);
    final ids = await _storage.loadProjectIds();
    await _storage.saveProjectIds(ids.where((id) => id != projectId).toList());
  }

  @override
  Future<NovelChapter?> loadChapter({
    required String projectId,
    required String chapterId,
  }) async {
    final json = await _storage.loadChapter(
      projectId: projectId,
      chapterId: chapterId,
    );
    return json == null ? null : NovelChapter.fromJson(json);
  }

  @override
  Future<void> saveChapter(NovelChapter chapter) {
    return _storage.saveChapter(
      projectId: chapter.novelId,
      chapterId: chapter.id,
      chapter: chapter.toJson(),
    );
  }

  @override
  Future<void> deleteChapter({
    required String projectId,
    required String chapterId,
  }) {
    return _storage.deleteChapter(projectId: projectId, chapterId: chapterId);
  }
}

String _nonEmpty(String value, String fallback) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}
