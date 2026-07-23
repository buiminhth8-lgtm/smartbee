import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../domain/novel_chapter.dart';
import '../domain/novel_project.dart';
import '../domain/novel_repository.dart';
import '../domain/novel_save_status.dart';
import '../domain/novel_volume.dart';
import '../domain/novel_writing_exception.dart';
import '../domain/novel_writing_state.dart';

class NovelWritingController extends ChangeNotifier {
  NovelWritingController({
    required NovelRepository repository,
    Duration autosaveDelay = const Duration(milliseconds: 800),
    DateTime Function()? now,
    Uuid? uuid,
  }) : this._(
         repository: repository,
         autosaveDelay: autosaveDelay,
         now: now,
         uuid: uuid,
       );

  NovelWritingController._({
    required this._repository,
    required this._autosaveDelay,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _now = now ?? (() => DateTime.now().toUtc()),
       _uuid = uuid ?? const Uuid();

  final NovelRepository _repository;
  final Duration _autosaveDelay;
  final DateTime Function() _now;
  final Uuid _uuid;

  NovelWritingState _state = NovelWritingState.initial();
  Timer? _autosaveTimer;
  bool _saveInProgress = false;
  bool _saveRequested = false;
  int _currentRevision = 0;
  int _savedRevision = 0;
  bool _disposed = false;

  NovelWritingState get state => _state;

  Future<void> loadLibrary() async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    try {
      final projects = await _repository.loadProjects();
      if (projects.isEmpty) {
        _setState(
          _state.copyWith(
            isLoading: false,
            projects: projects,
            chaptersById: <String, NovelChapter>{},
            selectedProject: null,
            selectedChapter: null,
            saveStatus: NovelSaveStatus.idle,
            hasUnsavedChanges: false,
          ),
        );
        return;
      }
      await _selectProjectWithoutFlush(projects.first, projects: projects);
    } catch (error, stackTrace) {
      debugPrint(
        '[NovelWriting] step=load-library-failed '
        'errorType=${error.runtimeType} error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: '加载小说作品失败。',
          saveStatus: NovelSaveStatus.failed,
        ),
      );
    }
  }

  Future<void> createNovel({
    required String title,
    String author = '',
    String synopsis = '',
  }) async {
    await flush();
    final project = await _repository.createProject(
      title: title,
      author: author,
      synopsis: synopsis,
    );
    final projects = await _repository.loadProjects();
    await _selectProjectWithoutFlush(project, projects: projects);
  }

  Future<void> selectNovel(String projectId) async {
    await flush();
    final projects = await _repository.loadProjects();
    final project = projects.firstWhere(
      (project) => project.id == projectId,
      orElse: () => throw const NovelWritingException(
        type: NovelWritingExceptionType.projectNotFound,
        message: '小说作品不存在。',
      ),
    );
    await _selectProjectWithoutFlush(project, projects: projects);
  }

  Future<void> renameNovel(String title) async {
    final project = _state.selectedProject;
    if (project == null) {
      return;
    }
    final updated = project.copyWith(
      title: _nonEmpty(title, NovelProject.defaultTitle),
      updatedAt: _now(),
    );
    await _repository.saveProject(updated);
    _setSelectedProject(updated);
  }

  Future<void> deleteNovel(String projectId) async {
    await flush();
    await _repository.deleteProject(projectId);
    await loadLibrary();
  }

  Future<void> createVolume(String title) async {
    await flush();
    final project = _state.selectedProject;
    if (project == null) {
      return;
    }
    final now = _now();
    final volume = NovelVolume(
      id: _uuid.v4(),
      novelId: project.id,
      title: _nonEmpty(title, NovelVolume.defaultTitle),
      order: project.volumes.length,
      chapterIds: const <String>[],
      createdAt: now,
      updatedAt: now,
    );
    final updated = project.copyWith(
      volumes: <NovelVolume>[...project.volumes, volume],
      updatedAt: now,
    );
    await _repository.saveProject(updated);
    _setSelectedProject(updated);
  }

  Future<void> renameVolume({
    required String volumeId,
    required String title,
  }) async {
    final project = _state.selectedProject;
    if (project == null) {
      return;
    }
    final now = _now();
    final volumes = project.volumes.map((volume) {
      if (volume.id != volumeId) {
        return volume;
      }
      return volume.copyWith(
        title: _nonEmpty(title, NovelVolume.defaultTitle),
        updatedAt: now,
      );
    }).toList();
    final updated = project.copyWith(volumes: volumes, updatedAt: now);
    await _repository.saveProject(updated);
    _setSelectedProject(updated);
  }

  Future<void> deleteVolume(String volumeId) async {
    await flush();
    final project = _state.selectedProject;
    if (project == null) {
      return;
    }
    if (project.volumes.length <= 1) {
      _setState(_state.copyWith(errorMessage: '至少需要保留一个分卷。'));
      return;
    }
    final volume = project.volumes.firstWhere(
      (volume) => volume.id == volumeId,
    );
    for (final chapterId in volume.chapterIds) {
      await _repository.deleteChapter(
        projectId: project.id,
        chapterId: chapterId,
      );
    }
    final updated = project.copyWith(
      volumes: project.volumes
          .where((volume) => volume.id != volumeId)
          .toList(),
      updatedAt: _now(),
      lastOpenedChapterId: null,
    );
    await _repository.saveProject(updated);
    await _selectProjectWithoutFlush(
      updated,
      projects: _replaceProject(updated),
    );
  }

  Future<void> createChapter({
    required String volumeId,
    required String title,
  }) async {
    await flush();
    final project = _state.selectedProject;
    if (project == null) {
      return;
    }
    final now = _now();
    final volume = project.volumes.firstWhere(
      (volume) => volume.id == volumeId,
    );
    final chapter = NovelChapter(
      id: _uuid.v4(),
      novelId: project.id,
      volumeId: volumeId,
      title: _nonEmpty(title, NovelChapter.defaultTitle),
      content: '',
      order: volume.chapterIds.length,
      revision: 0,
      createdAt: now,
      updatedAt: now,
    );
    final volumes = project.volumes.map((candidate) {
      if (candidate.id != volumeId) {
        return candidate;
      }
      return candidate.copyWith(
        chapterIds: <String>[...candidate.chapterIds, chapter.id],
        updatedAt: now,
      );
    }).toList();
    final updatedProject = project.copyWith(
      volumes: volumes,
      updatedAt: now,
      lastOpenedChapterId: chapter.id,
    );
    await _repository.saveProject(updatedProject);
    await _repository.saveChapter(chapter);
    final chapters = Map<String, NovelChapter>.from(_state.chaptersById)
      ..[chapter.id] = chapter;
    _setState(
      _state.copyWith(
        projects: _replaceProject(updatedProject),
        selectedProject: updatedProject,
        selectedChapter: chapter,
        chaptersById: chapters,
        saveStatus: NovelSaveStatus.saved,
        hasUnsavedChanges: false,
        lastSavedAt: DateTime.now(),
        errorMessage: null,
      ),
    );
    _resetRevision(chapter);
  }

  Future<void> selectChapter(String chapterId) async {
    await flush();
    await _selectChapterWithoutFlush(chapterId);
  }

  Future<void> renameChapter(String title) async {
    final chapter = _state.selectedChapter;
    if (chapter == null) {
      return;
    }
    _applyChapterEdit(
      chapter.copyWith(title: _nonEmpty(title, NovelChapter.defaultTitle)),
    );
  }

  void updateChapterContent(String content) {
    final chapter = _state.selectedChapter;
    if (chapter == null) {
      return;
    }
    _applyChapterEdit(chapter.copyWith(content: content));
  }

  Future<void> deleteChapter(String chapterId) async {
    await flush();
    final project = _state.selectedProject;
    if (project == null) {
      return;
    }
    final totalChapters = project.volumes.fold<int>(
      0,
      (count, volume) => count + volume.chapterIds.length,
    );
    if (totalChapters <= 1) {
      _setState(_state.copyWith(errorMessage: '至少需要保留一个章节。'));
      return;
    }
    await _repository.deleteChapter(
      projectId: project.id,
      chapterId: chapterId,
    );
    final volumes = project.volumes
        .map(
          (volume) => volume.copyWith(
            chapterIds: volume.chapterIds
                .where((id) => id != chapterId)
                .toList(),
          ),
        )
        .toList();
    final updatedProject = project.copyWith(
      volumes: volumes,
      updatedAt: _now(),
      lastOpenedChapterId: null,
    );
    await _repository.saveProject(updatedProject);
    final chapters = Map<String, NovelChapter>.from(_state.chaptersById)
      ..remove(chapterId);
    _setState(
      _state.copyWith(
        projects: _replaceProject(updatedProject),
        selectedProject: updatedProject,
        chaptersById: chapters,
        selectedChapter: null,
      ),
    );
    final nextId = _firstChapterId(updatedProject);
    if (nextId != null) {
      await _selectChapterWithoutFlush(nextId);
    }
  }

  Future<void> moveChapter({
    required String chapterId,
    required int delta,
  }) async {
    await flush();
    final project = _state.selectedProject;
    if (project == null) {
      return;
    }
    final now = _now();
    final volumes = project.volumes.map((volume) {
      final index = volume.chapterIds.indexOf(chapterId);
      if (index < 0) {
        return volume;
      }
      final newIndex = (index + delta).clamp(0, volume.chapterIds.length - 1);
      if (newIndex == index) {
        return volume;
      }
      final ids = volume.chapterIds.toList();
      final moved = ids.removeAt(index);
      ids.insert(newIndex, moved);
      return volume.copyWith(chapterIds: ids, updatedAt: now);
    }).toList();
    final updated = project.copyWith(volumes: volumes, updatedAt: now);
    await _repository.saveProject(updated);
    _setSelectedProject(updated);
  }

  Future<void> saveNow() async {
    _autosaveTimer?.cancel();
    if (_saveInProgress) {
      _saveRequested = true;
      return;
    }
    _saveInProgress = true;
    try {
      do {
        _saveRequested = false;
        final chapterSnapshot = _state.selectedChapter;
        final revisionSnapshot = _currentRevision;
        if (chapterSnapshot == null || revisionSnapshot <= _savedRevision) {
          break;
        }
        debugPrint(
          '[NovelAutosave] step=save-start '
          'chapterId=${chapterSnapshot.id} revision=$revisionSnapshot',
        );
        _setState(
          _state.copyWith(
            saveStatus: NovelSaveStatus.saving,
            errorMessage: null,
          ),
        );
        final savedChapter = chapterSnapshot.copyWith(
          revision: revisionSnapshot,
          updatedAt: _now(),
        );
        await _repository.saveChapter(savedChapter);
        _savedRevision = revisionSnapshot;
        final chapters = Map<String, NovelChapter>.from(_state.chaptersById)
          ..[savedChapter.id] = savedChapter;
        if (_state.selectedChapter?.id == savedChapter.id &&
            _currentRevision == revisionSnapshot) {
          _setState(
            _state.copyWith(
              selectedChapter: savedChapter,
              chaptersById: chapters,
              saveStatus: NovelSaveStatus.saved,
              hasUnsavedChanges: false,
              lastSavedAt: DateTime.now(),
              errorMessage: null,
            ),
          );
        } else {
          _setState(_state.copyWith(chaptersById: chapters));
        }
        debugPrint(
          '[NovelAutosave] step=save-success '
          'chapterId=${savedChapter.id} revision=$revisionSnapshot',
        );
        if (_currentRevision > _savedRevision) {
          _saveRequested = true;
        }
      } while (_saveRequested);
    } catch (error, stackTrace) {
      debugPrint(
        '[NovelAutosave] step=save-failed '
        'errorType=${error.runtimeType} error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      _setState(
        _state.copyWith(
          saveStatus: NovelSaveStatus.failed,
          hasUnsavedChanges: true,
          errorMessage: '保存失败，请重试。',
        ),
      );
      rethrow;
    } finally {
      _saveInProgress = false;
    }
  }

  Future<void> retrySave() => saveNow();

  Future<void> flush() async {
    _autosaveTimer?.cancel();
    if (_state.hasUnsavedChanges || _currentRevision > _savedRevision) {
      await saveNow();
    }
  }

  Future<void> close() async {
    _autosaveTimer?.cancel();
    try {
      await flush();
    } catch (error) {
      debugPrint(
        '[NovelAutosave] step=close-flush-failed '
        'errorType=${error.runtimeType} error=$error',
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _autosaveTimer?.cancel();
    super.dispose();
  }

  Future<void> _selectProjectWithoutFlush(
    NovelProject project, {
    List<NovelProject>? projects,
  }) async {
    final chapters = await _loadChaptersForProject(project);
    final selectedChapterId =
        project.lastOpenedChapterId ?? _firstChapterId(project);
    final selectedChapter = selectedChapterId == null
        ? null
        : chapters[selectedChapterId];
    _setState(
      _state.copyWith(
        isLoading: false,
        projects: projects ?? _replaceProject(project),
        selectedProject: project,
        selectedChapter: selectedChapter,
        chaptersById: chapters,
        saveStatus: selectedChapter == null
            ? NovelSaveStatus.idle
            : NovelSaveStatus.saved,
        hasUnsavedChanges: false,
        errorMessage: null,
      ),
    );
    if (selectedChapter != null) {
      _resetRevision(selectedChapter);
    }
  }

  Future<Map<String, NovelChapter>> _loadChaptersForProject(
    NovelProject project,
  ) async {
    final chapters = <String, NovelChapter>{};
    for (final chapterId in _allChapterIds(project)) {
      final chapter = await _repository.loadChapter(
        projectId: project.id,
        chapterId: chapterId,
      );
      if (chapter != null) {
        chapters[chapter.id] = chapter;
      }
    }
    return chapters;
  }

  Future<void> _selectChapterWithoutFlush(String chapterId) async {
    final project = _state.selectedProject;
    if (project == null) {
      return;
    }
    final chapter =
        _state.chaptersById[chapterId] ??
        await _repository.loadChapter(
          projectId: project.id,
          chapterId: chapterId,
        );
    if (chapter == null) {
      throw const NovelWritingException(
        type: NovelWritingExceptionType.chapterNotFound,
        message: '章节不存在。',
      );
    }
    final updatedProject = project.copyWith(
      lastOpenedChapterId: chapter.id,
      updatedAt: _now(),
    );
    await _repository.saveProject(updatedProject);
    final chapters = Map<String, NovelChapter>.from(_state.chaptersById)
      ..[chapter.id] = chapter;
    _setState(
      _state.copyWith(
        projects: _replaceProject(updatedProject),
        selectedProject: updatedProject,
        selectedChapter: chapter,
        chaptersById: chapters,
        saveStatus: NovelSaveStatus.saved,
        hasUnsavedChanges: false,
        errorMessage: null,
      ),
    );
    _resetRevision(chapter);
  }

  void _applyChapterEdit(NovelChapter chapter) {
    _currentRevision++;
    final updated = chapter.copyWith(
      revision: _currentRevision,
      updatedAt: _now(),
    );
    final chapters = Map<String, NovelChapter>.from(_state.chaptersById)
      ..[updated.id] = updated;
    _setState(
      _state.copyWith(
        selectedChapter: updated,
        chaptersById: chapters,
        saveStatus: NovelSaveStatus.dirty,
        hasUnsavedChanges: true,
        errorMessage: null,
      ),
    );
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    debugPrint(
      '[NovelAutosave] step=scheduled '
      'revision=$_currentRevision delayMs=${_autosaveDelay.inMilliseconds}',
    );
    _autosaveTimer = Timer(_autosaveDelay, () {
      unawaited(saveNow().catchError((_) {}));
    });
  }

  void _resetRevision(NovelChapter chapter) {
    _currentRevision = chapter.revision;
    _savedRevision = chapter.revision;
    _saveRequested = false;
  }

  List<String> _allChapterIds(NovelProject project) {
    return project.volumes.expand((volume) => volume.chapterIds).toList();
  }

  String? _firstChapterId(NovelProject project) {
    for (final volume in project.volumes) {
      if (volume.chapterIds.isNotEmpty) {
        return volume.chapterIds.first;
      }
    }
    return null;
  }

  List<NovelProject> _replaceProject(NovelProject project) {
    final projects = _state.projects.toList();
    final index = projects.indexWhere(
      (candidate) => candidate.id == project.id,
    );
    if (index >= 0) {
      projects[index] = project;
    } else {
      projects.insert(0, project);
    }
    return projects;
  }

  void _setSelectedProject(NovelProject project) {
    _setState(
      _state.copyWith(
        projects: _replaceProject(project),
        selectedProject: project,
        errorMessage: null,
      ),
    );
  }

  void _setState(NovelWritingState state) {
    _state = state;
    if (!_disposed) {
      notifyListeners();
    }
  }
}

String _nonEmpty(String value, String fallback) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}
