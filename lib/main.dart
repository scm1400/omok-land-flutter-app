import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/splash_screen.dart';
import 'screens/omok_app_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/chat_list_screen.dart';

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

  // 상태바, 내비게이션바 컬러 설정(안드로이드)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.teal,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.teal,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZEP 오목',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.light,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/omok': (context) => const OmokAppScreen(),
        '/friends': (context) => const FriendsScreen(),
        '/chats': (context) => const ChatListScreen(),
      },
    );
  }
}
