import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../../data/models/search_history_model.dart';
import '../../data/services/artist_service.dart';
import '../controllers/audio_controller.dart';
import '../../data/models/artist_model.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final Box<SearchHistory> _historyBox = Hive.box<SearchHistory>('search_history');
  final ArtistService _artistService = ArtistService();

  List<String> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final controller = Provider.of<AudioController>(context, listen: false);
    final allArtists = controller.songs.map((s) => s.artist).toSet().toList();

    final results = allArtists.where((artist) => artist.toLowerCase().contains(query.toLowerCase())).toList();

    setState(() {
      _searchResults = results;
    });
  }

  void _saveToHistory(String query) {
    if (query.trim().isEmpty) return;

    // Check if exists and delete to move to top
    final existingKey = _historyBox.values
        .firstWhere(
          (element) => element.query.toLowerCase() == query.toLowerCase(),
          orElse: () => SearchHistory(query: '', timestamp: DateTime(0)),
        )
        .key;

    if (existingKey != null) {
      _historyBox.delete(existingKey);
    }

    _historyBox.add(SearchHistory(query: query, timestamp: DateTime.now()));
  }

  void _onResultTap(String artistName) {
    _saveToHistory(artistName);
    context.pushNamed('artist_details', pathParameters: {'name': artistName}, extra: 'search_$artistName');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 24, height: 24),
          onPressed: () => context.pop(),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: const InputDecoration(
            hintText: 'Search artists...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          style: const TextStyle(fontSize: 18),
          onChanged: _performSearch,
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _saveToHistory(value);
            }
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _searchController.clear();
                _performSearch('');
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _searchController.text.isEmpty ? _buildRecentSearches() : _buildSearchResults(),
    );
  }

  Widget _buildRecentSearches() {
    return ValueListenableBuilder(
      valueListenable: _historyBox.listenable(),
      builder: (context, Box<SearchHistory> box, _) {
        final history = box.values.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No recent searches', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Searches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton(onPressed: () => box.clear(), child: const Text('Clear All')),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  return ListTile(
                    leading: const Icon(Icons.history_rounded, color: Colors.grey),
                    title: Text(item.query),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                      onPressed: () => item.delete(),
                    ),
                    onTap: () {
                      _searchController.text = item.query;
                      _performSearch(item.query);
                      _focusNode.unfocus();
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No artists found', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final artistName = _searchResults[index];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.deepPurple,
            child: Icon(Icons.person, color: Colors.white),
          ),
          title: Text(artistName),
          onTap: () => _onResultTap(artistName),
        );
      },
    );
  }
}
