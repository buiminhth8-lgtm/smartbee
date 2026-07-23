import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:smartbee/features/novel_writing/infrastructure/local_novel_repository.dart';
import 'package:smartbee/features/novel_writing/infrastructure/storage/novel_storage_io.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('smartbee_novel_test_');
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('creates a novel and reloads Chinese chapter content', () async {
    final storage = NovelStorageIo(rootPath: temp.path);
    final repository = LocalNovelRepository(storage: storage);
    final project = await repository.createProject(
      title: '\u6d4b\u8bd5\u5c0f\u8bf4',
    );
    final chapterId = project.volumes.single.chapterIds.single;
    final chapter = await repository.loadChapter(
      projectId: project.id,
      chapterId: chapterId,
    );

    await repository.saveChapter(
      chapter!.copyWith(
        content: '\u8fd9\u662f\u4e00\u6bb5\u4e2d\u6587\u6b63\u6587\u3002',
        revision: 1,
      ),
    );

    final reloaded = LocalNovelRepository(
      storage: NovelStorageIo(rootPath: temp.path),
    );
    final projects = await reloaded.loadProjects();
    final restored = await reloaded.loadChapter(
      projectId: project.id,
      chapterId: chapterId,
    );

    expect(projects.single.title, '\u6d4b\u8bd5\u5c0f\u8bf4');
    expect(projects.single.volumes.single.title, '\u7b2c\u4e00\u5377');
    expect(
      restored!.content,
      '\u8fd9\u662f\u4e00\u6bb5\u4e2d\u6587\u6b63\u6587\u3002',
    );
  });

  test('recovers a broken chapter file from bak', () async {
    final repository = LocalNovelRepository(
      storage: NovelStorageIo(rootPath: temp.path),
    );
    final project = await repository.createProject(
      title: '\u5907\u4efd\u5c0f\u8bf4',
    );
    final chapterId = project.volumes.single.chapterIds.single;
    final chapter = await repository.loadChapter(
      projectId: project.id,
      chapterId: chapterId,
    );
    await repository.saveChapter(
      chapter!.copyWith(content: '\u5907\u4efd\u5185\u5bb9', revision: 1),
    );
    await repository.saveChapter(
      chapter.copyWith(content: '\u65b0\u5185\u5bb9', revision: 2),
    );

    final chapterFile = File(
      p.join(
        temp.path,
        'smartbee',
        'novels',
        project.id,
        'chapters',
        '$chapterId.json',
      ),
    );
    await chapterFile.writeAsString('{broken json', flush: true);

    final restored = await repository.loadChapter(
      projectId: project.id,
      chapterId: chapterId,
    );

    expect(restored!.content, '\u5907\u4efd\u5185\u5bb9');
  });

  test('recovers a missing chapter file from tmp', () async {
    final repository = LocalNovelRepository(
      storage: NovelStorageIo(rootPath: temp.path),
    );
    final project = await repository.createProject(
      title: '\u4e34\u65f6\u6062\u590d\u5c0f\u8bf4',
    );
    final chapterId = project.volumes.single.chapterIds.single;
    final chapter = await repository.loadChapter(
      projectId: project.id,
      chapterId: chapterId,
    );
    final chapterFile = File(
      p.join(
        temp.path,
        'smartbee',
        'novels',
        project.id,
        'chapters',
        '$chapterId.json',
      ),
    );
    final recovered = chapter!.copyWith(
      content: '\u4e34\u65f6\u6587\u4ef6\u6b63\u6587',
      revision: 9,
    );

    await chapterFile.delete();
    await File('${chapterFile.path}.tmp').writeAsString(
      const JsonEncoder.withIndent('  ').convert(recovered.toJson()),
      flush: true,
    );

    final restored = await repository.loadChapter(
      projectId: project.id,
      chapterId: chapterId,
    );

    expect(restored!.content, '\u4e34\u65f6\u6587\u4ef6\u6b63\u6587');
    expect(await chapterFile.exists(), isTrue);
  });

  test('deletes a chapter and a novel', () async {
    final repository = LocalNovelRepository(
      storage: NovelStorageIo(rootPath: temp.path),
    );
    final project = await repository.createProject(
      title: '\u5220\u9664\u5c0f\u8bf4',
    );
    final chapterId = project.volumes.single.chapterIds.single;

    await repository.deleteChapter(projectId: project.id, chapterId: chapterId);
    expect(
      await repository.loadChapter(projectId: project.id, chapterId: chapterId),
      isNull,
    );

    await repository.deleteProject(project.id);
    expect(await repository.loadProjects(), isEmpty);
  });
}
