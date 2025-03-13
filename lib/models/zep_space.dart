import 'package:flutter/foundation.dart';

class ZepSpace {
  final String id;
  final String name;
  final String description;
  final String thumbnailUrl;
  final String spaceUrl;
  final List<String> tags;
  final int popularity;

  ZepSpace({
    required this.id,
    required this.name,
    required this.description,
    required this.thumbnailUrl,
    required this.spaceUrl,
    this.tags = const [],
    this.popularity = 0,
  });

  factory ZepSpace.fromJson(Map<String, dynamic> json) {
    return ZepSpace(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      spaceUrl: json['spaceUrl'] as String,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          [],
      popularity: json['popularity'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'spaceUrl': spaceUrl,
      'tags': tags,
      'popularity': popularity,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ZepSpace && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
