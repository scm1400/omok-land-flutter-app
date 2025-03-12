// lib/services/hive_service.dart

import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  /// 싱글턴 패턴으로 인스턴스를 공유하는 예시
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;

  HiveService._internal();

  // 앱 내부에서 사용할 Box 이름
  static const String _settingsBoxName = 'settings';

  /// Box 인스턴스 가져오기
  Future<Box> get settingsBox async {
    if (!Hive.isBoxOpen(_settingsBoxName)) {
      return await Hive.openBox(_settingsBoxName);
    } else {
      return Hive.box(_settingsBoxName);
    }
  }

  /// 키-값 저장 (Create/Update)
  Future<void> putData({required String key, required dynamic value}) async {
    final box = await settingsBox;
    await box.put(key, value);
  }

  /// 키로 데이터 가져오기 (Read)
  Future<T?> getData<T>({required String key, T? defaultValue}) async {
    final box = await settingsBox;
    return box.get(key, defaultValue: defaultValue);
  }

  /// 모든 키-값 가져오기 (예시)
  Future<Map<dynamic, dynamic>> getAllData() async {
    final box = await settingsBox;
    return Map<dynamic, dynamic>.from(box.toMap());
  }

  /// 특정 키 삭제 (Delete)
  Future<void> deleteData({required String key}) async {
    final box = await settingsBox;
    await box.delete(key);
  }

  /// Box 전체 비우기 (주의: 전부 삭제!)
  Future<void> clearAll() async {
    final box = await settingsBox;
    await box.clear();
  }

  /// Box 닫기
  Future<void> closeBox() async {
    final box = await settingsBox;
    await box.close();
  }
}
