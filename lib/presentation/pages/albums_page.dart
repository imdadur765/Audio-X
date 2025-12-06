import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_x/data/models/song_model.dart';
import 'package:audio_x/presentation/controllers/audio_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

enum ViewMode { grid, list }

enum SortOrder { aToZ, zToA, recentlyAdded, mostPlayed }

class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  ViewMode _viewMode = ViewMode.grid;
  SortOrder _sortOrder = SortOrder.aToZ;
  double _scrollOffset = 0;
  double _lastScrollOffset = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Simulate loading for premium feel
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _onScroll() {
    // Throttle scroll updates - only update if difference > 10 pixels
    final currentOffset = _scrollController.offset;
    if ((currentOffset - _lastScrollOffset).abs() > 10) {
      setState(() {
        _scrollOffset = currentOffset;
        _lastScrollOffset = currentOffset;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, List<Song>> _groupByAlbums(List<Song> songs) {
    final albumsMap = <String, List<Song>>{};
    for (final song in songs) {
      final albumName = song.album.trim().isEmpty ? 'Unknown Album' : song.album;
      albumsMap.putIfAbsent(albumName, () => []).add(song);
    }
    return albumsMap;
  }

  List<MapEntry<String, List<Song>>> _filterAndSortAlbums(Map<String, List<Song>> albums) {
    var albumsList = albums.entries.toList();

    // Apply search filter first
    if (_searchQuery.isNotEmpty) {
      albumsList = albumsList.where((entry) => entry.key.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    // Apply sorting
    switch (_sortOrder) {
      case SortOrder.aToZ:
        albumsList.sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
        break;
      case SortOrder.zToA:
        albumsList.sort((a, b) => b.key.toLowerCase().compareTo(a.key.toLowerCase()));
        break;
      case SortOrder.recentlyAdded:
        // Sort by the most recent song in each album (highest id = most recent)
        albumsList.sort((a, b) {
          final aMaxId = a.value.map((s) => int.tryParse(s.id) ?? 0).reduce((max, id) => id > max ? id : max);
          final bMaxId = b.value.map((s) => int.tryParse(s.id) ?? 0).reduce((max, id) => id > max ? id : max);
          return bMaxId.compareTo(aMaxId); // Descending (newest first)
        });
        break;
      case SortOrder.mostPlayed:
        // Sort by number of songs in album (more songs = potentially more played)
        albumsList.sort((a, b) => b.value.length.compareTo(a.value.length));
        break;
    }

    return albumsList;
  }

  void _navigateToAlbumDetails(BuildContext context, String albumName, List<Song> songs, {String? heroTag}) {
    context.pushNamed(
      'album_details',
      pathParameters: {'name': albumName},
      extra: {'songs': songs, 'heroTag': heroTag ?? 'album_$albumName'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _buildHeader(),
          // Albums Grid
          Consumer<AudioController>(
            builder: (context, controller, child) {
              if (_isLoading) {
                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: _viewMode == ViewMode.grid ? _buildGridShimmer() : _buildListShimmer(),
                );
              }

              if (controller.songs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(color: Colors.deepPurple.shade50, shape: BoxShape.circle),
                          child: Image.asset(
                            'assets/images/album.png',
                            width: 50,
                            height: 50,
                            color: Colors.deepPurple.shade300,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No Albums Found',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add some music to see your albums',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final albumsMap = _groupByAlbums(controller.songs);
              final albums = _filterAndSortAlbums(albumsMap);

              if (albums.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text('No results found', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: _viewMode == ViewMode.grid ? _buildGridView(albums) : _buildListView(albums),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final opacity = (_scrollOffset / 100).clamp(0.0, 1.0);

    return SliverAppBar(
      expandedHeight: 220,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: opacity * 4,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      actions: [
        // View toggle buttons
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(10),
            boxShadow: opacity > 0.5
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Row(
            children: [
              _buildViewButton(
                imagePath: 'assets/images/girdview.png',
                isSelected: _viewMode == ViewMode.grid,
                onTap: () => setState(() => _viewMode = ViewMode.grid),
                isCompact: opacity > 0.5,
              ),
              _buildViewButton(
                imagePath: 'assets/images/listview.png',
                isSelected: _viewMode == ViewMode.list,
                onTap: () => setState(() => _viewMode = ViewMode.list),
                isCompact: opacity > 0.5,
              ),
            ],
          ),
        ),
        // Sort button
        PopupMenuButton<SortOrder>(
          icon: Image.asset(
            'assets/images/sort.png',
            width: 24,
            height: 24,
            color: opacity > 0.5 ? Colors.deepPurple : Colors.white,
          ),
          onSelected: (order) {
            setState(() {
              _sortOrder = order;
            });
          },
          offset: const Offset(0, 40),
          itemBuilder: (context) => [
            const PopupMenuItem(value: SortOrder.aToZ, child: Text('A to Z')),
            const PopupMenuItem(value: SortOrder.zToA, child: Text('Z to A')),
            const PopupMenuItem(value: SortOrder.recentlyAdded, child: Text('Recently Added')),
            const PopupMenuItem(value: SortOrder.mostPlayed, child: Text('Most Songs')),
          ],
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 200),
          child: const Text(
            'Albums',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade500, Colors.pink.shade400],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Albums',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(offset: Offset(0, 2), blurRadius: 8, color: Colors.black26)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Your music collection', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 16),
                  // Search bar in gradient
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 15, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search albums...',
                        hintStyle: const TextStyle(color: Colors.white60),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Image.asset('assets/images/search.png', width: 20, height: 20, color: Colors.white70),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumCard(String albumName, List<Song> songs) {
    // Get first song's artwork for album cover
    final firstSong = songs.first;
    final hasArtwork = firstSong.localArtworkPath != null;

    return GestureDetector(
      onTap: () => _navigateToAlbumDetails(context, albumName, songs, heroTag: 'album_grid_$albumName'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album Art
            Expanded(
              child: Container(
                decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasArtwork)
                        Image.file(
                          File(firstSong.localArtworkPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholderArt(),
                        )
                      else
                        _buildPlaceholderArt(),
                      // Subtle gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.1)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Album Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    albumName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderArt() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple.shade300, Colors.purple.shade400],
        ),
      ),
      child: Center(
        child: Image.asset(
          'assets/images/album.png',
          width: 48,
          height: 48,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildViewButton({
    required String imagePath,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isCompact,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isCompact ? Colors.deepPurple.shade50 : Colors.white.withValues(alpha: 0.3))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Image.asset(
          imagePath,
          width: 20,
          height: 20,
          color: isCompact
              ? (isSelected ? Colors.deepPurple : Colors.grey[600])
              : (isSelected ? Colors.white : Colors.white60),
        ),
      ),
    );
  }

  Widget _buildGridView(List<MapEntry<String, List<Song>>> albums) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final album = albums[index];
          return RepaintBoundary(
            key: ValueKey('album_grid_${album.key}'),
            child: _buildAlbumCard(album.key, album.value),
          );
        },
        childCount: albums.length,
        addAutomaticKeepAlives: true,
      ),
    );
  }

  Widget _buildListView(List<MapEntry<String, List<Song>>> albums) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final album = albums[index];
          return RepaintBoundary(
            key: ValueKey('album_list_${album.key}'),
            child: _buildAlbumListTile(album.key, album.value),
          );
        },
        childCount: albums.length,
        addAutomaticKeepAlives: true,
      ),
    );
  }

  Widget _buildAlbumListTile(String albumName, List<Song> songs) {
    final firstSong = songs.first;
    final hasArtwork = firstSong.localArtworkPath != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 56,
            height: 56,
            child: hasArtwork
                ? Image.file(
                    File(firstSong.localArtworkPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderAvatar(),
                  )
                : _buildPlaceholderAvatar(),
          ),
        ),
        title: Text(albumName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(
          '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () => _navigateToAlbumDetails(context, albumName, songs, heroTag: 'album_list_$albumName'),
      ),
    );
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple.shade300, Colors.purple.shade400],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Image.asset('assets/images/album.png', width: 28, height: 28, color: Colors.white54),
    );
  }

  Widget _buildGridShimmer() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 160,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              ),
              const SizedBox(height: 12),
              Container(
                height: 16,
                width: 120,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(height: 6),
              Container(
                height: 12,
                width: 80,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
              ),
            ],
          ),
        );
      }, childCount: 6),
    );
  }

  Widget _buildListShimmer() {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: 150,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 12,
                        width: 100,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }, childCount: 10),
    );
  }
}
