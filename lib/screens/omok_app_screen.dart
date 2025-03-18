import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
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
    return WillPopScope(
      onWillPop: () async {
        if (await _controller.canGoBack()) {
          _controller.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar:
            isFullScreen
                ? null
                : AppBar(
                  title: const Text('ZEP 오목'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.chat),
                      tooltip: '채팅',
                      onPressed: () => Navigator.pushNamed(context, '/chats'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => _controller.reload(),
                    ),
                    IconButton(
                      icon: Icon(
                        isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      ),
                      onPressed: _toggleFullScreen,
                    ),
                  ],
                ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (isLoading) const Center(child: CircularProgressIndicator()),
            if (isOffline)
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        '인터넷 연결이 끊어졌습니다',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '인터넷 연결을 확인하고 다시 시도해주세요',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          _checkConnection();
                        },
                        child: const Text('재시도'),
                      ),
                    ],
                  ),
                ),
              ),
            if (hasError && !isOffline)
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '오류가 발생했습니다',
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            hasError = false;
                            isLoading = true;
                          });
                          _controller.reload();
                        },
                        child: const Text('재시도'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'chat_button',
              onPressed: () {
                Navigator.pushNamed(context, '/chats');
              },
              mini: true,
              tooltip: '채팅 목록',
              child: const Icon(Icons.chat),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              heroTag: 'friends_button',
              onPressed: () {
                Navigator.pushNamed(context, '/friends');
              },
              tooltip: '친구 목록',
              child: const Icon(Icons.people),
            ),
          ],
        ),
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
}
