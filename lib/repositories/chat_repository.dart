import '../models/chat_message.dart';
import '../models/chat_conversation.dart';

/// 채팅 저장소 인터페이스
abstract class ChatRepository {
  /// 사용자의 모든 대화방 목록 조회
  Future<List<ChatConversation>> getConversationsForUser(String userId);

  /// 특정 대화방 조회
  Future<ChatConversation?> getConversationById(String conversationId);

  /// 두 사용자 간의 대화방 조회 (없으면 null 반환)
  Future<ChatConversation?> getConversationBetweenUsers(
    String userId1,
    String userId2,
  );

  /// 새 대화방 생성
  Future<ChatConversation> createConversation(String userId1, String userId2);

  /// 대화방의 모든 메시지 조회
  Future<List<ChatMessage>> getMessagesForConversation(String conversationId);

  /// 메시지 전송
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String text,
    String? imageUrl,
  });

  /// 메시지 읽음 처리
  Future<void> markMessagesAsRead(String conversationId, String userId);

  /// 대화방 삭제
  Future<void> deleteConversation(String conversationId);

  /// 메시지 삭제
  Future<void> deleteMessage(String messageId);

  /// 안 읽은 메시지 수 조회
  Future<int> getUnreadMessageCount(String userId);

  /// 대화방의 안 읽은 메시지 수 조회
  Future<int> getUnreadMessageCountForConversation(
    String conversationId,
    String userId,
  );

  /// 대화방의 새 메시지 스트림 제공
  Stream<List<ChatMessage>> getMessageStream(String conversationId);

  /// 사용자의 대화방 목록 스트림 제공
  Stream<List<ChatConversation>> getConversationStream(String userId);
}
