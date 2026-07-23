import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/novel_writing_exception.dart';
import 'novel_storage_common.dart';

class NovelStorageFactory {
  const NovelStorageFactory._();

  static NovelStorage create({String? rootPath}) {
    return NovelStorageIo(rootPath: rootPath);
  }
}

class NovelStorageIo implements NovelStorage {
  NovelStorageIo({String? rootPath}) : _injectedRootPath = rootPath;

  final String? _injectedRootPath;
  Directory? _rootDirectory;

  Future<Directory> get _root async {
    final cached = _rootDirectory;
    if (cached != null) {
      return cached;
    }
    final base = _injectedRootPath == null
        ? await getApplicationDocumentsDirectory()
        : Directory(_injectedRootPath);
    final root = Directory(p.join(base.path, 'smartbee', 'novels'));
    await root.create(recursive: true);
    _rootDirectory = root;
    return root;
  }

  @override
  Future<List<String>> loadProjectIds() async {
    final file = await _indexFile();
    if (!await file.exists()) {
      return <String>[];
    }
    final json = await _readJsonWithRecovery(file);
    return ((json?['projectIds'] as List?) ?? const <Object?>[])
        .whereType<String>()
        .toList();
  }

  @override
  Future<void> saveProjectIds(List<String> projectIds) async {
    await writeJsonAtomically(await _indexFile(), <String, Object?>{
      'schemaVersion': 1,
      'projectIds': projectIds,
    });
  }

  @override
  Future<Map<String, Object?>?> loadProjectManifest(String projectId) async {
    return _readJsonWithRecovery(await _manifestFile(projectId));
  }

  @override
  Future<void> saveProjectManifest({
    required String projectId,
    required Map<String, Object?> manifest,
  }) async {
    await writeJsonAtomically(await _manifestFile(projectId), manifest);
  }

  @override
  Future<void> deleteProject(String projectId) async {
    final directory = await _projectDirectory(projectId);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  @override
  Future<Map<String, Object?>?> loadChapter({
    required String projectId,
    required String chapterId,
  }) async {
    return _readJsonWithRecovery(await _chapterFile(projectId, chapterId));
  }

  @override
  Future<void> saveChapter({
    required String projectId,
    required String chapterId,
    required Map<String, Object?> chapter,
  }) async {
    await writeJsonAtomically(
      await _chapterFile(projectId, chapterId),
      chapter,
    );
  }

  @override
  Future<void> deleteChapter({
    required String projectId,
    required String chapterId,
  }) async {
    final file = await _chapterFile(projectId, chapterId);
    for (final candidate in <File>[
      file,
      File('${file.path}.bak'),
      File('${file.path}.tmp'),
    ]) {
      if (await candidate.exists()) {
        await candidate.delete();
      }
    }
  }

  Future<File> _indexFile() async =>
      File(p.join((await _root).path, 'index.json'));

  Future<Directory> _projectDirectory(String projectId) async {
    final directory = Directory(p.join((await _root).path, projectId));
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> _manifestFile(String projectId) async {
    return File(
      p.join((await _projectDirectory(projectId)).path, 'manifest.json'),
    );
  }

  Future<File> _chapterFile(String projectId, String chapterId) async {
    final directory = Directory(
      p.join((await _projectDirectory(projectId)).path, 'chapters'),
    );
    await directory.create(recursive: true);
    return File(p.join(directory.path, '$chapterId.json'));
  }
}

Future<void> writeJsonAtomically(File target, Map<String, Object?> json) async {
  await target.parent.create(recursive: true);
  final tmp = File('${target.path}.tmp');
  final bak = File('${target.path}.bak');
  final encoded = const JsonEncoder.withIndent('  ').convert(json);

  try {
    await tmp.writeAsString(encoded, encoding: utf8, flush: true);
    jsonDecode(await tmp.readAsString(encoding: utf8));
    if (await target.exists()) {
      await target.copy(bak.path);
      await target.delete();
    }
    await tmp.rename(target.path);
  } catch (error, stackTrace) {
    debugPrint(
      '[NovelStorage] step=atomic-write-failed '
      'file=${p.basename(target.path)} errorType=${error.runtimeType} error=$error',
    );
    debugPrintStack(stackTrace: stackTrace);
    if (await bak.exists() && !await target.exists()) {
      await bak.copy(target.path);
    }
    throw NovelWritingException(
      type: NovelWritingExceptionType.saveFailed,
      message: '保存小说文件失败。',
      cause: error,
    );
  } finally {
    if (await tmp.exists()) {
      await tmp.delete();
    }
  }
}

Future<Map<String, Object?>?> _readJsonWithRecovery(File target) async {
  Future<Map<String, Object?>?> read(File file) async {
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString(encoding: utf8));
    if (decoded is! Map) {
      throw const FormatException('JSON root is not an object');
    }
    return Map<String, Object?>.from(decoded);
  }

  Object? firstError;
  StackTrace? firstStackTrace;
  final targetExists = await target.exists();

  if (targetExists) {
    try {
      return await read(target);
    } catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }
  }

  for (final candidate in <File>[
    File('${target.path}.bak'),
    File('${target.path}.tmp'),
  ]) {
    try {
      final recovered = await read(candidate);
      if (recovered != null) {
        await writeJsonAtomically(target, recovered);
        debugPrint(
          '[NovelStorage] step=recovered-from-backup file=${p.basename(target.path)}',
        );
        return recovered;
      }
    } catch (_) {
      // Try the next recovery candidate.
    }
  }

  if (!targetExists && firstError == null) {
    return null;
  }

  debugPrint(
    '[NovelStorage] step=read-failed file=${p.basename(target.path)} '
    'errorType=${firstError.runtimeType} error=$firstError',
  );
  if (firstStackTrace != null) {
    debugPrintStack(stackTrace: firstStackTrace);
  }
  throw NovelWritingException(
    type: NovelWritingExceptionType.invalidData,
    message:
        '\u5c0f\u8bf4\u6570\u636e\u6587\u4ef6\u635f\u574f\uff0c\u4e14\u5907\u4efd\u6062\u590d\u5931\u8d25\u3002',
    cause: firstError,
  );
}
