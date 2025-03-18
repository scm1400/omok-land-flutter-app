import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/friend.dart';
import '../repositories/friend_repository.dart';
import '../repositories/memory_friend_repository.dart';
import '../repositories/chat_repository.dart';
import '../repositories/memory_chat_repository.dart';
import 'chat_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  final FriendRepository _repository = MemoryFriendRepository();
  final ChatRepository _chatRepository = MemoryChatRepository();
  late TabController _tabController;
  String _searchQuery = '';

  // 탭 인덱스
  static const int _allFriendsTabIndex = 0;
  static const int _favoritesTabIndex = 1;

  // 현재 앱 사용자 ID
  static const String _currentUserId = 'current_user';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('친구 목록'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: '모든 친구'), Tab(text: '즐겨찾기')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: '채팅 목록',
            onPressed: () {
              Navigator.pushNamed(context, '/chats');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '친구 검색...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 모든 친구 탭
                _buildFriendList(false),
                // 즐겨찾기 탭
                _buildFriendList(true),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFriendDialog,
        tooltip: '친구 추가',
        child: const Icon(Icons.person_add),
      ),
    );
  }

  // 친구 목록 위젯 생성
  Widget _buildFriendList(bool favoritesOnly) {
    return FutureBuilder<List<Friend>>(
      future:
          _searchQuery.isNotEmpty
              ? _repository.searchFriends(_searchQuery)
              : favoritesOnly
              ? _repository.getFavoriteFriends()
              : _repository.getAllFriends(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('오류 발생: ${snapshot.error}'));
        }

        final friends = snapshot.data ?? [];

        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  favoritesOnly
                      ? '즐겨찾기한 친구가 없습니다'
                      : _searchQuery.isNotEmpty
                      ? '검색 결과가 없습니다'
                      : '친구 목록이 비어있습니다',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                if (!favoritesOnly && _searchQuery.isEmpty)
                  ElevatedButton(
                    onPressed: _showAddFriendDialog,
                    child: const Text('친구 추가하기'),
                  ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return Dismissible(
              key: Key(friend.id),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              direction: DismissDirection.endToStart,
              confirmDismiss: (direction) async {
                return await showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('친구 삭제'),
                        content: Text('${friend.name}님을 친구 목록에서 삭제하시겠습니까?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text(
                              '삭제',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                );
              },
              onDismissed: (direction) async {
                await _repository.deleteFriend(friend.id);
                setState(() {});
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${friend.name}님이 삭제되었습니다'),
                    action: SnackBarAction(
                      label: '실행 취소',
                      onPressed: () async {
                        await _repository.addFriend(friend);
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      friend.profileImageUrl != null
                          ? NetworkImage(friend.profileImageUrl!)
                          : null,
                  child:
                      friend.profileImageUrl == null
                          ? Text(friend.name.substring(0, 1))
                          : null,
                ),
                title: Text(friend.name),
                subtitle: Text(
                  [
                    if (friend.zepUserId != null) '@${friend.zepUserId}',
                    if (friend.email != null) friend.email,
                    if (friend.phoneNumber != null) friend.phoneNumber,
                  ].join(' • '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () => _startChat(friend),
                      tooltip: '채팅 시작',
                    ),
                    IconButton(
                      icon: Icon(
                        friend.isFavorite ? Icons.star : Icons.star_border,
                        color: friend.isFavorite ? Colors.amber : null,
                      ),
                      onPressed: () async {
                        await _repository.toggleFavorite(friend.id);
                        setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () => _shareContact(friend),
                    ),
                  ],
                ),
                onTap: () => _showFriendDetails(friend),
              ),
            );
          },
        );
      },
    );
  }

  // 친구 추가 다이얼로그
  Future<void> _showAddFriendDialog() async {
    final nameController = TextEditingController();
    final zepUserIdController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('친구 추가'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '이름 *',
                      hintText: '친구 이름을 입력하세요',
                    ),
                  ),
                  TextField(
                    controller: zepUserIdController,
                    decoration: const InputDecoration(
                      labelText: 'ZEP 사용자 ID',
                      hintText: '예: omok123',
                    ),
                  ),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      hintText: '예: friend@example.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: '전화번호',
                      hintText: '예: 010-1234-5678',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('이름을 입력해주세요')));
                    return;
                  }
                  Navigator.of(context).pop(true);
                },
                child: const Text('추가'),
              ),
            ],
          ),
    );

    if (result == true) {
      final newFriend = Friend(
        id: '',
        name: nameController.text.trim(),
        zepUserId:
            zepUserIdController.text.trim().isEmpty
                ? null
                : zepUserIdController.text.trim(),
        email:
            emailController.text.trim().isEmpty
                ? null
                : emailController.text.trim(),
        phoneNumber:
            phoneController.text.trim().isEmpty
                ? null
                : phoneController.text.trim(),
        createdAt: DateTime.now(),
      );

      await _repository.addFriend(newFriend);
      setState(() {});
    }
  }

  // 친구 상세 정보 및 수정 화면
  Future<void> _showFriendDetails(Friend friend) async {
    final nameController = TextEditingController(text: friend.name);
    final zepUserIdController = TextEditingController(
      text: friend.zepUserId ?? '',
    );
    final emailController = TextEditingController(text: friend.email ?? '');
    final phoneController = TextEditingController(
      text: friend.phoneNumber ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('${friend.name} 정보'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '이름 *'),
                  ),
                  TextField(
                    controller: zepUserIdController,
                    decoration: const InputDecoration(labelText: 'ZEP 사용자 ID'),
                  ),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: '이메일'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: '전화번호'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          if (friend.zepUserId != null) {
                            _inviteToOmok(friend);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ZEP 사용자 ID가 필요합니다'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.videogame_asset),
                        label: const Text('오목 초대'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _startChat(friend),
                        icon: const Icon(Icons.chat),
                        label: const Text('채팅 하기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('이름을 입력해주세요')));
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('저장'),
              ),
            ],
          ),
    );

    if (result == true) {
      final updatedFriend = friend.copyWith(
        name: nameController.text.trim(),
        zepUserId:
            zepUserIdController.text.trim().isEmpty
                ? null
                : zepUserIdController.text.trim(),
        email:
            emailController.text.trim().isEmpty
                ? null
                : emailController.text.trim(),
        phoneNumber:
            phoneController.text.trim().isEmpty
                ? null
                : phoneController.text.trim(),
      );

      await _repository.updateFriend(updatedFriend);
      setState(() {});
    }
  }

  // 친구 정보 공유
  Future<void> _shareContact(Friend friend) async {
    final text = '''
${friend.name} 연락처:
${friend.zepUserId != null ? 'ZEP ID: ${friend.zepUserId}\n' : ''}${friend.email != null ? '이메일: ${friend.email}\n' : ''}${friend.phoneNumber != null ? '전화: ${friend.phoneNumber}' : ''}
''';

    await Share.share(text.trim(), subject: '${friend.name} 연락처');
  }

  // 오목 게임 초대
  Future<void> _inviteToOmok(Friend friend) async {
    final inviteText = '''
안녕하세요, ${friend.name}님! 

오목 한 판 어떠세요? 아래 링크로 접속해주세요:
https://zep.us/@omok

- From ZEP 오목 앱
''';

    await Share.share(inviteText, subject: '오목 게임 초대');
  }

  // 친구와 채팅 시작
  Future<void> _startChat(Friend friend) async {
    // 대화방 찾기 또는 생성
    final conversation = await _chatRepository.createConversation(
      _currentUserId,
      friend.id,
    );

    if (!context.mounted) return;

    // 채팅 화면으로 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChatScreen(
              conversationId: conversation.id,
              friendId: friend.id,
            ),
      ),
    );
  }
}
