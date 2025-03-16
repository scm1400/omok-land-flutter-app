import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/zep_space.dart';
import '../services/zep_space_service.dart';

class SpaceDetailScreen extends StatefulWidget {
  final ZepSpace space;

  const SpaceDetailScreen({super.key, required this.space});

  @override
  State<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends State<SpaceDetailScreen> {
  final ZepSpaceService _spaceService = ZepSpaceService();
  late final WebViewController _controller;
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  bool isFullScreen = false;

  @override
  void initState() {
    super.initState();

    // 웹뷰 컨트롤러 초기화
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setUserAgent(
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (url) {
                setState(() {
                  isLoading = true;
                  hasError = false;
                });
              },
              onPageFinished: (url) {
                setState(() {
                  isLoading = false;
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
          ..loadRequest(Uri.parse(widget.space.spaceUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          isFullScreen
              ? null
              : AppBar(
                title: Text(widget.space.name),
                actions: [
                  IconButton(
                    icon: Icon(
                      _spaceService.isFavorite(widget.space.id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color:
                          _spaceService.isFavorite(widget.space.id)
                              ? Colors.red
                              : Colors.white,
                    ),
                    onPressed: () {
                      _spaceService.toggleFavorite(widget.space.id);
                      setState(() {});
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      _controller.reload();
                    },
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
                    Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
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
      floatingActionButton:
          isFullScreen
              ? FloatingActionButton(
                mini: true,
                backgroundColor: Colors.black.withOpacity(0.5),
                child: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                },
              )
              : null,
    );
  }

  void _toggleFullScreen() {
    setState(() {
      isFullScreen = !isFullScreen;
    });
  }
}
