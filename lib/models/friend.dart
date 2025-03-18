import 'package:flutter/foundation.dart';

class Friend {
  final String id;
  final String name;
  final String? profileImageUrl;
  final String? zepUserId;
  final String? email;
  final String? phoneNumber;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime? lastContactedAt;

  Friend({
    required this.id,
    required this.name,
    this.profileImageUrl,
    this.zepUserId,
    this.email,
    this.phoneNumber,
    this.isFavorite = false,
    required this.createdAt,
    this.lastContactedAt,
  });

  Friend copyWith({
    String? name,
    String? profileImageUrl,
    String? zepUserId,
    String? email,
    String? phoneNumber,
    bool? isFavorite,
    DateTime? lastContactedAt,
  }) {
    return Friend(
      id: id,
      name: name ?? this.name,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      zepUserId: zepUserId ?? this.zepUserId,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
      lastContactedAt: lastContactedAt ?? this.lastContactedAt,
    );
  }

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] as String,
      name: json['name'] as String,
      profileImageUrl: json['profileImageUrl'] as String?,
      zepUserId: json['zepUserId'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastContactedAt:
          json['lastContactedAt'] != null
              ? DateTime.parse(json['lastContactedAt'] as String)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profileImageUrl': profileImageUrl,
      'zepUserId': zepUserId,
      'email': email,
      'phoneNumber': phoneNumber,
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
      'lastContactedAt': lastContactedAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Friend && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
