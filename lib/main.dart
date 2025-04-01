import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'screens/splash_screen.dart';
import 'screens/omok_app_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/chat_list_screen.dart';
import 'services/version_check_service.dart';
import 'config/app_version.dart';

// 앱 컬러 팔레트 상수 정의
class AppColors {
  // 기본 배경색 - Sky Blue #AEE2FF
  static const Color skyBlue = Color(0xFFAEE2FF);

  // 강조 배경 - Ocean Blue #57C4E5
  static const Color oceanBlue = Color(0xFF57C4E5);

  // 섬 배경 - Grass Green #A7D676
  static const Color grassGreen = Color(0xFFA7D676);

  // 섬 테두리 - Earth Brown #C49B6C
  static const Color earthBrown = Color(0xFFC49B6C);

  // 오목판 - Wood Beige #EBC99A
  static const Color woodBeige = Color(0xFFEBC99A);

  // 오목돌 (흑) - Charcoal #3B3B3B
  static const Color charcoal = Color(0xFF3B3B3B);

  // 오목돌 (백) - Off White #F6F6F6
  static const Color offWhite = Color(0xFFF6F6F6);

  // 포인트 컬러 - Coral Orange #FFA764
  static const Color coralOrange = Color(0xFFFFA764);

  // 텍스트 (기본) - Dark Brown #4B3A2F
  static const Color darkBrown = Color(0xFF4B3A2F);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // intl 패키지 로케일 데이터 초기화
  await initializeDateFormatting('ko_KR', null);
  Intl.defaultLocale = 'ko_KR';

  // Hive 초기화
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox<String>('zep_spaces');
  await Hive.openBox<bool>('favorites');

  // 버전 체크
  bool isLatestVersion = await VersionCheckService.checkVersion();

  // 상태바, 내비게이션바 컬러 설정(안드로이드)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.oceanBlue,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.skyBlue,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(MyApp(isLatestVersion: isLatestVersion));
}

class MyApp extends StatelessWidget {
  final bool isLatestVersion;

  const MyApp({super.key, required this.isLatestVersion});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '오목랜드',
      theme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.oceanBlue,
          onPrimary: Colors.white,
          secondary: AppColors.coralOrange,
          onSecondary: Colors.white,
          error: Colors.redAccent,
          onError: Colors.white,
          surface: AppColors.woodBeige,
          onSurface: AppColors.darkBrown,
        ),
        scaffoldBackgroundColor: AppColors.skyBlue,
        textTheme: GoogleFonts.nanumGothicTextTheme(
          Theme.of(context).textTheme.apply(
            bodyColor: AppColors.darkBrown,
            displayColor: AppColors.darkBrown,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.oceanBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'NanumGothic',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardTheme(
          color: AppColors.woodBeige,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.coralOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
            textStyle: const TextStyle(
              fontFamily: 'NanumGothic',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.oceanBlue,
            side: const BorderSide(color: AppColors.oceanBlue, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontFamily: 'NanumGothic',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.coralOrange,
            textStyle: const TextStyle(
              fontFamily: 'NanumGothic',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.oceanBlue, width: 2),
          ),
          labelStyle: TextStyle(color: AppColors.darkBrown.withOpacity(0.7)),
          hintStyle: TextStyle(color: AppColors.darkBrown.withOpacity(0.5)),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.dark,
          primary: AppColors.oceanBlue,
          onPrimary: Colors.white,
          secondary: AppColors.coralOrange,
          onSecondary: Colors.white,
          error: Colors.redAccent,
          onError: Colors.white,
          surface: AppColors.charcoal.withOpacity(0.8),
          onSurface: AppColors.offWhite,
        ),
        scaffoldBackgroundColor: AppColors.charcoal,
        textTheme: GoogleFonts.nanumGothicTextTheme(
          Theme.of(context).textTheme.apply(
            bodyColor: AppColors.offWhite,
            displayColor: AppColors.offWhite,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.oceanBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'NanumGothic',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardTheme(
          color: AppColors.charcoal.withOpacity(0.8),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.coralOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
            textStyle: const TextStyle(
              fontFamily: 'NanumGothic',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.oceanBlue,
            side: const BorderSide(color: AppColors.oceanBlue, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontFamily: 'NanumGothic',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.coralOrange,
            textStyle: const TextStyle(
              fontFamily: 'NanumGothic',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.charcoal.withOpacity(0.6),
          contentPadding: const EdgeInsets.all(12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.oceanBlue, width: 2),
          ),
          labelStyle: TextStyle(color: AppColors.offWhite.withOpacity(0.7)),
          hintStyle: TextStyle(color: AppColors.offWhite.withOpacity(0.5)),
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/':
            (context) =>
                isLatestVersion
                    ? const SplashScreen()
                    : const UpdateRequiredScreen(),
        '/omok': (context) => const OmokAppScreen(),
        '/friends': (context) => const FriendsScreen(),
        '/chats': (context) => const ChatListScreen(),
      },
    );
  }
}

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.system_update,
              size: 64,
              color: AppColors.oceanBlue,
            ),
            const SizedBox(height: 16),
            Text(
              '새로운 버전이 있습니다',
              style: GoogleFonts.nanumGothic(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '앱을 사용하기 위해서는 최신 버전으로 업데이트가 필요합니다.',
              style: GoogleFonts.nanumGothic(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final Uri url = Uri.parse(AppVersion.storeUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: const Text('업데이트하기'),
            ),
          ],
        ),
      ),
    );
  }
}
