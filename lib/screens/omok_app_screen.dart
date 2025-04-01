import 'dart:convert';
import 'dart:developer' as logger;
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  var customData = {'app': true};

  // 오목 앱 URL
  late final String omokUrl =
      'https://zep.us/@omok?customData=${jsonEncode(customData)}';

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
          // 구글 로그인 처리를 위한 WebView 설정
          ..setBackgroundColor(Colors.transparent)
          ..enableZoom(false)
          // 웹 페이지 로드 전 CSP 헤더를 처리
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (request) {
                // 구글 로그인 URL 허용
                if (request.url.contains('accounts.google.com') ||
                    request.url.contains('googleapis.com') ||
                    request.url.contains('google.com')) {
                  return NavigationDecision.navigate;
                }
                logger.log('request.url2: $request.url');
                // zep.us/@omok 링크에 항상 customData 추가
                if (request.url.contains('zep.us/@omok')) {
                  // 이미 customData가 있으면 그대로 이동
                  if (request.url.contains('customData=')) {
                    return NavigationDecision.navigate;
                  }

                  // customData가 없으면 추가하고 수동으로 로드
                  String separator = request.url.contains('?') ? '&' : '?';
                  String newUrl =
                      '${request.url}${separator}customData=${jsonEncode(customData)}';
                  // loadRequest 호출로 인한 무한 재귀를 방지하기 위해
                  // Future.microtask를 사용하여 다음 이벤트 루프에서 로드
                  Future.microtask(() {
                    _controller.loadRequest(Uri.parse(newUrl));
                  });

                  // 현재 탐색은 방지
                  return NavigationDecision.prevent;
                }

                logger.log('request.url: ${request.url}');
                // 그 외 URL은 외부 브라우저로 열기
                _launchInBrowser(request.url);
                return NavigationDecision.prevent;
              },
              onPageStarted: (url) {
                setState(() {
                  isLoading = true;
                  hasError = false;
                  isOffline = false;
                });

                // 페이지 로드 직후 CSP 관련 처리
                // _controller.runJavaScript('''
                //   // 기존 CSP 메타 태그를 통째로 제거
                //   document.querySelectorAll('meta[http-equiv="Content-Security-Policy"]').forEach(function(el) {
                //     el.parentNode.removeChild(el);
                //   });
                // ''');
              },
              onPageFinished: (url) async {
                // CSP 헤더를 완전히 재설정
                // await _controller.runJavaScript('''
                //   try {
                //     // 모든 CSP 메타 태그 제거
                //     document.querySelectorAll('meta[http-equiv="Content-Security-Policy"]').forEach(function(el) {
                //       el.parentNode.removeChild(el);
                //     });

                //     // 새로운 CSP 메타 태그 추가 - about:blank 명시적 허용
                //     const meta = document.createElement('meta');
                //     meta.httpEquiv = 'Content-Security-Policy';
                //     meta.content = "default-src * 'unsafe-inline' 'unsafe-eval' data: blob: about: about:blank; media-src * data: blob: about: about:blank; img-src * data: blob: about: about:blank; script-src * 'unsafe-inline' 'unsafe-eval' data: blob: about: about:blank; style-src * 'unsafe-inline' data: blob: about: about:blank; frame-src * data: blob: about: about:blank; connect-src * data: blob: about: about:blank;";
                //     document.head.insertBefore(meta, document.head.firstChild);

                //     // viewport 설정
                //     const viewport = document.createElement('meta');
                //     viewport.name = 'viewport';
                //     viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                //     document.head.appendChild(viewport);

                //     // 로그인 팝업 처리 - about:blank 팝업을 새 창으로 열지 않도록 설정
                //     window.open = function(url, target, features) {
                //       if (url === 'about:blank') {
                //         location.href = url;
                //         return null;
                //       }
                //       return window.originalOpen ? window.originalOpen(url, '_self', features) : null;
                //     };

                //     if (!window.originalOpen) {
                //       window.originalOpen = window.open;
                //     }

                //     // 구글 로그인 버튼 처리 - 모든 클릭 이벤트 후킹
                //     document.addEventListener('click', function(e) {
                //       const target = e.target;
                //       // 구글 로그인 버튼 찾기 시도
                //       const button = target.closest('button') || target.closest('a');
                //       if (button && (
                //           button.textContent.includes('Google') ||
                //           button.innerHTML.includes('Google') ||
                //           button.getAttribute('aria-label')?.includes('Google')
                //       )) {
                //         console.log('구글 로그인 버튼 클릭 감지');
                //         // 기본 동작 실행 (CSP 무시)
                //         setTimeout(function() {
                //           try {
                //             // 모든 CSP 제거 다시 시도
                //             document.querySelectorAll('meta[http-equiv="Content-Security-Policy"]').forEach(function(el) {
                //               el.parentNode.removeChild(el);
                //             });
                //           } catch(err) {
                //             console.error('로그인 처리 중 오류:', err);
                //           }
                //         }, 10);
                //       }
                //     }, true);

                //     // about:blank 링크 직접 처리
                //     document.querySelectorAll('a[target="_blank"]').forEach(function(link) {
                //       link.removeAttribute('target');
                //       link.setAttribute('target', '_self');
                //     });
                //   } catch (e) {
                //     console.error('CSP 설정 중 오류:', e);
                //   }
                // ''');

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
              var data = jsonDecode(message.message);
              _handleJsMessage(data);
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
        _reloadWithCustomData();
      }
    } on SocketException catch (_) {
      setState(() {
        isOffline = true;
      });
    }
  }

  // customData와 함께 페이지 다시 로드
  Future<void> _reloadWithCustomData() async {
    // 현재 URL 가져오기
    String? currentUrl = await _controller.currentUrl();

    if (currentUrl != null && currentUrl.contains('zep.us/@omok')) {
      // customData가 이미 있는지 확인하고 없으면 추가
      if (!currentUrl.contains('customData=')) {
        String separator = currentUrl.contains('?') ? '&' : '?';
        String newUrl =
            '$currentUrl${separator}customData=${jsonEncode(customData)}';
        await _controller.loadRequest(Uri.parse(newUrl));
      } else {
        // customData가 이미 있으면 기존 방식의 reload() 사용
        await _controller.reload();
      }
    } else {
      // 오목 URL이 아니면 그냥 다시 로드
      await _controller.reload();
    }
  }

  // 웹 페이지로부터 메시지 처리
  void _handleJsMessage(Map<String, dynamic> data) {
    var type = data['type'];
    if (type == 'share') {
      // 게임 공유
      final shareUrl = data['url'];
      _shareGame(shareUrl);
    } else if (type == 'test') {
      // 테스트 메시지
      final message = data['message'];
      AlertDialog(
        title: Text('테스트 메시지'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 다이얼로그 닫기
            },
            child: Text('확인'),
          ),
        ],
      );
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
              'assets/images/omok_land_icon.png',
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
                    value: 'guide',
                    child: Row(
                      children: [
                        Icon(Icons.help_outline, color: AppColors.oceanBlue),
                        SizedBox(width: 10),
                        Text('게임 가이드'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          color: AppColors.oceanBlue,
                        ),
                        SizedBox(width: 10),
                        Text('설정'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'privacy',
                    child: Row(
                      children: [
                        Icon(
                          Icons.privacy_tip_outlined,
                          color: AppColors.oceanBlue,
                        ),
                        SizedBox(width: 10),
                        Text('개인정보 처리방침'),
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
                  _reloadWithCustomData();
                  break;
                case 'fullscreen':
                  _toggleFullScreen();
                  break;
                case 'guide':
                  _showGameGuide();
                  break;
                case 'settings':
                  _showSettings();
                  break;
                case 'privacy':
                  _showPrivacyPolicy();
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
                              _reloadWithCustomData();
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

  // 게임 가이드 표시
  void _showGameGuide() {
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
                  child: Icon(Icons.help_outline, color: AppColors.darkBrown),
                ),
                const SizedBox(width: 12),
                Text(
                  '게임 가이드',
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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _guideSection(
                    title: '오목 기본 규칙',
                    content:
                        '오목은 흑백 바둑돌을 이용해 5개의 돌을 가로, 세로, 대각선으로 '
                        '연속해서 두는 사람이 이기는 게임입니다.',
                    icon: Icons.grid_on_rounded,
                  ),
                  const SizedBox(height: 16),
                  _guideSection(
                    title: '금수 규칙',
                    content:
                        '흑은 쌍삼(3-3), 쌍사(4-4), 장목(6목 이상) 등의 금수가 있습니다. '
                        '금수 자리에는 돌을 놓을 수 없습니다.',
                    icon: Icons.cancel_outlined,
                  ),
                  const SizedBox(height: 16),
                  _guideSection(
                    title: '게임 진행',
                    content:
                        '흑이 먼저 시작하며, 번갈아가며 돌을 놓습니다. '
                        '상대방의 돌을 따먹는 룰은 없습니다.',
                    icon: Icons.play_circle_outline,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('확인'),
              ),
            ],
          ),
    );
  }

  // 가이드 섹션 위젯
  Widget _guideSection({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.woodBeige,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.coralOrange, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.nanumGothic(
                  textStyle: TextStyle(
                    color: AppColors.darkBrown,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.nanumGothic(
              textStyle: TextStyle(
                color: AppColors.darkBrown.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 설정 화면 표시
  void _showSettings() {
    // 설정 옵션을 위한 상태 변수들
    bool soundEnabled = true;
    bool vibrationEnabled = true;
    bool darkModeEnabled = Theme.of(context).brightness == Brightness.dark;
    double boardSize = 15; // 기본 크기

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.woodBeige,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.earthBrown,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.settings_outlined,
                          color: AppColors.darkBrown,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '설정',
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
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _settingItem(
                          icon: Icons.volume_up_outlined,
                          title: '소리',
                          trailing: Switch(
                            value: soundEnabled,
                            activeColor: AppColors.coralOrange,
                            onChanged: (value) {
                              setState(() {
                                soundEnabled = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        _settingItem(
                          icon: Icons.vibration,
                          title: '진동',
                          trailing: Switch(
                            value: vibrationEnabled,
                            activeColor: AppColors.coralOrange,
                            onChanged: (value) {
                              setState(() {
                                vibrationEnabled = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        _settingItem(
                          icon: Icons.dark_mode_outlined,
                          title: '다크 모드',
                          trailing: Switch(
                            value: darkModeEnabled,
                            activeColor: AppColors.coralOrange,
                            onChanged: (value) {
                              setState(() {
                                darkModeEnabled = value;
                              });
                              // 실제 앱에서는 여기서 테마 변경 처리
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('취소'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // 여기서 설정 저장 처리
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('설정이 저장되었습니다'),
                            backgroundColor: AppColors.oceanBlue,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.coralOrange,
                      ),
                      child: const Text('저장'),
                    ),
                  ],
                ),
          ),
    );
  }

  // 설정 항목 위젯
  Widget _settingItem({
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.woodBeige,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
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
            child: Text(
              title,
              style: GoogleFonts.nanumGothic(
                textStyle: TextStyle(
                  color: AppColors.darkBrown,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  // 개인정보 처리방침 표시
  void _showPrivacyPolicy() {
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
                    Icons.privacy_tip_outlined,
                    color: AppColors.darkBrown,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '개인정보 처리방침',
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
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _privacySection(
                      title: '1. 수집하는 개인정보',
                      content:
                          '당사는 오목랜드 앱에서 다음과 같은 정보를 수집합니다:\n'
                          '- 플레이 통계 (게임 횟수, 마지막 플레이 시간)\n'
                          '- 기기 정보 (모델명, OS 버전)\n'
                          '온라인 기능 사용 시 ZEP 서비스를 통해 추가 정보가 수집될 수 있습니다.',
                    ),
                    const SizedBox(height: 12),
                    _privacySection(
                      title: '2. 개인정보 이용 목적',
                      content:
                          '수집된 정보는 다음 목적으로 사용됩니다:\n'
                          '- 서비스 품질 개선\n'
                          '- 앱 오류 분석 및 수정\n'
                          '- 사용자 경험 개선',
                    ),
                    const SizedBox(height: 12),
                    _privacySection(
                      title: '3. 개인정보 보유 기간',
                      content:
                          '수집된 정보는 서비스 이용 기간 동안 보관되며, '
                          '앱 삭제 시 모든 로컬 데이터는 함께 삭제됩니다.',
                    ),
                    const SizedBox(height: 12),
                    _privacySection(
                      title: '4. 제3자 제공',
                      content:
                          '당사는 수집된 개인정보를 제3자에게 제공하지 않습니다. '
                          '단, 법적 요청이 있는 경우는 예외입니다.',
                    ),
                    const SizedBox(height: 12),
                    _privacySection(
                      title: '5. 이용자 권리',
                      content:
                          '이용자는 언제든지 개인정보 삭제를 요청할 수 있으며, '
                          '이는 앱 삭제를 통해 가능합니다.',
                    ),
                    const SizedBox(height: 12),
                    _privacySection(
                      title: '6. 문의처',
                      content: '개인정보 관련 문의: scm1400@gmail.com',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('확인'),
              ),
            ],
          ),
    );
  }

  // 개인정보 처리방침 섹션 위젯
  Widget _privacySection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.nanumGothic(
            textStyle: TextStyle(
              color: AppColors.darkBrown,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.woodBeige.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            content,
            style: GoogleFonts.nanumGothic(
              textStyle: TextStyle(
                color: AppColors.darkBrown.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
