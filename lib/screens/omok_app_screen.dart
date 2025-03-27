import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart'; // AppColors 클래스 import

class OmokAppScreen extends StatefulWidget {
  const OmokAppScreen({super.key});

  @override
  State<OmokAppScreen> createState() => _OmokAppScreenState();
}

class _OmokAppScreenState extends State<OmokAppScreen>
    with WidgetsBindingObserver {
  late final WebViewController _controller;

  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  bool canGoBack = false;
  bool canGoForward = false;
  bool isFullScreen = false;
  bool isOffline = false;
  DateTime? lastPlayedTime;
  int playCount = 0;
  bool hasRatedApp = false;

  // 오목 앱 URL
  final String omokUrl = 'https://zep.us/@omok';

  // 사용자 통계 저장 키
  static const String _keyPlayCount = 'play_count';
  static const String _keyLastPlayed = 'last_played';
  static const String _keyHasRated = 'has_rated_app';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // 사용자 통계 로드
    _loadStats();

    // 컨트롤러 초기화
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setUserAgent(
            'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1',
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (request) {
                // 오목 게임 URL이 아닌 경우 외부 브라우저로 열기
                if (!request.url.contains('zep.us/@omok')) {
                  _launchInBrowser(request.url);
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
              onPageStarted: (url) {
                setState(() {
                  isLoading = true;
                  hasError = false;
                  isOffline = false;
                });
              },
              onPageFinished: (url) async {
                // 페이지 로드 완료 후 모바일 화면에 맞게 viewport 설정
                await _controller.runJavaScript('''
                  const meta = document.createElement('meta');
                  meta.name = 'viewport';
                  meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                  document.getElementsByTagName('head')[0].appendChild(meta);
                ''');

                // 게임 로딩 완료 시 통계 업데이트
                if (url.contains('zep.us/@omok')) {
                  _updatePlayStats();
                }

                final back = await _controller.canGoBack();
                final forward = await _controller.canGoForward();

                setState(() {
                  isLoading = false;
                  canGoBack = back;
                  canGoForward = forward;
                });

                // 앱 평가 요청
                _checkAndAskForRating();
              },
              onWebResourceError: (error) {
                setState(() {
                  hasError = true;
                  isLoading = false;
                  errorMessage = error.description;

                  // 오프라인 상태 확인
                  if (error.errorCode == -2 ||
                      error.description.contains(
                        'net::ERR_INTERNET_DISCONNECTED',
                      ) ||
                      error.description.contains(
                        'net::ERR_NAME_NOT_RESOLVED',
                      )) {
                    isOffline = true;
                  }
                });
              },
            ),
          )
          ..addJavaScriptChannel(
            'OmokApp',
            onMessageReceived: (JavaScriptMessage message) {
              // 웹 -> Flutter 통신
              _handleJsMessage(message.message);
            },
          )
          ..loadRequest(Uri.parse(omokUrl));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드로 돌아올 때 네트워크 연결 확인
      if (isOffline) {
        _checkConnection();
      }
    }
  }

  // 네트워크 연결 확인 및 페이지 새로고침
  Future<void> _checkConnection() async {
    try {
      // 인터넷 연결 확인을 위한 간단한 요청
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        setState(() {
          isOffline = false;
        });
        _controller.reload();
      }
    } on SocketException catch (_) {
      setState(() {
        isOffline = true;
      });
    }
  }

  // 웹 페이지로부터 메시지 처리
  void _handleJsMessage(String message) {
    if (message.startsWith('win:')) {
      // 이긴 경우 축하 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('축하합니다! 게임에서 승리했습니다!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (message.startsWith('lose:')) {
      // 진 경우 위로 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('아쉽네요. 다음에 다시 도전해보세요!'),
          backgroundColor: Colors.orange,
        ),
      );
    } else if (message.startsWith('share:')) {
      // 게임 공유
      final shareUrl = message.substring(6);
      _shareGame(shareUrl);
    }
  }

  // 게임 통계 로드
  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      playCount = prefs.getInt(_keyPlayCount) ?? 0;

      final lastPlayedStr = prefs.getString(_keyLastPlayed);
      lastPlayedTime =
          lastPlayedStr != null ? DateTime.parse(lastPlayedStr) : null;

      hasRatedApp = prefs.getBool(_keyHasRated) ?? false;
    });
  }

  // 게임 통계 업데이트
  Future<void> _updatePlayStats() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 마지막 플레이 타임과 현재 시간이 1시간 이상 차이나면 플레이 카운트 증가
    if (lastPlayedTime == null ||
        now.difference(lastPlayedTime!).inHours >= 1) {
      playCount++;
      await prefs.setInt(_keyPlayCount, playCount);
    }

    // 마지막 플레이 시간 업데이트
    lastPlayedTime = now;
    await prefs.setString(_keyLastPlayed, now.toIso8601String());
  }

  // 앱 평가 요청
  Future<void> _checkAndAskForRating() async {
    if (hasRatedApp || playCount < 5) return;

    // 5회 이상 플레이 했고, 평가하지 않았다면 평가 요청
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('앱이 마음에 드시나요?'),
            content: const Text('오목 앱을 평가해주시면 더 나은 서비스 제공에 도움이 됩니다.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('나중에'),
              ),
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(_keyHasRated, true);
                  setState(() {
                    hasRatedApp = true;
                  });

                  // 앱스토어/플레이스토어 URL로 이동
                  // 실제 앱 출시 시 URL 업데이트 필요
                  final storeUri = Uri.parse(
                    'https://play.google.com/store/apps/details?id=com.your.omok',
                  );
                  if (await canLaunchUrl(storeUri)) {
                    await launchUrl(
                      storeUri,
                      mode: LaunchMode.externalApplication,
                    );
                  }

                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('평가하기'),
              ),
            ],
          ),
    );
  }

  // 게임 공유 기능
  Future<void> _shareGame(String shareUrl) async {
    // 공유 기능 구현
    // 실제 Share 패키지 사용이 필요함
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('게임 공유 기능: $shareUrl')));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/image/omok_land_icon.png',
              height: 24, // 필요에 따라 크기 조정
              width: 24,
            ),
            const SizedBox(width: 8), // 이미지와 텍스트 사이 간격
            Text(
              '오목랜드',
              style: GoogleFonts.blackHanSans(
                textStyle: const TextStyle(fontSize: 22),
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading:
            canGoBack
                ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () async {
                    if (await _controller.canGoBack()) {
                      _controller.goBack();
                    }
                  },
                )
                : null,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'reload',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, color: AppColors.oceanBlue),
                        SizedBox(width: 10),
                        Text('새로고침'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'fullscreen',
                    child: Row(
                      children: [
                        Icon(Icons.fullscreen, color: AppColors.oceanBlue),
                        SizedBox(width: 10),
                        Text('전체화면'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'info',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.oceanBlue),
                        SizedBox(width: 10),
                        Text('앱 정보'),
                      ],
                    ),
                  ),
                ],
            onSelected: (value) {
              switch (value) {
                case 'reload':
                  _controller.reload();
                  break;
                case 'fullscreen':
                  setState(() {
                    isFullScreen = !isFullScreen;
                  });
                  break;
                case 'info':
                  _showAppInfo();
                  break;
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 웹뷰
          WebViewWidget(controller: _controller),

          // 로딩 인디케이터
          if (isLoading)
            Container(
              color: AppColors.skyBlue.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.woodBeige,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.coralOrange,
                              ),
                              strokeWidth: 5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '게임 로딩 중...',
                            style: GoogleFonts.nanumGothic(
                              textStyle: TextStyle(
                                color: AppColors.darkBrown,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 오프라인 상태 표시
          if (isOffline)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.woodBeige,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: AppColors.earthBrown,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            size: 50,
                            color: AppColors.darkBrown,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '인터넷 연결이 끊겼습니다',
                            style: GoogleFonts.nanumGothic(
                              textStyle: TextStyle(
                                color: AppColors.darkBrown,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '네트워크 연결을 확인해주세요',
                            style: GoogleFonts.nanumGothic(
                              textStyle: TextStyle(
                                color: AppColors.darkBrown.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _checkConnection,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('다시 시도'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 에러 상태 표시 (오프라인 상태가 아닌 경우만)
          if (hasError && !isOffline)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.woodBeige,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: AppColors.earthBrown,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 50,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '오류가 발생했습니다',
                            style: GoogleFonts.nanumGothic(
                              textStyle: TextStyle(
                                color: AppColors.darkBrown,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            errorMessage,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nanumGothic(
                              textStyle: TextStyle(
                                color: AppColors.darkBrown.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              _controller.reload();
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('다시 시도'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.woodBeige,
        indicatorColor: AppColors.coralOrange.withOpacity(0.2),
        elevation: 8,
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_on_rounded), label: '오목'),
          NavigationDestination(icon: Icon(Icons.people_rounded), label: '친구'),
          NavigationDestination(icon: Icon(Icons.chat_rounded), label: '채팅'),
        ],
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              // 이미 오목 화면이므로 아무것도 안함
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/friends');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/chats');
              break;
          }
        },
      ),
    );
  }

  /// URL 외부 브라우저 열기
  Future<void> _launchInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// 풀스크린 토글
  void _toggleFullScreen() {
    if (!isFullScreen) {
      // 숨김
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      // 복원
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    setState(() {
      isFullScreen = !isFullScreen;
    });
  }

  // 앱 정보 다이얼로그 표시
  void _showAppInfo() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.woodBeige,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.earthBrown, width: 1.5),
                  ),
                  child: Icon(
                    Icons.gamepad_rounded,
                    color: AppColors.darkBrown,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '오목랜드',
                  style: GoogleFonts.nanumGothic(
                    textStyle: TextStyle(
                      color: AppColors.darkBrown,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: AppColors.skyBlue,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoItem(
                  icon: Icons.info_outline,
                  title: '버전',
                  value: '1.0.0',
                ),
                const SizedBox(height: 8),
                _infoItem(
                  icon: Icons.person_outline,
                  title: '개발자',
                  value: '오목납치범',
                ),
                const SizedBox(height: 8),
                _infoItem(
                  icon: Icons.language,
                  title: 'Powered by ZEP',
                  value: 'https://zep.us',
                  isLink: true,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.woodBeige,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sports_esports, color: AppColors.coralOrange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '총 플레이 횟수: $playCount회',
                          style: GoogleFonts.nanumGothic(
                            textStyle: TextStyle(
                              color: AppColors.darkBrown,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('닫기'),
              ),
            ],
          ),
    );
  }

  // 정보 아이템 위젯
  Widget _infoItem({
    required IconData icon,
    required String title,
    required String value,
    bool isLink = false,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.oceanBlue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: AppColors.oceanBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.nanumGothic(
                  textStyle: TextStyle(
                    color: AppColors.darkBrown.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              if (isLink)
                InkWell(
                  onTap: () async {
                    final uri = Uri.parse(value);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: Text(
                    value,
                    style: GoogleFonts.nanumGothic(
                      textStyle: TextStyle(
                        color: AppColors.oceanBlue,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                )
              else
                Text(
                  value,
                  style: GoogleFonts.nanumGothic(
                    textStyle: TextStyle(
                      color: AppColors.darkBrown,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
