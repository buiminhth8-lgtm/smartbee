import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/novel_writing_exception.dart';
import 'novel_storage_common.dart';

class NovelStorageFactory {
  const NovelStorageFactory._();

  static NovelStorage create({String? rootPath}) => NovelStorageWeb();
}

class NovelStorageWeb implements NovelStorage {
  static const _indexKey = 'novel_writing.index';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<List<String>> loadProjectIds() async {
    final value = (await _preferences).getString(_indexKey);
    if (value == null || value.isEmpty) {
      return <String>[];
    }
    final decoded = jsonDecode(value) as Map<String, Object?>;
    return ((decoded['projectIds'] as List?) ?? const <Object?>[])
        .whereType<String>()
        .toList();
  }

  @override
  Future<void> saveProjectIds(List<String> projectIds) {
    return _setJson(_indexKey, <String, Object?>{
      'schemaVersion': 1,
      'projectIds': projectIds,
    });
  }

  @override
  Future<Map<String, Object?>?> loadProjectManifest(String projectId) {
    return _getJson('novel_writing.project.$projectId');
  }

  @override
  Future<void> saveProjectManifest({
    required String projectId,
    required Map<String, Object?> manifest,
  }) {
    return _setJson('novel_writing.project.$projectId', manifest);
  }

  @override
  Future<void> deleteProject(String projectId) async {
    final preferences = await _preferences;
    for (final key in preferences.getKeys().where(
      (key) => key.startsWith('novel_writing.chapter.$projectId.'),
    )) {
      await preferences.remove(key);
    }
    await preferences.remove('novel_writing.project.$projectId');
    final ids = await loadProjectIds();
    await saveProjectIds(ids.where((id) => id != projectId).toList());
  }

  @override
  Future<Map<String, Object?>?> loadChapter({
    required String projectId,
    required String chapterId,
  }) {
    return _getJson('novel_writing.chapter.$projectId.$chapterId');
  }

  @override
  Future<void> saveChapter({
    required String projectId,
    required String chapterId,
    required Map<String, Object?> chapter,
  }) async {
    final encoded = jsonEncode(chapter);
    if (encoded.length > 512 * 1024) {
      debugPrint(
        '[NovelStorage] step=web-large-chapter chapterId=$chapterId '
        'charLength=${encoded.length}',
      );
    }
    await _setString('novel_writing.chapter.$projectId.$chapterId', encoded);
  }

  @override
  Future<void> deleteChapter({
    required String projectId,
    required String chapterId,
  }) async {
    await (await _preferences).remove(
      'novel_writing.chapter.$projectId.$chapterId',
    );
  }

  Future<Map<String, Object?>?> _getJson(String key) async {
    final value = (await _preferences).getString(key);
    if (value == null || value.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const NovelWritingException(
        type: NovelWritingExceptionType.invalidData,
        message: '小说本地数据格式错误。',
      );
    }
    return Map<String, Object?>.from(decoded);
  }

  Future<void> _setJson(String key, Map<String, Object?> value) {
    return _setString(key, jsonEncode(value));
  }

  Future<void> _setString(String key, String value) async {
    final success = await (await _preferences).setString(key, value);
    if (!success) {
      throw const NovelWritingException(
        type: NovelWritingExceptionType.saveFailed,
        message: '保存浏览器本地小说数据失败。',
      );
    }
  }
}
