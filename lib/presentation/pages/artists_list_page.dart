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

  bool _isPreloading = false;
  bool _isOnline = true;
  String _searchQuery = '';
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchHistoryBox = Hive.box<String>('searchHistory');
    _searchFocusNode.addListener(_onFocusChange);
    _preloadArtistData();
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

  Future<void> _preloadArtistData() async {
    if (_isPreloading) return;

    setState(() {
      _isPreloading = true;
    });

    try {
      final controller = Provider.of<AudioController>(context, listen: false);
      final artistsMap = <String, List<Song>>{};

      for (final song in controller.songs) {
        final artistName = song.artist.trim().isEmpty ? 'Unknown Artist' : song.artist;
        artistsMap.putIfAbsent(artistName, () => []).add(song);
      }

      // Preload Spotify data for all artists
      await _cacheService.preloadArtists(artistsMap.keys.toList());
      await _checkConnectivity();
    } finally {
      if (mounted) {
        setState(() {
          _isPreloading = false;
        });
      }
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Artists'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          if (_isPreloading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          IconButton(
            icon: Icon(_isOnline ? Icons.cloud_done : Icons.cloud_off, color: _isOnline ? Colors.green : Colors.orange),
            tooltip: _isOnline ? 'Online' : 'Offline',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isOnline ? 'Online - Spotify data available' : 'Offline - Showing local data only'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search local artists...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
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
      body: Consumer<AudioController>(
        builder: (context, controller, child) {
          if (controller.songs.isEmpty) {
            return _buildEmptyState(context);
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
            return _buildNoResultsState(context);
          }

          return Column(
            children: [
              // Offline notification banner
              if (!_isOnline) _buildOfflineBanner(context),

              // Artists list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _preloadArtistData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredArtists.length,
                    itemBuilder: (context, index) {
                      final entry = filteredArtists[index];
                      final artistName = entry.key;
                      final songs = entry.value;

                      return _ArtistCardWithImage(
                        artistName: artistName,
                        songs: songs,
                        cacheService: _cacheService,
                        isOnline: _isOnline,
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchHistory() {
    final history = _searchHistoryBox.values.toList().reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(onPressed: _clearHistory, child: const Text('Clear All')),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final query = history[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(query),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => _removeFromHistory(history.length - 1 - index),
                ),
                onTap: () {
                  setState(() {
                    _searchController.text = query;
                    _searchQuery = query;
                    _searchFocusNode.unfocus(); // Close keyboard and show results
                  });
                  _addToHistory(query); // Move to top
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline Mode',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 13),
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
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No artists found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 80, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
            const SizedBox(height: 24),
            Text(
              'No Artists Found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add some music to see your artists',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
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

    // Then fetch/update in background if needed and online
    if (widget.isOnline && (cached == null || cached.isExpired)) {
      _fetchFreshData();
    }
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
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildLeadingImage(context),
        title: Text(
          widget.artistName,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${widget.songs.length} ${widget.songs.length == 1 ? 'song' : 'songs'}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  ArtistPage(artistName: widget.artistName, localSongs: widget.songs, cachedSpotifyData: _cachedData),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeadingImage(BuildContext context) {
    if (_cachedData?.imageUrl != null) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(_cachedData!.imageUrl!),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        onBackgroundImageError: (_, __) {
          // Fallback handled by child
        },
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : null,
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: _isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimaryContainer),
            )
          : Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 28),
    );
  }
}
