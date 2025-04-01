class AppVersion {
  static const String version = '1.0.6';
  static const int buildNumber = 6;

  static String get fullVersion => '$version+$buildNumber';

  // 최소 필수 버전
  static const String minVersion = version;

  // 스토어 URL
  static const String storeUrl =
      'https://play.google.com/store/apps/details?id=com.omokland.app';
}
