import 'package:flutter/material.dart';
import '../models/zep_space.dart';
import '../services/zep_space_service.dart';
import 'space_detail_screen.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  final ZepSpaceService _spaceService = ZepSpaceService();
  List<ZepSpace> _favoriteSpaces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
    });

    // 서비스가 초기화되지 않았을 경우를 대비
    if (_spaceService.getAllSpaces().isEmpty) {
      await _spaceService.init();
    }

    setState(() {
      _favoriteSpaces = _spaceService.getFavoriteSpaces();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('즐겨찾기')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _favoriteSpaces.isEmpty
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      '즐겨찾기한 스페이스가 없습니다.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '스페이스 상세 페이지에서 하트 아이콘을 눌러\n즐겨찾기에 추가할 수 있습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadFavorites,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _favoriteSpaces.length,
                  itemBuilder: (context, index) {
                    final space = _favoriteSpaces[index];
                    return _buildFavoriteItem(space);
                  },
                ),
              ),
    );
  }

  Widget _buildFavoriteItem(ZepSpace space) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SpaceDetailScreen(space: space),
            ),
          ).then((_) => _loadFavorites());
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일 이미지
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      space.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.error, color: Colors.red),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () {
                        _spaceService.toggleFavorite(space.id);
                        _loadFavorites();
                      },
                    ),
                  ),
                ],
              ),
            ),
            // 텍스트 정보
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    space.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    space.description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              space.tags.map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.teal[700],
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => SpaceDetailScreen(space: space),
                            ),
                          ).then((_) => _loadFavorites());
                        },
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text('입장하기'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
