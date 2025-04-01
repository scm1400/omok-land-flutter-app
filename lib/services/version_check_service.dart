import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_version.dart';

class VersionCheckService {
  static Future<bool> checkVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // 버전 비교 로직
      List<int> current = currentVersion.split('.').map(int.parse).toList();
      List<int> minimum =
          AppVersion.minVersion.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        if (current[i] < minimum[i]) {
          return false;
        } else if (current[i] > minimum[i]) {
          return true;
        }
      }

      return true;
    } catch (e) {
      debugPrint('버전 체크 중 오류 발생: $e');
      return true; // 오류 발생 시 업데이트 강제하지 않음
    }
  }

  static Future<void> showUpdateDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('새로운 버전이 있습니다'),
          content: const Text('앱을 사용하기 위해서는 최신 버전으로 업데이트가 필요합니다.'),
          actions: [
            TextButton(
              onPressed: () async {
                final Uri url = Uri.parse(AppVersion.storeUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: const Text('업데이트'),
            ),
          ],
        );
      },
    );
  }
}
