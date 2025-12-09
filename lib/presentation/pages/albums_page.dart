import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_x/data/models/song_model.dart';
import 'package:audio_x/presentation/controllers/audio_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../widgets/glass_background.dart';

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
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
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
    return Consumer<AudioController>(
      builder: (context, controller, child) {
        // Use current song for background or fallback
        final artworkPath = controller.currentSong?.localArtworkPath;
        final accentColor = controller.accentColor;

        return Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              // Shared Glass Background
              GlassBackground(
                artworkPath: artworkPath,
                accentColor: accentColor,
                isDark: true, // Force dark mode for premium look
              ),

              // Content
              CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  _buildHeader(accentColor),
                  // Albums Grid
                  if (_isLoading)
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: _viewMode == ViewMode.grid ? _buildGridShimmer() : _buildListShimmer(),
                    )
                  else if (controller.songs.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                              child: Image.asset(
                                'assets/images/album.png',
                                width: 50,
                                height: 50,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'No Albums Found',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Add some music to see your albums',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Builder(
                      builder: (context) {
                        final albumsMap = _groupByAlbums(controller.songs);
                        final albums = _filterAndSortAlbums(albumsMap);

                        if (albums.isEmpty) {
                          return SliverFillRemaining(
                            child: Center(
                              child: Text('No results found', style: TextStyle(fontSize: 16, color: Colors.white70)),
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(Color accentColor) {
    // Calculate opacity for blur effect on scroll
    final isScrolled = _scrollOffset > 100;

    return SliverAppBar(
      expandedHeight: 220,
      floating: false,
      pinned: true,
      backgroundColor: isScrolled ? Colors.black.withOpacity(0.4) : Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: isScrolled ? 20 : 0, sigmaY: isScrolled ? 20 : 0),
          child: FlexibleSpaceBar(
            title: AnimatedOpacity(
              opacity: isScrolled ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Text(
                'Albums',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            background: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Image.asset('assets/images/album.png', width: 28, height: 28, color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Albums',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(offset: Offset(0, 2), blurRadius: 8, color: Colors.black26)],
                              ),
                            ),
                          ],
                        ),
                        // View Toggle Buttons
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              _buildViewButton(
                                imagePath: 'assets/images/girdview.png',
                                isSelected: _viewMode == ViewMode.grid,
                                onTap: () => setState(() => _viewMode = ViewMode.grid),
                                accentColor: accentColor,
                              ),
                              _buildViewButton(
                                imagePath: 'assets/images/listview.png',
                                isSelected: _viewMode == ViewMode.list,
                                onTap: () => setState(() => _viewMode = ViewMode.list),
                                accentColor: accentColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    const Text('Your music collection', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 16),
                    // Search bar in glass
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                textSelectionTheme: TextSelectionThemeData(
                                  cursorColor: accentColor,
                                  selectionColor: accentColor.withOpacity(0.4),
                                  selectionHandleColor: accentColor,
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(fontSize: 15, color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Search albums...',
                                  hintStyle: const TextStyle(color: Colors.white38),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Image.asset(
                                      'assets/images/search.png',
                                      width: 20,
                                      height: 20,
                                      color: Colors.white70,
                                    ),
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
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Sort button
                        PopupMenuButton<SortOrder>(
                          icon: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Image.asset(
                              'assets/images/sort.png',
                              width: 24,
                              height: 24,
                              color: accentColor, // Updated to dynamic color
                            ),
                          ),
                          onSelected: (order) {
                            setState(() {
                              _sortOrder = order;
                            });
                          },
                          color: const Color(0xFF1E1E1E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          offset: const Offset(0, 40),
                          itemBuilder: (context) => [
                            _buildPopupItem(SortOrder.aToZ, 'A to Z'),
                            _buildPopupItem(SortOrder.zToA, 'Z to A'),
                            _buildPopupItem(SortOrder.recentlyAdded, 'Recently Added'),
                            _buildPopupItem(SortOrder.mostPlayed, 'Most Songs'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<SortOrder> _buildPopupItem(SortOrder value, String text) {
    return PopupMenuItem(
      value: value,
      child: Text(text, style: const TextStyle(color: Colors.white)),
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
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album Art
            Expanded(
              child: Container(
                decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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

                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
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
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
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
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1)),
      child: Center(
        child: Image.asset('assets/images/album.png', width: 48, height: 48, color: Colors.white.withOpacity(0.3)),
      ),
    );
  }

  Widget _buildViewButton({
    required String imagePath,
    required bool isSelected,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Image.asset(imagePath, width: 20, height: 20, color: isSelected ? accentColor : Colors.white60),
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                    errorBuilder: (_, __, ___) => _buildPlaceholderArt(),
                  )
                : _buildPlaceholderArt(),
          ),
        ),
        title: Text(
          albumName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white),
        ),
        subtitle: Text(
          '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
        onTap: () => _navigateToAlbumDetails(context, albumName, songs, heroTag: 'album_list_$albumName'),
      ),
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
          baseColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
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
          baseColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
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
