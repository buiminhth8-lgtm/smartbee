class NovelChapter {
  const NovelChapter({
    required this.id,
    required this.novelId,
    required this.volumeId,
    required this.title,
    required this.content,
    required this.order,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
  });

  static const defaultTitle = '第一章';

  final String id;
  final String novelId;
  final String volumeId;
  final String title;
  final String content;
  final int order;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get characterCount {
    var count = 0;
    for (final rune in content.runes) {
      if (String.fromCharCode(rune).trim().isNotEmpty) {
        count++;
      }
    }
    return count;
  }

  int get paragraphCount => content
      .split(RegExp(r'\r?\n'))
      .where((paragraph) => paragraph.trim().isNotEmpty)
      .length;

  NovelChapter copyWith({
    String? id,
    String? novelId,
    String? volumeId,
    String? title,
    String? content,
    int? order,
    int? revision,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NovelChapter(
      id: id ?? this.id,
      novelId: novelId ?? this.novelId,
      volumeId: volumeId ?? this.volumeId,
      title: title ?? this.title,
      content: content ?? this.content,
      order: order ?? this.order,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 1,
    'id': id,
    'novelId': novelId,
    'volumeId': volumeId,
    'title': title,
    'content': content,
    'order': order,
    'revision': revision,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory NovelChapter.fromJson(Map<String, Object?> json) {
    return NovelChapter(
      id: json['id'] as String? ?? '',
      novelId: json['novelId'] as String? ?? '',
      volumeId: json['volumeId'] as String? ?? '',
      title: _nonEmpty(json['title'] as String?, defaultTitle),
      content: json['content'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      revision: json['revision'] as int? ?? 0,
      createdAt: _dateFromJson(json['createdAt']),
      updatedAt: _dateFromJson(json['updatedAt']),
    );
  }
}

String _nonEmpty(String? value, String fallback) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? fallback : trimmed;
}

DateTime _dateFromJson(Object? value) {
  return DateTime.tryParse(value as String? ?? '')?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
