import 'package:flutter/foundation.dart';

class ChatConversation {
  final String id;
  final String userId1; // 대화 참여자 1 (본인)
  final String userId2; // 대화 참여자 2 (상대방)
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessageText;
  final int unreadCount;

  ChatConversation({
    required this.id,
    required this.userId1,
    required this.userId2,
    required this.createdAt,
    this.lastMessageAt,
    this.lastMessageText,
    this.unreadCount = 0,
  });

  ChatConversation copyWith({
    DateTime? lastMessageAt,
    String? lastMessageText,
    int? unreadCount,
  }) {
    return ChatConversation(
      id: id,
      userId1: userId1,
      userId2: userId2,
      createdAt: createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as String,
      userId1: json['userId1'] as String,
      userId2: json['userId2'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastMessageAt:
          json['lastMessageAt'] != null
              ? DateTime.parse(json['lastMessageAt'] as String)
              : null,
      lastMessageText: json['lastMessageText'] as String?,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId1': userId1,
      'userId2': userId2,
      'createdAt': createdAt.toIso8601String(),
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'lastMessageText': lastMessageText,
      'unreadCount': unreadCount,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatConversation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
