enum NovelWritingExceptionType {
  storageUnavailable,
  projectNotFound,
  chapterNotFound,
  invalidData,
  saveFailed,
  deleteFailed,
}

class NovelWritingException implements Exception {
  const NovelWritingException({
    required this.type,
    required this.message,
    this.cause,
  });

  final NovelWritingExceptionType type;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
