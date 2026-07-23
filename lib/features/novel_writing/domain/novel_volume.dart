class NovelVolume {
  NovelVolume({
    required this.id,
    required this.novelId,
    required this.title,
    required this.order,
    required List<String> chapterIds,
    required this.createdAt,
    required this.updatedAt,
  }) : chapterIds = List.unmodifiable(chapterIds);

  static const defaultTitle = '第一卷';

  final String id;
  final String novelId;
  final String title;
  final int order;
  final List<String> chapterIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  NovelVolume copyWith({
    String? id,
    String? novelId,
    String? title,
    int? order,
    List<String>? chapterIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NovelVolume(
      id: id ?? this.id,
      novelId: novelId ?? this.novelId,
      title: title ?? this.title,
      order: order ?? this.order,
      chapterIds: chapterIds ?? this.chapterIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 1,
    'id': id,
    'novelId': novelId,
    'title': title,
    'order': order,
    'chapterIds': chapterIds,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory NovelVolume.fromJson(Map<String, Object?> json) {
    return NovelVolume(
      id: json['id'] as String? ?? '',
      novelId: json['novelId'] as String? ?? '',
      title: _nonEmpty(json['title'] as String?, defaultTitle),
      order: json['order'] as int? ?? 0,
      chapterIds: ((json['chapterIds'] as List?) ?? const <Object?>[])
          .whereType<String>()
          .toList(),
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
