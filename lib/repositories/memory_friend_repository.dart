import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/friend.dart';
import 'friend_repository.dart';

/// 메모리 기반 친구 저장소 구현
class MemoryFriendRepository implements FriendRepository {
  final Map<String, Friend> _friends = {};
  final _uuid = Uuid();

  // 스트림 컨트롤러를 사용하여 변경 사항 알림
  final _friendsStreamController = StreamController<List<Friend>>.broadcast();

  /// 친구 목록 변경 스트림 제공
  Stream<List<Friend>> get friendsStream => _friendsStreamController.stream;

  // 싱글톤 패턴 구현
  static final MemoryFriendRepository _instance =
      MemoryFriendRepository._internal();

  factory MemoryFriendRepository() {
    return _instance;
  }

  MemoryFriendRepository._internal() {
    // 초기 샘플 데이터 추가
    _addSampleData();
  }

  /// 샘플 데이터 추가
  void _addSampleData() {
    final sampleFriends = [
      Friend(
        id: _uuid.v4(),
        name: '김오목',
        profileImageUrl: 'https://i.pravatar.cc/150?u=1',
        zepUserId: 'kimomok',
        email: 'kimomok@example.com',
        isFavorite: true,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Friend(
        id: _uuid.v4(),
        name: '박바둑',
        profileImageUrl: 'https://i.pravatar.cc/150?u=2',
        zepUserId: 'parkbaduk',
        email: 'parkbaduk@example.com',
        isFavorite: false,
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
      Friend(
        id: _uuid.v4(),
        name: '이체스',
        profileImageUrl: 'https://i.pravatar.cc/150?u=3',
        zepUserId: 'leechess',
        phoneNumber: '010-1234-5678',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];

    for (final friend in sampleFriends) {
      _friends[friend.id] = friend;
    }

    // 스트림 업데이트
    _notifyListeners();
  }

  /// 리스너에게 변경 알림
  void _notifyListeners() {
    _friendsStreamController.add(_friends.values.toList());
  }

  @override
  Future<List<Friend>> getAllFriends() async {
    return _friends.values.toList();
  }

  @override
  Future<Friend?> getFriendById(String id) async {
    return _friends[id];
  }

  @override
  Future<List<Friend>> getFavoriteFriends() async {
    return _friends.values.where((friend) => friend.isFavorite).toList();
  }

  @override
  Future<Friend> addFriend(Friend friend) async {
    // 새 ID 생성
    final newId = friend.id.isEmpty ? _uuid.v4() : friend.id;
    final newFriend = Friend(
      id: newId,
      name: friend.name,
      profileImageUrl: friend.profileImageUrl,
      zepUserId: friend.zepUserId,
      email: friend.email,
      phoneNumber: friend.phoneNumber,
      isFavorite: friend.isFavorite,
      createdAt: DateTime.now(),
    );

    _friends[newId] = newFriend;
    _notifyListeners();

    return newFriend;
  }

  @override
  Future<Friend> updateFriend(Friend friend) async {
    if (!_friends.containsKey(friend.id)) {
      throw Exception('친구를 찾을 수 없습니다: ${friend.id}');
    }

    _friends[friend.id] = friend;
    _notifyListeners();

    return friend;
  }

  @override
  Future<void> deleteFriend(String id) async {
    _friends.remove(id);
    _notifyListeners();
  }

  @override
  Future<Friend> toggleFavorite(String id) async {
    if (!_friends.containsKey(id)) {
      throw Exception('친구를 찾을 수 없습니다: $id');
    }

    final friend = _friends[id]!;
    final updatedFriend = friend.copyWith(isFavorite: !friend.isFavorite);

    _friends[id] = updatedFriend;
    _notifyListeners();

    return updatedFriend;
  }

  @override
  Future<List<Friend>> searchFriends(String query) async {
    if (query.isEmpty) {
      return getAllFriends();
    }

    final lowerQuery = query.toLowerCase();
    return _friends.values
        .where(
          (friend) =>
              friend.name.toLowerCase().contains(lowerQuery) ||
              (friend.email?.toLowerCase().contains(lowerQuery) ?? false) ||
              (friend.zepUserId?.toLowerCase().contains(lowerQuery) ?? false) ||
              (friend.phoneNumber?.toLowerCase().contains(lowerQuery) ?? false),
        )
        .toList();
  }

  /// 리소스 해제
  void dispose() {
    _friendsStreamController.close();
  }
}
