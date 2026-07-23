import 'package:flutter_test/flutter_test.dart';
import 'package:smartbee/features/novel_writing/application/novel_writing_controller.dart';
import 'package:smartbee/features/novel_writing/domain/novel_save_status.dart';

import '../fakes.dart';

void main() {
  test('正文修改后进入dirty并自动保存最后版本', () async {
    final repository = FakeNovelRepository();
    final controller = NovelWritingController(
      repository: repository,
      autosaveDelay: const Duration(milliseconds: 10),
    );
    await controller.createNovel(title: '测试小说');

    controller.updateChapterContent('第一版');
    controller.updateChapterContent('最终版本');

    expect(controller.state.saveStatus, NovelSaveStatus.dirty);
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(repository.saveChapterCount, 1);
    expect(controller.state.selectedChapter!.content, '最终版本');
    expect(controller.state.saveStatus, NovelSaveStatus.saved);
    expect(controller.state.hasUnsavedChanges, isFalse);

    controller.dispose();
  });

  test('保存失败后保留正文和dirty状态，retrySave可恢复', () async {
    final repository = FakeNovelRepository();
    final controller = NovelWritingController(
      repository: repository,
      autosaveDelay: const Duration(minutes: 1),
    );
    await controller.createNovel(title: '失败小说');
    repository.failNextSave = true;

    controller.updateChapterContent('不能丢的正文');
    await expectLater(controller.saveNow(), throwsStateError);

    expect(controller.state.saveStatus, NovelSaveStatus.failed);
    expect(controller.state.hasUnsavedChanges, isTrue);
    expect(controller.state.selectedChapter!.content, '不能丢的正文');

    await controller.retrySave();

    expect(controller.state.saveStatus, NovelSaveStatus.saved);
    expect(
      repository.chapters[controller.state.selectedChapter!.id]!.content,
      '不能丢的正文',
    );
    controller.dispose();
  });

  test('切换章节前会flush，保存失败时不切换', () async {
    final repository = FakeNovelRepository();
    final controller = NovelWritingController(
      repository: repository,
      autosaveDelay: const Duration(minutes: 1),
    );
    await controller.createNovel(title: '切换小说');
    final project = controller.state.selectedProject!;
    await controller.createChapter(
      volumeId: project.volumes.first.id,
      title: '第二章',
    );
    final secondChapterId = controller.state.selectedChapter!.id;
    final firstChapterId = project.volumes.first.chapterIds.first;

    controller.updateChapterContent('会保存失败');
    repository.failNextSave = true;
    await expectLater(
      controller.selectChapter(firstChapterId),
      throwsStateError,
    );

    expect(controller.state.selectedChapter!.id, secondChapterId);
    expect(controller.state.saveStatus, NovelSaveStatus.failed);

    await controller.retrySave();
    await controller.selectChapter(firstChapterId);
    expect(controller.state.selectedChapter!.id, firstChapterId);
    controller.dispose();
  });
}
