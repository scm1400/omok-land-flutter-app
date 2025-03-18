import '../models/friend.dart';

/// 친구 저장소 인터페이스
abstract class FriendRepository {
  /// 모든 친구 목록 조회
  Future<List<Friend>> getAllFriends();

  /// 특정 친구 조회
  Future<Friend?> getFriendById(String id);

  /// 즐겨찾기된 친구 목록 조회
  Future<List<Friend>> getFavoriteFriends();

  /// 친구 추가
  Future<Friend> addFriend(Friend friend);

  /// 친구 수정
  Future<Friend> updateFriend(Friend friend);

  /// 친구 삭제
  Future<void> deleteFriend(String id);

  /// 친구 즐겨찾기 상태 토글
  Future<Friend> toggleFavorite(String id);

  /// 친구 검색 (이름 기준)
  Future<List<Friend>> searchFriends(String query);
}
