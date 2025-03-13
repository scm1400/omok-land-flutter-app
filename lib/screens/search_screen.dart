import 'package:flutter/material.dart';
import '../models/zep_space.dart';
import '../services/zep_space_service.dart';
import 'space_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final List<ZepSpace> spaces;

  const SearchScreen({super.key, required this.spaces});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ZepSpaceService _spaceService = ZepSpaceService();
  List<ZepSpace> _filteredSpaces = [];
  List<String> _allTags = [];
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    _filteredSpaces = widget.spaces;
    _extractAllTags();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _extractAllTags() {
    final Set<String> tags = {};
    for (final space in widget.spaces) {
      tags.addAll(space.tags);
    }
    _allTags = tags.toList()..sort();
  }

  void _filterSpaces() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty && _selectedTag == null) {
        _filteredSpaces = widget.spaces;
      } else if (query.isNotEmpty && _selectedTag == null) {
        _filteredSpaces = _spaceService.searchSpaces(query);
      } else if (query.isEmpty && _selectedTag != null) {
        _filteredSpaces = _spaceService.getSpacesByTag(_selectedTag!);
      } else {
        // 검색어와 태그 모두 적용
        _filteredSpaces =
            _spaceService
                .searchSpaces(query)
                .where((space) => space.tags.contains(_selectedTag))
                .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('스페이스 검색')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '스페이스 이름, 설명 또는 태그 검색',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        _searchController.text.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _filterSpaces();
                              },
                            )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) => _filterSpaces(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: const Text('전체'),
                          selected: _selectedTag == null,
                          onSelected: (selected) {
                            setState(() {
                              _selectedTag = null;
                              _filterSpaces();
                            });
                          },
                        ),
                      ),
                      ..._allTags.map((tag) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text('#$tag'),
                            selected: _selectedTag == tag,
                            onSelected: (selected) {
                              setState(() {
                                _selectedTag = selected ? tag : null;
                                _filterSpaces();
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _filteredSpaces.isEmpty
                    ? const Center(
                      child: Text(
                        '검색 결과가 없습니다.',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredSpaces.length,
                      itemBuilder: (context, index) {
                        final space = _filteredSpaces[index];
                        return _buildSpaceListItem(space);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpaceListItem(ZepSpace space) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SpaceDetailScreen(space: space),
            ),
          ).then((_) => setState(() {}));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  space.thumbnailUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[300],
                      child: const Icon(Icons.error, color: Colors.red),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      space.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      space.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
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
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _spaceService.isFavorite(space.id)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color:
                      _spaceService.isFavorite(space.id)
                          ? Colors.red
                          : Colors.grey,
                ),
                onPressed: () {
                  _spaceService.toggleFavorite(space.id);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
