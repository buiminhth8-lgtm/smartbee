import 'package:flutter_test/flutter_test.dart';
import 'package:smartbee/features/novel_writing/domain/novel_chapter.dart';
import 'package:smartbee/features/novel_writing/domain/novel_project.dart';
import 'package:smartbee/features/novel_writing/domain/novel_volume.dart';

void main() {
  test('NovelProject toJson/fromJson round trip keeps Chinese content', () {
    final now = DateTime.utc(2026, 1, 1);
    final volume = NovelVolume(
      id: 'volume',
      novelId: 'project',
      title: '\u7b2c\u4e00\u5377',
      order: 0,
      chapterIds: const <String>['chapter'],
      createdAt: now,
      updatedAt: now,
    );
    final project = NovelProject(
      id: 'project',
      title: '\u6d4b\u8bd5\u5c0f\u8bf4',
      author: '\u4f5c\u8005',
      synopsis: '\u7b80\u4ecb',
      createdAt: now,
      updatedAt: now,
      volumes: <NovelVolume>[volume],
      lastOpenedChapterId: 'chapter',
    );

    final restored = NovelProject.fromJson(project.toJson());

    expect(restored.title, '\u6d4b\u8bd5\u5c0f\u8bf4');
    expect(restored.volumes.single.chapterIds.single, 'chapter');
    expect(restored.createdAt, now);
  });

  test('NovelChapter statistics and json round trip', () {
    final now = DateTime.utc(2026, 1, 2);
    final chapter = NovelChapter(
      id: 'chapter',
      novelId: 'project',
      volumeId: 'volume',
      title: '\u7b2c\u4e00\u7ae0',
      content: '\u4e2d\u6587 \u6b63\u6587\n\u7b2c\u4e8c\u6bb5',
      order: 0,
      revision: 3,
      createdAt: now,
      updatedAt: now,
    );

    final restored = NovelChapter.fromJson(chapter.toJson());

    expect(restored.content, chapter.content);
    expect(restored.characterCount, 7);
    expect(restored.paragraphCount, 2);
    expect(restored.updatedAt, now);
  });
}
