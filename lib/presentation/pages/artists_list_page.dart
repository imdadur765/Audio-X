import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_x/data/models/song_model.dart';
import 'package:audio_x/data/models/cached_spotify_artist.dart';
import 'package:audio_x/data/services/spotify_cache_service.dart';
import 'package:audio_x/presentation/controllers/audio_controller.dart';
import 'package:audio_x/presentation/pages/artist_page.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ArtistsListPage extends StatefulWidget {
  const ArtistsListPage({super.key});

  @override
  State<ArtistsListPage> createState() => _ArtistsListPageState();
}

class _ArtistsListPageState extends State<ArtistsListPage> {
  final SpotifyCacheService _cacheService = SpotifyCacheService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late Box<String> _searchHistoryBox;

  final bool _isPreloading = false;
  bool _isOnline = true;
  String _searchQuery = '';
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchHistoryBox = Hive.box<String>('searchHistory');
    _searchFocusNode.addListener(_onFocusChange);
    _checkConnectivity();
  }

  void _onFocusChange() {
    setState(() {
      _isSearchFocused = _searchFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _addToHistory(String query) {
    if (query.trim().isEmpty) return;
    final cleanQuery = query.trim();

    // Remove if exists to avoid duplicates (move to top)
    final existingKeys = _searchHistoryBox
        .toMap()
        .entries
        .where((e) => e.value == cleanQuery)
        .map((e) => e.key)
        .toList();

    for (final key in existingKeys) {
      _searchHistoryBox.delete(key);
    }

    _searchHistoryBox.add(cleanQuery);
  }

  void _removeFromHistory(int index) {
    _searchHistoryBox.deleteAt(index);
    setState(() {});
  }

  void _clearHistory() {
    _searchHistoryBox.clear();
    setState(() {});
  }

  Future<void> _checkConnectivity() async {
    // Simple check - will fail if no internet
    try {
      await _cacheService.getOrFetchArtist('test');
      setState(() {
        _isOnline = true;
      });
    } catch (_) {
      setState(() {
        _isOnline = false;
      });
    }
  }

  List<MapEntry<String, List<Song>>> _filterArtists(Map<String, List<Song>> artistsMap) {
    final artists = artistsMap.entries.toList()..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    if (_searchQuery.isEmpty) {
      return artists;
    }

    return artists.where((entry) => entry.key.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Intercept back button if search is active or focused
    final bool canPop = !(_isSearchFocused || _searchQuery.isNotEmpty);

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        setState(() {
          if (_isSearchFocused) {
            _searchFocusNode.unfocus();
          }
          if (_searchQuery.isNotEmpty) {
            _searchController.clear();
            _searchQuery = '';
          }
        });
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: CustomScrollView(
          slivers: [
            // Custom App Bar
            SliverAppBar(
              expandedHeight: 140,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.black.withOpacity(0.1),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.deepPurple.shade50, Colors.blue.shade50],
                    ),
                  ),
                ),
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.deepPurple, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Artists',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const Spacer(),
                    if (_isPreloading)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                        ],
                      ),
                      child: Icon(
                        _isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                        color: _isOnline ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),

            // Search Bar
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Search artists...',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.deepPurple),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: Colors.grey.shade600),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    onSubmitted: (value) {
                      _addToHistory(value);
                    },
                  ),
                ),
              ),
            ),

            // Offline Banner
            if (!_isOnline)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.shade100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.orange.shade100, shape: BoxShape.circle),
                          child: Icon(Icons.wifi_off_rounded, size: 20, color: Colors.orange.shade800),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Offline Mode',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange.shade900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Connect to internet to get Spotify artist data',
                                style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Content
            Consumer<AudioController>(
              builder: (context, controller, child) {
                if (controller.songs.isEmpty) {
                  return _buildEmptyState();
                }

                // Show History if focused and query is empty
                if (_isSearchFocused && _searchQuery.isEmpty && _searchHistoryBox.isNotEmpty) {
                  return _buildSearchHistory();
                }

                // Group songs by artist
                final artistsMap = <String, List<Song>>{};
                for (final song in controller.songs) {
                  final artistName = song.artist.trim().isEmpty ? 'Unknown Artist' : song.artist;
                  artistsMap.putIfAbsent(artistName, () => []).add(song);
                }

                final filteredArtists = _filterArtists(artistsMap);

                if (filteredArtists.isEmpty) {
                  return _buildNoResultsState();
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final entry = filteredArtists[index];
                      final artistName = entry.key;
                      final songs = entry.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ArtistCardWithImage(
                          artistName: artistName,
                          songs: songs,
                          cacheService: _cacheService,
                          isOnline: _isOnline,
                        ),
                      );
                    }, childCount: filteredArtists.length),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHistory() {
    final history = _searchHistoryBox.values.toList().reversed.toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Searches',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
                  ),
                  TextButton(
                    onPressed: _clearHistory,
                    style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
                    child: const Text('Clear All'),
                  ),
                ],
              ),
            );
          }

          final queryIndex = index - 1;
          if (queryIndex >= history.length) return null;

          final query = history[queryIndex];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.deepPurple.shade50, shape: BoxShape.circle),
                child: Icon(Icons.history_rounded, color: Colors.deepPurple, size: 20),
              ),
              title: Text(query, style: const TextStyle(fontWeight: FontWeight.w500)),
              trailing: IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade600),
                onPressed: () => _removeFromHistory(history.length - 1 - queryIndex),
              ),
              onTap: () {
                setState(() {
                  _searchController.text = query;
                  _searchQuery = query;
                  _searchFocusNode.unfocus();
                });
                _addToHistory(query);
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }, childCount: history.length + 1),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(color: Colors.deepPurple.shade50, shape: BoxShape.circle),
                child: Icon(Icons.search_off_rounded, size: 50, color: Colors.deepPurple.shade300),
              ),
              const SizedBox(height: 24),
              Text(
                'No Artists Found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text('Try a different search term', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(color: Colors.deepPurple.shade50, shape: BoxShape.circle),
                child: Icon(Icons.person_outline_rounded, size: 70, color: Colors.deepPurple.shade300),
              ),
              const SizedBox(height: 24),
              Text(
                'No Artists Found',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Text(
                'Add some music to see your artists',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.deepPurple.shade400, Colors.purple.shade600]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      // You can add navigation to music library here
                    },
                    child: const Center(
                      child: Text(
                        'Browse Music',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Artist card with cached Spotify image
class _ArtistCardWithImage extends StatefulWidget {
  final String artistName;
  final List<Song> songs;
  final SpotifyCacheService cacheService;
  final bool isOnline;

  const _ArtistCardWithImage({
    required this.artistName,
    required this.songs,
    required this.cacheService,
    required this.isOnline,
  });

  @override
  State<_ArtistCardWithImage> createState() => _ArtistCardWithImageState();
}

class _ArtistCardWithImageState extends State<_ArtistCardWithImage> {
  CachedSpotifyArtist? _cachedData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    // First try cache only (instant)
    final cached = await widget.cacheService.getCachedOnly(widget.artistName);
    if (cached != null && mounted) {
      setState(() {
        _cachedData = cached;
      });
    }

    // DISABLED: Auto-fetch causes ANR during scroll
    // Only load from cache, no new API calls during list rendering
    // if (widget.isOnline && (cached == null || cached.isExpired)) {
    //   _fetchFreshData();
    // }
  }

  Future<void> _fetchFreshData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final freshData = await widget.cacheService.getOrFetchArtist(widget.artistName);
      if (freshData != null && mounted) {
        setState(() {
          _cachedData = freshData;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    ArtistPage(artistName: widget.artistName, localSongs: widget.songs, cachedSpotifyData: _cachedData),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Artist Image
                _buildLeadingImage(),

                const SizedBox(width: 16),

                // Artist Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.artistName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.songs.length} ${widget.songs.length == 1 ? 'song' : 'songs'}',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                // Spotify Verified Badge (if available)
                if (_cachedData != null && _cachedData!.imageUrl != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, size: 12, color: Colors.green.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(width: 12),

                // Chevron
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingImage() {
    return Stack(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.deepPurple.shade100,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: _cachedData?.imageUrl != null
                ? Image.network(
                    _cachedData!.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildPlaceholderImage();
                    },
                  )
                : _buildPlaceholderImage(),
          ),
        ),

        // Loading Indicator
        if (_isLoading)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(15)),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple.shade400, Colors.purple.shade600],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Center(child: Icon(Icons.person_rounded, color: Colors.white, size: 28)),
    );
  }
}
