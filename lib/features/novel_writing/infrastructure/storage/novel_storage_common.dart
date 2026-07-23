abstract interface class NovelStorage {
  Future<List<String>> loadProjectIds();
  Future<void> saveProjectIds(List<String> projectIds);
  Future<Map<String, Object?>?> loadProjectManifest(String projectId);
  Future<void> saveProjectManifest({
    required String projectId,
    required Map<String, Object?> manifest,
  });
  Future<void> deleteProject(String projectId);
  Future<Map<String, Object?>?> loadChapter({
    required String projectId,
    required String chapterId,
  });
  Future<void> saveChapter({
    required String projectId,
    required String chapterId,
    required Map<String, Object?> chapter,
  });
  Future<void> deleteChapter({
    required String projectId,
    required String chapterId,
  });
}
