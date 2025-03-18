import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';
import '../models/friend.dart';
import '../repositories/chat_repository.dart';
import '../repositories/memory_chat_repository.dart';
import '../repositories/friend_repository.dart';
import '../repositories/memory_friend_repository.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String friendId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.friendId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatRepository _chatRepository = MemoryChatRepository();
  final FriendRepository _friendRepository = MemoryFriendRepository();

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  // 현재 앱 사용자 ID
  static const String _currentUserId = 'current_user';

  // 날짜 포맷터
  final _dateFormat = DateFormat('yyyy년 M월 d일');
  final _timeFormat = DateFormat('a h:mm');

  // 현재 친구 정보
  Friend? _friend;

  @override
  void initState() {
    super.initState();
    _loadFriend();

    // 메시지 읽음 처리
    _chatRepository.markMessagesAsRead(widget.conversationId, _currentUserId);

    // 메시지가 추가되면 자동 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Future<void> _loadFriend() async {
    final friend = await _friendRepository.getFriendById(widget.friendId);
    setState(() {
      _friend = friend;
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage:
                  _friend?.profileImageUrl != null
                      ? NetworkImage(_friend!.profileImageUrl!)
                      : null,
              child:
                  _friend?.profileImageUrl == null
                      ? Text(_friend?.name.substring(0, 1) ?? '?')
                      : null,
            ),
            const SizedBox(width: 8),
            Text(_friend?.name ?? '채팅'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videogame_asset),
            tooltip: '오목 초대',
            onPressed: () {
              _sendGameInvite();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _confirmClearChat();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(value: 'clear', child: Text('대화 내용 삭제')),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 메시지 목록
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatRepository.getMessageStream(widget.conversationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('오류 발생: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(child: Text('아직 대화 내용이 없습니다'));
                }

                // 새 메시지가 있을 때 스크롤
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == _currentUserId;

                    // 날짜 구분선 표시 로직
                    bool showDateDivider = false;
                    if (index == 0) {
                      showDateDivider = true;
                    } else {
                      final prevMessage = messages[index - 1];
                      final prevDate = DateTime(
                        prevMessage.timestamp.year,
                        prevMessage.timestamp.month,
                        prevMessage.timestamp.day,
                      );
                      final currDate = DateTime(
                        message.timestamp.year,
                        message.timestamp.month,
                        message.timestamp.day,
                      );

                      if (prevDate != currDate) {
                        showDateDivider = true;
                      }
                    }

                    return Column(
                      children: [
                        if (showDateDivider)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _dateFormat.format(message.timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        _buildMessageItem(message, isMe),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // 입력창
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo),
                  color: Colors.blue,
                  onPressed: () {
                    // 이미지 첨부 기능 (추후 구현)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('이미지 첨부 기능은 준비 중입니다')),
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: '메시지를 입력하세요',
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.teal,
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),

          // 하단 패딩 (iPhone X 이상의 안전 영역)
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message, bool isMe) {
    final bubbleColor = isMe ? Colors.teal.shade100 : Colors.grey.shade200;
    final textColor = isMe ? Colors.black87 : Colors.black87;
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage:
                  _friend?.profileImageUrl != null
                      ? NetworkImage(_friend!.profileImageUrl!)
                      : null,
              child:
                  _friend?.profileImageUrl == null
                      ? Text(
                        _friend?.name.substring(0, 1) ?? '?',
                        style: const TextStyle(fontSize: 12),
                      )
                      : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: alignment,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child:
                      message.imageUrl != null
                          ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  message.imageUrl!,
                                  width: 200,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (
                                    context,
                                    child,
                                    loadingProgress,
                                  ) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: 200,
                                      height: 150,
                                      alignment: Alignment.center,
                                      child: CircularProgressIndicator(
                                        value:
                                            loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                                : null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (message.text.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  message.text,
                                  style: TextStyle(color: textColor),
                                ),
                              ],
                            ],
                          )
                          : Text(
                            message.text,
                            style: TextStyle(color: textColor),
                          ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _timeFormat.format(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 12,
                          color: message.isRead ? Colors.blue : Colors.grey,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 24), // 오른쪽 메시지에 빈 공간 추가
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _chatRepository.sendMessage(
      conversationId: widget.conversationId,
      senderId: _currentUserId,
      receiverId: widget.friendId,
      text: text,
    );

    _messageController.clear();
  }

  void _sendGameInvite() {
    final inviteText = '''
안녕하세요, ${_friend?.name ?? '친구'}님! 

오목 한 판 어떠세요? 아래 링크로 접속해주세요:
https://zep.us/@omok

- From ZEP 오목 앱
''';

    _chatRepository.sendMessage(
      conversationId: widget.conversationId,
      senderId: _currentUserId,
      receiverId: widget.friendId,
      text: inviteText,
    );
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('대화 내용 삭제'),
            content: const Text('모든 대화 내용을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _chatRepository.deleteConversation(widget.conversationId);
                  Navigator.pop(context); // 채팅 화면 닫기
                },
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}
