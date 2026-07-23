import 'novel_chapter.dart';
import 'novel_project.dart';
import 'novel_save_status.dart';

class NovelWritingState {
  NovelWritingState({
    required this.isLoading,
    required List<NovelProject> projects,
    required Map<String, NovelChapter> chaptersById,
    required this.saveStatus,
    required this.hasUnsavedChanges,
    this.selectedProject,
    this.selectedChapter,
    this.lastSavedAt,
    this.errorMessage,
  }) : projects = List.unmodifiable(projects),
       chaptersById = Map.unmodifiable(chaptersById);

  final bool isLoading;
  final List<NovelProject> projects;
  final Map<String, NovelChapter> chaptersById;
  final NovelProject? selectedProject;
  final NovelChapter? selectedChapter;
  final NovelSaveStatus saveStatus;
  final bool hasUnsavedChanges;
  final DateTime? lastSavedAt;
  final String? errorMessage;

  factory NovelWritingState.initial() {
    return NovelWritingState(
      isLoading: false,
      projects: <NovelProject>[],
      chaptersById: <String, NovelChapter>{},
      saveStatus: NovelSaveStatus.idle,
      hasUnsavedChanges: false,
    );
  }

  NovelWritingState copyWith({
    bool? isLoading,
    List<NovelProject>? projects,
    Map<String, NovelChapter>? chaptersById,
    Object? selectedProject = _unset,
    Object? selectedChapter = _unset,
    NovelSaveStatus? saveStatus,
    bool? hasUnsavedChanges,
    Object? lastSavedAt = _unset,
    Object? errorMessage = _unset,
  }) {
    return NovelWritingState(
      isLoading: isLoading ?? this.isLoading,
      projects: projects ?? this.projects,
      chaptersById: chaptersById ?? this.chaptersById,
      selectedProject: identical(selectedProject, _unset)
          ? this.selectedProject
          : selectedProject as NovelProject?,
      selectedChapter: identical(selectedChapter, _unset)
          ? this.selectedChapter
          : selectedChapter as NovelChapter?,
      saveStatus: saveStatus ?? this.saveStatus,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      lastSavedAt: identical(lastSavedAt, _unset)
          ? this.lastSavedAt
          : lastSavedAt as DateTime?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  NovelWritingState clearSelectedProject() {
    return copyWith(
      selectedProject: null,
      selectedChapter: null,
      chaptersById: <String, NovelChapter>{},
    );
  }

  NovelWritingState clearSelectedChapter() {
    return copyWith(selectedChapter: null);
  }

  NovelWritingState clearError() {
    return copyWith(errorMessage: null);
  }
}

const Object _unset = Object();
