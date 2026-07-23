import '../../domain/novel_writing_exception.dart';
import 'novel_storage_common.dart';

class NovelStorageFactory {
  const NovelStorageFactory._();

  static NovelStorage create({String? rootPath}) => const NovelStorageStub();
}

class NovelStorageStub implements NovelStorage {
  const NovelStorageStub();

  NovelWritingException get _unsupported => const NovelWritingException(
    type: NovelWritingExceptionType.storageUnavailable,
    message: '当前平台暂不支持小说本地存储。',
  );

  @override
  Future<void> deleteChapter({
    required String projectId,
    required String chapterId,
  }) => throw _unsupported;
  @override
  Future<void> deleteProject(String projectId) => throw _unsupported;
  @override
  Future<Map<String, Object?>?> loadChapter({
    required String projectId,
    required String chapterId,
  }) => throw _unsupported;
  @override
  Future<Map<String, Object?>?> loadProjectManifest(String projectId) =>
      throw _unsupported;
  @override
  Future<List<String>> loadProjectIds() => throw _unsupported;
  @override
  Future<void> saveChapter({
    required String projectId,
    required String chapterId,
    required Map<String, Object?> chapter,
  }) => throw _unsupported;
  @override
  Future<void> saveProjectIds(List<String> projectIds) => throw _unsupported;
  @override
  Future<void> saveProjectManifest({
    required String projectId,
    required Map<String, Object?> manifest,
  }) => throw _unsupported;
}
