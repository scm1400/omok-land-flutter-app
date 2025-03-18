import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_conversation.dart';
import '../models/friend.dart';
import '../repositories/chat_repository.dart';
import '../repositories/memory_chat_repository.dart';
import '../repositories/friend_repository.dart';
import '../repositories/memory_friend_repository.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatRepository _chatRepository = MemoryChatRepository();
  final FriendRepository _friendRepository = MemoryFriendRepository();

  // 현재 앱 사용자 ID
  static const String _currentUserId = 'current_user';

  // 이름 포맷터
  final _nameFormat = DateFormat('M월 d일');
  final _timeFormat = DateFormat('a h:mm');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // 검색 기능 (추후 구현)
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ChatConversation>>(
        stream: _chatRepository.getConversationStream(_currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('오류 발생: ${snapshot.error}'));
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text('채팅 내역이 없습니다', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/friends');
                    },
                    child: const Text('친구와 채팅하기'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];

              // 대화 상대방 ID
              final otherUserId =
                  conversation.userId1 == _currentUserId
                      ? conversation.userId2
                      : conversation.userId1;

              return FutureBuilder<Friend?>(
                future: _friendRepository.getFriendById(otherUserId),
                builder: (context, friendSnapshot) {
                  if (friendSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const ListTile(
                      leading: CircularProgressIndicator(),
                      title: Text('로딩 중...'),
                    );
                  }

                  final friend = friendSnapshot.data;
                  final name = friend?.name ?? '알 수 없는 사용자';

                  // 마지막 메시지 시간
                  final lastTime =
                      conversation.lastMessageAt ?? conversation.createdAt;
                  String timeText;

                  final now = DateTime.now();
                  if (now.difference(lastTime).inDays > 0) {
                    timeText = _nameFormat.format(lastTime);
                  } else {
                    timeText = _timeFormat.format(lastTime);
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          friend?.profileImageUrl != null
                              ? NetworkImage(friend!.profileImageUrl!)
                              : null,
                      child:
                          friend?.profileImageUrl == null
                              ? Text(name.substring(0, 1))
                              : null,
                    ),
                    title: Text(name),
                    subtitle: Text(
                      conversation.lastMessageText ?? '새로운 채팅방',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        if (conversation.unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              conversation.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => ChatScreen(
                                conversationId: conversation.id,
                                friendId: otherUserId,
                              ),
                        ),
                      );
                    },
                    onLongPress: () {
                      _showConversationOptions(conversation);
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/friends');
        },
        tooltip: '새 채팅',
        child: const Icon(Icons.chat),
      ),
    );
  }

  void _showConversationOptions(ChatConversation conversation) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('채팅방 삭제'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteConversation(conversation);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_off),
                  title: const Text('알림 끄기'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('알림이 꺼졌습니다')));
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _confirmDeleteConversation(ChatConversation conversation) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('채팅방 삭제'),
            content: const Text('이 채팅방을 삭제하시겠습니까? 모든 메시지가 삭제됩니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _chatRepository.deleteConversation(conversation.id);
                },
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}
