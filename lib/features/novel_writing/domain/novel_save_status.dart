enum NovelSaveStatus { idle, dirty, saving, saved, failed }

extension NovelSaveStatusLabel on NovelSaveStatus {
  String get label => switch (this) {
    NovelSaveStatus.idle => '空闲',
    NovelSaveStatus.dirty => '有未保存修改',
    NovelSaveStatus.saving => '保存中',
    NovelSaveStatus.saved => '已保存',
    NovelSaveStatus.failed => '保存失败',
  };
}
