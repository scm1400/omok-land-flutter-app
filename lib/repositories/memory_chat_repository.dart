import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/chat_conversation.dart';
import 'chat_repository.dart';

/// 메모리 기반 채팅 저장소 구현
class MemoryChatRepository implements ChatRepository {
  final Map<String, ChatConversation> _conversations = {};
  final Map<String, List<ChatMessage>> _messages = {};
  final _uuid = Uuid();

  // 스트림 컨트롤러들
  final Map<String, StreamController<List<ChatMessage>>>
  _messageStreamControllers = {};
  final Map<String, StreamController<List<ChatConversation>>>
  _conversationStreamControllers = {};

  // 싱글톤 패턴 구현
  static final MemoryChatRepository _instance =
      MemoryChatRepository._internal();

  factory MemoryChatRepository() {
    return _instance;
  }

  MemoryChatRepository._internal() {
    // 초기 샘플 데이터 추가
    _addSampleData();
  }

  /// 샘플 데이터 추가
  void _addSampleData() {
    // 현재 유저 ID (앱 사용자)
    const myUserId = 'current_user';

    // 샘플 대화방 1 (김오목과의 대화)
    final conversation1Id = _uuid.v4();
    final conversation1 = ChatConversation(
      id: conversation1Id,
      userId1: myUserId,
      userId2: 'friend1', // 김오목의 ID
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
      lastMessageText: '오목 한 판 어때요?',
      unreadCount: 1,
    );

    // 샘플 대화방 2 (박바둑과의 대화)
    final conversation2Id = _uuid.v4();
    final conversation2 = ChatConversation(
      id: conversation2Id,
      userId1: myUserId,
      userId2: 'friend2', // 박바둑의 ID
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      lastMessageAt: DateTime.now().subtract(const Duration(days: 1)),
      lastMessageText: '어제 고마웠어요!',
      unreadCount: 0,
    );

    // 대화방 등록
    _conversations[conversation1Id] = conversation1;
    _conversations[conversation2Id] = conversation2;

    // 샘플 메시지들 - 김오목과의 대화
    final messages1 = [
      ChatMessage(
        id: _uuid.v4(),
        senderId: myUserId,
        receiverId: 'friend1',
        text: '안녕하세요, 김오목님!',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
        isRead: true,
      ),
      ChatMessage(
        id: _uuid.v4(),
        senderId: 'friend1',
        receiverId: myUserId,
        text: '안녕하세요! 오목 앱은 잘 사용 중이신가요?',
        timestamp: DateTime.now().subtract(
          const Duration(days: 1, hours: 2, minutes: 30),
        ),
        isRead: true,
      ),
      ChatMessage(
        id: _uuid.v4(),
        senderId: myUserId,
        receiverId: 'friend1',
        text: '네, 정말 재밌게 사용하고 있어요. 인터페이스가 직관적이라 좋네요.',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        isRead: true,
      ),
      ChatMessage(
        id: _uuid.v4(),
        senderId: 'friend1',
        receiverId: myUserId,
        text: '오목 한 판 어때요?',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: false,
      ),
    ];

    // 샘플 메시지들 - 박바둑과의 대화
    final messages2 = [
      ChatMessage(
        id: _uuid.v4(),
        senderId: 'friend2',
        receiverId: myUserId,
        text: '오목 앱 추천해줘서 고마워요!',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        isRead: true,
      ),
      ChatMessage(
        id: _uuid.v4(),
        senderId: myUserId,
        receiverId: 'friend2',
        text: '별말씀을요. 같이 게임해요 언제든지!',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 12)),
        isRead: true,
      ),
      ChatMessage(
        id: _uuid.v4(),
        senderId: 'friend2',
        receiverId: myUserId,
        text: '어제 고마웠어요!',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isRead: true,
      ),
    ];

    // 메시지 등록
    _messages[conversation1Id] = messages1;
    _messages[conversation2Id] = messages2;
  }

  /// 대화방 목록 스트림 컨트롤러 가져오기 (없으면 생성)
  StreamController<List<ChatConversation>> _getConversationStreamController(
    String userId,
  ) {
    if (!_conversationStreamControllers.containsKey(userId)) {
      _conversationStreamControllers[userId] =
          StreamController<List<ChatConversation>>.broadcast();
    }
    return _conversationStreamControllers[userId]!;
  }

  /// 메시지 스트림 컨트롤러 가져오기 (없으면 생성)
  StreamController<List<ChatMessage>> _getMessageStreamController(
    String conversationId,
  ) {
    if (!_messageStreamControllers.containsKey(conversationId)) {
      _messageStreamControllers[conversationId] =
          StreamController<List<ChatMessage>>.broadcast();
    }
    return _messageStreamControllers[conversationId]!;
  }

  /// 대화방 목록 변경을 구독자에게 알림
  void _notifyConversationListeners(String userId) {
    final conversations = getConversationsForUser(userId);
    conversations.then((list) {
      if (_conversationStreamControllers.containsKey(userId)) {
        _conversationStreamControllers[userId]!.add(list);
      }
    });
  }

  /// 메시지 목록 변경을 구독자에게 알림
  void _notifyMessageListeners(String conversationId) {
    final messages = getMessagesForConversation(conversationId);
    messages.then((list) {
      if (_messageStreamControllers.containsKey(conversationId)) {
        _messageStreamControllers[conversationId]!.add(list);
      }
    });
  }

  @override
  Future<List<ChatConversation>> getConversationsForUser(String userId) async {
    return _conversations.values
        .where(
          (conversation) =>
              conversation.userId1 == userId || conversation.userId2 == userId,
        )
        .toList()
      // 마지막 메시지 시간 기준 내림차순 정렬
      ..sort(
        (a, b) => (b.lastMessageAt ?? b.createdAt).compareTo(
          a.lastMessageAt ?? a.createdAt,
        ),
      );
  }

  @override
  Future<ChatConversation?> getConversationById(String conversationId) async {
    return _conversations[conversationId];
  }

  @override
  Future<ChatConversation?> getConversationBetweenUsers(
    String userId1,
    String userId2,
  ) async {
    try {
      return _conversations.values.firstWhere(
        (conversation) =>
            (conversation.userId1 == userId1 &&
                conversation.userId2 == userId2) ||
            (conversation.userId1 == userId2 &&
                conversation.userId2 == userId1),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<ChatConversation> createConversation(
    String userId1,
    String userId2,
  ) async {
    // 이미 존재하는 대화방이 있는지 확인
    final existingConversation = await getConversationBetweenUsers(
      userId1,
      userId2,
    );
    if (existingConversation != null) {
      return existingConversation;
    }

    // 새로운 대화방 생성
    final id = _uuid.v4();
    final conversation = ChatConversation(
      id: id,
      userId1: userId1,
      userId2: userId2,
      createdAt: DateTime.now(),
    );

    _conversations[id] = conversation;
    _messages[id] = []; // 빈 메시지 리스트 초기화

    // 변경 사항 알림
    _notifyConversationListeners(userId1);
    _notifyConversationListeners(userId2);

    return conversation;
  }

  @override
  Future<List<ChatMessage>> getMessagesForConversation(
    String conversationId,
  ) async {
    final messages = _messages[conversationId] ?? [];
    // 시간순 정렬 (오래된 메시지가 위에 오도록)
    return List.from(messages)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String text,
    String? imageUrl,
  }) async {
    // 대화방이 존재하는지 확인
    if (!_conversations.containsKey(conversationId)) {
      throw Exception('대화방을 찾을 수 없습니다: $conversationId');
    }

    // 새 메시지 생성
    final message = ChatMessage(
      id: _uuid.v4(),
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      timestamp: DateTime.now(),
      imageUrl: imageUrl,
    );

    // 메시지 저장
    if (!_messages.containsKey(conversationId)) {
      _messages[conversationId] = [];
    }
    _messages[conversationId]!.add(message);

    // 대화방 정보 업데이트
    final conversation = _conversations[conversationId]!;
    _conversations[conversationId] = conversation.copyWith(
      lastMessageAt: message.timestamp,
      lastMessageText: text,
      unreadCount: conversation.unreadCount + 1,
    );

    // 변경 사항 알림
    _notifyMessageListeners(conversationId);
    _notifyConversationListeners(senderId);
    _notifyConversationListeners(receiverId);

    return message;
  }

  @override
  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    // 대화방이 존재하는지 확인
    if (!_conversations.containsKey(conversationId)) {
      throw Exception('대화방을 찾을 수 없습니다: $conversationId');
    }

    final conversation = _conversations[conversationId]!;

    // 현재 사용자가 수신자인 메시지만 읽음 처리
    final updatedMessages = <ChatMessage>[];
    var unreadCount = 0;

    for (final message in _messages[conversationId] ?? []) {
      if (message.receiverId == userId && !message.isRead) {
        // 읽음 표시로 업데이트
        updatedMessages.add(message.copyWith(isRead: true));
      } else {
        updatedMessages.add(message);
        // 안 읽은 메시지 수 계산
        if (message.receiverId == userId && !message.isRead) {
          unreadCount++;
        }
      }
    }

    // 메시지 업데이트
    _messages[conversationId] = updatedMessages;

    // 대화방 읽지 않은 메시지 수 업데이트
    if (conversation.userId1 == userId || conversation.userId2 == userId) {
      _conversations[conversationId] = conversation.copyWith(
        unreadCount: unreadCount,
      );
    }

    // 변경 사항 알림
    _notifyMessageListeners(conversationId);
    _notifyConversationListeners(userId);

    final otherUserId =
        conversation.userId1 == userId
            ? conversation.userId2
            : conversation.userId1;
    _notifyConversationListeners(otherUserId);
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    // 대화방이 존재하는지 확인
    if (!_conversations.containsKey(conversationId)) {
      throw Exception('대화방을 찾을 수 없습니다: $conversationId');
    }

    final conversation = _conversations[conversationId]!;

    // 대화방 및 메시지 삭제
    _conversations.remove(conversationId);
    _messages.remove(conversationId);

    // 변경 사항 알림
    _notifyConversationListeners(conversation.userId1);
    _notifyConversationListeners(conversation.userId2);

    // 스트림 컨트롤러 정리
    if (_messageStreamControllers.containsKey(conversationId)) {
      _messageStreamControllers[conversationId]!.add([]);
    }
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    // 모든 대화방에서 메시지 찾기
    for (final conversationId in _messages.keys) {
      final index = _messages[conversationId]!.indexWhere(
        (message) => message.id == messageId,
      );

      if (index != -1) {
        // 메시지 삭제
        final messages = List<ChatMessage>.from(_messages[conversationId]!);
        final deletedMessage = messages.removeAt(index);
        _messages[conversationId] = messages;

        // 마지막 메시지였다면 대화방 정보 업데이트
        final conversation = _conversations[conversationId]!;
        final lastMessage =
            messages.isNotEmpty
                ? messages.reduce(
                  (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
                )
                : null;

        if (lastMessage != null) {
          _conversations[conversationId] = conversation.copyWith(
            lastMessageAt: lastMessage.timestamp,
            lastMessageText: lastMessage.text,
          );
        } else {
          _conversations[conversationId] = conversation.copyWith(
            lastMessageAt: null,
            lastMessageText: null,
          );
        }

        // 읽지 않은 메시지 수 업데이트
        if (!deletedMessage.isRead &&
            (conversation.userId1 == deletedMessage.receiverId ||
                conversation.userId2 == deletedMessage.receiverId)) {
          final newUnreadCount = conversation.unreadCount - 1;
          _conversations[conversationId] = _conversations[conversationId]!
              .copyWith(unreadCount: newUnreadCount >= 0 ? newUnreadCount : 0);
        }

        // 변경 사항 알림
        _notifyMessageListeners(conversationId);
        _notifyConversationListeners(conversation.userId1);
        _notifyConversationListeners(conversation.userId2);

        break;
      }
    }
  }

  @override
  Future<int> getUnreadMessageCount(String userId) async {
    int total = 0;

    for (final conversation in _conversations.values) {
      if (conversation.userId1 == userId || conversation.userId2 == userId) {
        // 해당 사용자의 대화방마다 안 읽은 메시지 수를 더함
        final messagesInConversation = _messages[conversation.id] ?? [];

        for (final message in messagesInConversation) {
          if (message.receiverId == userId && !message.isRead) {
            total++;
          }
        }
      }
    }

    return total;
  }

  @override
  Future<int> getUnreadMessageCountForConversation(
    String conversationId,
    String userId,
  ) async {
    if (!_conversations.containsKey(conversationId)) {
      return 0;
    }

    int count = 0;
    final messagesInConversation = _messages[conversationId] ?? [];

    for (final message in messagesInConversation) {
      if (message.receiverId == userId && !message.isRead) {
        count++;
      }
    }

    return count;
  }

  @override
  Stream<List<ChatMessage>> getMessageStream(String conversationId) {
    final controller = _getMessageStreamController(conversationId);

    // 초기 데이터 전달
    getMessagesForConversation(conversationId).then((messages) {
      controller.add(messages);
    });

    return controller.stream;
  }

  @override
  Stream<List<ChatConversation>> getConversationStream(String userId) {
    final controller = _getConversationStreamController(userId);

    // 초기 데이터 전달
    getConversationsForUser(userId).then((conversations) {
      controller.add(conversations);
    });

    return controller.stream;
  }

  /// 리소스 해제
  void dispose() {
    for (final controller in _messageStreamControllers.values) {
      controller.close();
    }
    for (final controller in _conversationStreamControllers.values) {
      controller.close();
    }
  }
}
