import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/zep_space.dart';

class ZepSpaceService {
  static final ZepSpaceService _instance = ZepSpaceService._internal();
  factory ZepSpaceService() => _instance;

  ZepSpaceService._internal();

  static const String _spacesBoxName = 'zep_spaces';
  static const String _favoritesBoxName = 'favorites';

  late Box<String> _spacesBox;
  late Box<bool> _favoritesBox;

  List<ZepSpace> _cachedSpaces = [];

  // 개발 모드에서 샘플 데이터를 강제로 로드할지 여부
  bool _forceLoadSampleData = true;

  // 강제 로드 설정 함수
  void setForceLoadSampleData(bool force) {
    _forceLoadSampleData = force;
  }

  Future<void> init() async {
    if (!Hive.isBoxOpen(_spacesBoxName)) {
      _spacesBox = await Hive.openBox<String>(_spacesBoxName);
    } else {
      _spacesBox = Hive.box<String>(_spacesBoxName);
    }

    if (!Hive.isBoxOpen(_favoritesBoxName)) {
      _favoritesBox = await Hive.openBox<bool>(_favoritesBoxName);
    } else {
      _favoritesBox = Hive.box<bool>(_favoritesBoxName);
    }

    // 초기 데이터가 없거나 강제 로드 옵션이 켜져 있으면 샘플 데이터 로드
    if (_spacesBox.isEmpty || _forceLoadSampleData) {
      await loadSampleData();
    } else {
      _loadCachedSpaces();
    }
  }

  // 샘플 데이터 로드 함수를 public으로 변경하고 기존 데이터 삭제 옵션 추가
  Future<void> loadSampleData({bool clearExisting = true}) async {
    // 기존 데이터 삭제 옵션이 켜져 있으면 모든 데이터 삭제
    if (clearExisting) {
      await _spacesBox.clear();
    }

    final sampleSpaces = [
      ZepSpace(
        id: '1',
        name: 'ZEP 오목',
        description: 'ZEP 오목',
        thumbnailUrl:
            'https://cdn-static.zep.us/uploads/spaces/AlPRzo/thumbnail/9e2a6df927584274bfb053b05379db03/0.jpg?w=600',
        spaceUrl: 'https://zep.us/@omok',
        tags: ['공식', '오목'],
        popularity: 100,
      ),
      ZepSpace(
        id: '2',
        name: '마피아게임',
        description: '마피아게임임',
        thumbnailUrl:
            'https://cdn-static.zep.us/uploads/spaces/62XVgv/thumbnail/cb2f74fdd152475b844c053d7439c098/0.jpg?w=600',
        spaceUrl: 'https://zep.us/@mafia',
        tags: ['공식', '마피아게임'],
        popularity: 85,
      ),
      // ZepSpace(
      //   id: '3',
      //   name: '가상 오피스',
      //   description: '원격 근무를 위한 가상 오피스 공간입니다.',
      //   thumbnailUrl: 'https://zep.us/assets/images/office.png',
      //   spaceUrl: 'https://zep.us/play/office',
      //   tags: ['업무', '오피스'],
      //   popularity: 90,
      // ),
      // ZepSpace(
      //   id: '4',
      //   name: '게임 월드',
      //   description: '다양한 미니게임을 즐길 수 있는 공간입니다.',
      //   thumbnailUrl: 'https://zep.us/assets/images/game.png',
      //   spaceUrl: 'https://zep.us/play/game',
      //   tags: ['게임', '엔터테인먼트'],
      //   popularity: 95,
      // ),
      // ZepSpace(
      //   id: '5',
      //   name: '콘서트홀',
      //   description: '가상 콘서트와 이벤트를 위한 공간입니다.',
      //   thumbnailUrl: 'https://zep.us/assets/images/concert.png',
      //   spaceUrl: 'https://zep.us/play/concert',
      //   tags: ['이벤트', '콘서트'],
      //   popularity: 80,
      // ),
    ];

    for (final space in sampleSpaces) {
      await _spacesBox.put(space.id, jsonEncode(space.toJson()));
    }

    _cachedSpaces = sampleSpaces;
  }

  // 기존 private 함수는 제거하고 아래 함수로 대체
  void _loadCachedSpaces() {
    _cachedSpaces =
        _spacesBox.values
            .map((jsonStr) => ZepSpace.fromJson(jsonDecode(jsonStr)))
            .toList();
  }

  // 모든 스페이스 가져오기
  List<ZepSpace> getAllSpaces() {
    return List.from(_cachedSpaces);
  }

  // 인기 스페이스 가져오기
  List<ZepSpace> getPopularSpaces({int limit = 10}) {
    final spaces = List<ZepSpace>.from(_cachedSpaces);
    spaces.sort((a, b) => b.popularity.compareTo(a.popularity));
    return spaces.take(limit).toList();
  }

  // 태그로 스페이스 필터링
  List<ZepSpace> getSpacesByTag(String tag) {
    return _cachedSpaces
        .where((space) => space.tags.contains(tag.toLowerCase()))
        .toList();
  }

  // 검색어로 스페이스 검색
  List<ZepSpace> searchSpaces(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _cachedSpaces.where((space) {
      return space.name.toLowerCase().contains(lowercaseQuery) ||
          space.description.toLowerCase().contains(lowercaseQuery) ||
          space.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  // 즐겨찾기 추가/제거
  Future<void> toggleFavorite(String spaceId) async {
    final isFavorite = _favoritesBox.get(spaceId, defaultValue: false) ?? false;
    await _favoritesBox.put(spaceId, !isFavorite);
  }

  // 즐겨찾기 여부 확인
  bool isFavorite(String spaceId) {
    return _favoritesBox.get(spaceId, defaultValue: false) ?? false;
  }

  // 즐겨찾기 스페이스 가져오기
  List<ZepSpace> getFavoriteSpaces() {
    return _cachedSpaces
        .where(
          (space) => _favoritesBox.get(space.id, defaultValue: false) ?? false,
        )
        .toList();
  }

  // 스페이스 추가 (관리자 기능)
  Future<void> addSpace(ZepSpace space) async {
    await _spacesBox.put(space.id, jsonEncode(space.toJson()));
    _loadCachedSpaces();
  }

  // 스페이스 업데이트 (관리자 기능)
  Future<void> updateSpace(ZepSpace space) async {
    await _spacesBox.put(space.id, jsonEncode(space.toJson()));
    _loadCachedSpaces();
  }

  // 스페이스 삭제 (관리자 기능)
  Future<void> deleteSpace(String spaceId) async {
    await _spacesBox.delete(spaceId);
    _loadCachedSpaces();
  }

  // 모든 데이터 초기화
  Future<void> resetAllData() async {
    await _spacesBox.clear();
    await _favoritesBox.clear();
    _cachedSpaces = [];
  }
}
