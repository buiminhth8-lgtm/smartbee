import 'novel_volume.dart';

class NovelProject {
  NovelProject({
    required this.id,
    required this.title,
    required this.author,
    required this.synopsis,
    required this.createdAt,
    required this.updatedAt,
    required List<NovelVolume> volumes,
    this.lastOpenedChapterId,
  }) : volumes = List.unmodifiable(volumes);

  static const defaultTitle = '未命名作品';

  final String id;
  final String title;
  final String author;
  final String synopsis;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<NovelVolume> volumes;
  final String? lastOpenedChapterId;

  NovelProject copyWith({
    String? id,
    String? title,
    String? author,
    String? synopsis,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<NovelVolume>? volumes,
    Object? lastOpenedChapterId = _unset,
  }) {
    return NovelProject(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      synopsis: synopsis ?? this.synopsis,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      volumes: volumes ?? this.volumes,
      lastOpenedChapterId: identical(lastOpenedChapterId, _unset)
          ? this.lastOpenedChapterId
          : lastOpenedChapterId as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 1,
    'id': id,
    'title': title,
    'author': author,
    'synopsis': synopsis,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'lastOpenedChapterId': lastOpenedChapterId,
    'volumes': volumes.map((volume) => volume.toJson()).toList(),
  };

  factory NovelProject.fromJson(Map<String, Object?> json) {
    return NovelProject(
      id: json['id'] as String? ?? '',
      title: _nonEmpty(json['title'] as String?, defaultTitle),
      author: json['author'] as String? ?? '',
      synopsis: json['synopsis'] as String? ?? '',
      createdAt: _dateFromJson(json['createdAt']),
      updatedAt: _dateFromJson(json['updatedAt']),
      lastOpenedChapterId: json['lastOpenedChapterId'] as String?,
      volumes: ((json['volumes'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map(
            (volume) => NovelVolume.fromJson(Map<String, Object?>.from(volume)),
          )
          .toList(),
    );
  }
}

const Object _unset = Object();

String _nonEmpty(String? value, String fallback) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? fallback : trimmed;
}

DateTime _dateFromJson(Object? value) {
  return DateTime.tryParse(value as String? ?? '')?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
