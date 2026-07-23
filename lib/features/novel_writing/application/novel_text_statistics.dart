class NovelTextStatistics {
  const NovelTextStatistics({
    required this.characterCount,
    required this.paragraphCount,
  });

  final int characterCount;
  final int paragraphCount;

  static NovelTextStatistics calculate(String content) {
    var characterCount = 0;
    for (final rune in content.runes) {
      if (String.fromCharCode(rune).trim().isNotEmpty) {
        characterCount++;
      }
    }

    final paragraphCount = content
        .split(RegExp(r'\r?\n'))
        .where((paragraph) => paragraph.trim().isNotEmpty)
        .length;

    return NovelTextStatistics(
      characterCount: characterCount,
      paragraphCount: paragraphCount,
    );
  }
}
