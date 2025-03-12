import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebAppPage extends StatefulWidget {
  const WebAppPage({Key? key}) : super(key: key);

  @override
  State<WebAppPage> createState() => _WebAppPageState();
}

class _WebAppPageState extends State<WebAppPage> {
  late final WebViewController _controller; // 새로운 WebView 컨트롤러

  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  bool canGoBack = false;
  bool canGoForward = false;
  bool isFullScreen = false;

  final _settingsBox = Hive.box('settings');
  late String initialUrl;

  @override
  void initState() {
    super.initState();

    // 마지막 방문 기록이 있으면 사용, 없으면 기본 URL
    initialUrl = _settingsBox.get('lastUrl', defaultValue: 'https://zep.us');

    // 새로운 컨트롤러 초기화
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // 새 창 열기(target="_blank") 감지
            if (!request.isMainFrame) {
              // 외부 브라우저로 오픈
              _launchInBrowser(request.url);
              return NavigationDecision.prevent;
            }
            // iOS에서 특정 링크는 외부로 열도록
            if (_shouldOpenExternally(request.url)) {
              _launchInBrowser(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) {
            setState(() {
              isLoading = true;
              hasError = false;
            });
          },
          onPageFinished: (url) async {
            // 마지막 방문 저장
            _settingsBox.put('lastUrl', url);
            // 뒤로가기/앞으로가기 여부 체크
            final back = await _controller.canGoBack();
            final forward = await _controller.canGoForward();
            setState(() {
              isLoading = false;
              canGoBack = back;
              canGoForward = forward;
            });
          },
          onWebResourceError: (error) {
            setState(() {
              hasError = true;
              isLoading = false;
              errorMessage = error.description;
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'Flutter',
        onMessageReceived: (JavaScriptMessage message) {
          // 웹 -> Flutter ( window.Flutter.postMessage(...) )
          final msg = message.message;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('웹에서 보낸 메시지: $msg')),
          );
        },
      )
      ..loadRequest(Uri.parse(initialUrl));

    // 안드로이드에선 하드웨어 가속을 위해 필요(전 버전에선 SurfaceAndroidWebView() 등)
    // 현재는 자동으로 적용되므로, 특별히 설정하지 않아도 동작 가능
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Android 백버튼 누르면 WebView에서 뒤로가기 시도
      onWillPop: () async {
        if (await _controller.canGoBack()) {
          _controller.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: isFullScreen
            ? null
            : AppBar(
                title: const Text('Zep Browser'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: canGoBack
                        ? () async {
                            if (await _controller.canGoBack()) {
                              _controller.goBack();
                            }
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: canGoForward
                        ? () async {
                            if (await _controller.canGoForward()) {
                              _controller.goForward();
                            }
                          }
                        : null,
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
            // 새로운 API: WebViewWidget + WebViewController
            WebViewWidget(controller: _controller),
            if (isLoading)
              const Center(child: CircularProgressIndicator()),
            if (hasError)
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '네트워크 오류가 발생했습니다.',
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
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // 웹 페이지로 메시지 보내기
            _controller.runJavaScript(
              "window.postMessage('Hello from Flutter', '*');",
            );
          },
          child: const Icon(Icons.send),
        ),
      ),
    );
  }

  /// 특정 URL을 외부 브라우저로 열어야 하는지 판별
  bool _shouldOpenExternally(String url) {
    if (Platform.isIOS) {
      // 예: itunes.apple.com, apple.com/pay 등은 외부에서 열도록 처리
      if (url.contains('itunes.apple.com') ||
          (url.contains('apple.com') && url.contains('pay'))) {
        return true;
      }
    }
    return false;
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
