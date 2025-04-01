import 'dart:io';
import 'package:path/path.dart' as path;

void main() async {
  // app_version.dart 파일 읽기
  final appVersionFile = File('lib/config/app_version.dart');
  if (!await appVersionFile.exists()) {
    print('app_version.dart 파일을 찾을 수 없습니다.');
    exit(1);
  }

  final content = await appVersionFile.readAsString();

  // 버전과 빌드 번호 추출
  final versionMatch = RegExp(r"version = '([^']+)'").firstMatch(content);
  final buildNumberMatch = RegExp(r"buildNumber = (\d+)").firstMatch(content);

  if (versionMatch == null || buildNumberMatch == null) {
    print('버전 정보를 찾을 수 없습니다.');
    exit(1);
  }

  final version = versionMatch.group(1)!;
  final buildNumber = buildNumberMatch.group(1)!;
  final fullVersion = '$version+$buildNumber';

  // pubspec.yaml 업데이트
  final pubspecFile = File('pubspec.yaml');
  if (!await pubspecFile.exists()) {
    print('pubspec.yaml 파일을 찾을 수 없습니다.');
    exit(1);
  }

  var pubspecContent = await pubspecFile.readAsString();
  pubspecContent = pubspecContent.replaceFirst(
    RegExp(r'version: [^\n]+'),
    'version: $fullVersion',
  );
  await pubspecFile.writeAsString(pubspecContent);

  // android/local.properties 업데이트
  final localPropertiesFile = File('android/local.properties');
  if (!await localPropertiesFile.exists()) {
    print('android/local.properties 파일을 찾을 수 없습니다.');
    exit(1);
  }

  var localPropertiesContent = await localPropertiesFile.readAsString();

  // 버전 정보가 이미 있는지 확인
  if (!localPropertiesContent.contains('flutter.versionName=')) {
    localPropertiesContent += '\nflutter.versionName=$version';
  } else {
    localPropertiesContent = localPropertiesContent.replaceFirst(
      RegExp(r'flutter\.versionName=[^\n]+'),
      'flutter.versionName=$version',
    );
  }

  if (!localPropertiesContent.contains('flutter.versionCode=')) {
    localPropertiesContent += '\nflutter.versionCode=$buildNumber';
  } else {
    localPropertiesContent = localPropertiesContent.replaceFirst(
      RegExp(r'flutter\.versionCode=[^\n]+'),
      'flutter.versionCode=$buildNumber',
    );
  }

  await localPropertiesFile.writeAsString(localPropertiesContent);

  print('버전이 성공적으로 업데이트되었습니다:');
  print('버전: $version');
  print('빌드 번호: $buildNumber');
  print('전체 버전: $fullVersion');
  print('\n업데이트된 파일:');
  print('- lib/config/app_version.dart');
  print('- pubspec.yaml');
  print('- android/local.properties');
}
