import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/playlist_model.dart';

import 'package:go_router/go_router.dart';
import '../../services/playlist_service.dart';
import '../controllers/audio_controller.dart';
import '../widgets/glass_button.dart';
import 'playlist_details_page.dart';
import 'recently_added_page.dart';
import 'most_played_page.dart';
import 'favorites_page.dart';
import 'all_songs_page.dart';
import 'recently_played_page.dart';

enum SortOrder { aToZ, zToA, newest, oldest }

enum ViewMode { grid, list }

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  final PlaylistService _playlistService = PlaylistService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Playlist> _playlists = [];
  bool _isLoading = true;
  ViewMode _viewMode = ViewMode.grid;
  SortOrder _sortOrder = SortOrder.newest;
  double _scrollOffset = 0;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    PlaylistService.playlistChangeNotifier.addListener(_loadPlaylists);
    _loadPlaylists();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    PlaylistService.playlistChangeNotifier.removeListener(_loadPlaylists);
    super.dispose();
  }

  void _onScroll() {
    final currentOffset = _scrollController.offset;
    if ((currentOffset - _lastScrollOffset).abs() > 10) {
      setState(() {
        _scrollOffset = currentOffset;
        _lastScrollOffset = currentOffset;
      });
    }
  }

  Future<void> _loadPlaylists() async {
    setState(() => _isLoading = true);

    final audioController = Provider.of<AudioController>(context, listen: false);
    final allSongs = audioController.allSongs;

    final playlists = await _playlistService.getAllPlaylists(allSongs);

    if (mounted) {
      setState(() {
        _playlists = playlists;
        _isLoading = false;
      });
    }
  }

  List<Playlist> _getFilteredAndSortedPlaylists() {
    var filtered = List<Playlist>.from(_playlists);

    // Filter by search
    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((p) => p.name.toLowerCase().contains(_searchController.text.toLowerCase())).toList();
    }

    // Sort
    switch (_sortOrder) {
      case SortOrder.aToZ:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SortOrder.zToA:
        filtered.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case SortOrder.newest:
        filtered.sort((a, b) => b.created.compareTo(a.created));
        break;
      case SortOrder.oldest:
        filtered.sort((a, b) => a.created.compareTo(b.created));
        break;
    }

    return filtered;
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final nameController = TextEditingController();
    String selectedIcon = 'playlist_open.png'; // Default asset

    final icons = [
      'playlist_open.png',
      'favorite.png',
      'most_played.png',
      'recently_played.png',
      'recently_added.png',
      'song.png',
      'album.png',
      'popularity.png',
      'followers.png',
      'share.png',
      'info.png',
      'lyrics.png',
      'equalizer.png',
      'upload_lrc.png',
      'search.png',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text(
              'Create Playlist',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Playlist Name',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Choose Icon',
                  style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  width: double.maxFinite,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: icons.length,
                    itemBuilder: (context, index) {
                      final iconName = icons[index];
                      final isSelected = selectedIcon == iconName;
                      return GestureDetector(
                        onTap: () => setState(() => selectedIcon = iconName),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.deepPurple.withOpacity(0.1) : Colors.grey.shade500,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected ? Border.all(color: Colors.deepPurple, width: 2) : null,
                          ),
                          child: Image.asset(
                            'assets/images/$iconName',
                            color: isSelected ? Colors.deepPurple : Colors.grey.shade600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
                    await _playlistService.createPlaylist(nameController.text, iconEmoji: selectedIcon);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlists = _getFilteredAndSortedPlaylists();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _buildHeader(),
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (playlists.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: _viewMode == ViewMode.grid ? _buildGridView(playlists) : _buildListView(playlists),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePlaylistDialog(context),
        backgroundColor: Colors.deepPurple,
        icon: Image.asset('assets/images/create.png', width: 24, height: 24, color: Colors.white),
        label: const Text(
          'Create',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
      shadowColor: Colors.black.withOpacity(0.1),
      actions: [
        // View toggle buttons
        Row(
          children: [
            GlassButton(
              imagePath: 'assets/images/girdview.png',
              onTap: () => setState(() => _viewMode = ViewMode.grid),
              isActive: _viewMode == ViewMode.grid,
              accentColor: Colors.deepPurple,
              size: 20,
              containerSize: 40,
            ),
            const SizedBox(width: 8),
            GlassButton(
              imagePath: 'assets/images/listview.png',
              onTap: () => setState(() => _viewMode = ViewMode.list),
              isActive: _viewMode == ViewMode.list,
              accentColor: Colors.deepPurple,
              size: 20,
              containerSize: 40,
            ),
          ],
        ),
        const SizedBox(width: 8),
        // Sort button
        PopupMenuButton<SortOrder>(
          onSelected: (order) => setState(() => _sortOrder = order),
          offset: const Offset(0, 40),
          itemBuilder: (context) => [
            const PopupMenuItem(value: SortOrder.newest, child: Text('Newest First')),
            const PopupMenuItem(value: SortOrder.oldest, child: Text('Oldest First')),
            const PopupMenuItem(value: SortOrder.aToZ, child: Text('A to Z')),
            const PopupMenuItem(value: SortOrder.zToA, child: Text('Z to A')),
          ],
          child: GlassButton(
            imagePath: 'assets/images/sort.png',
            onTap: () {}, // Handled by PopupMenuButton
            accentColor: Colors.deepPurple,
            size: 20,
            containerSize: 40,
          ),
        ),
        const SizedBox(width: 16),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 200),
          child: const Text(
            'Playlists',
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
                    'Playlists',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(offset: Offset(0, 2), blurRadius: 8, color: Colors.black26)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Your custom collections', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 16),
                  // Search bar
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 15, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search playlists...',
                        hintStyle: const TextStyle(color: Colors.white60),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Image.asset('assets/images/search.png', color: Colors.white70, width: 20, height: 20),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Image.asset(
                                  'assets/images/home_close.png',
                                  color: Colors.white70,
                                  width: 20,
                                  height: 20,
                                ),
                                onPressed: () => setState(() => _searchController.clear()),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onChanged: (value) => setState(() {}),
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

  Widget _buildGridView(List<Playlist> playlists) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final playlist = playlists[index];
        return _buildPlaylistCard(playlist);
      }, childCount: playlists.length),
    );
  }

  Widget _buildListView(List<Playlist> playlists) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final playlist = playlists[index];
        return _buildPlaylistListTile(playlist);
      }, childCount: playlists.length),
    );
  }

  Widget _buildPlaylistCard(Playlist playlist) {
    final audioController = Provider.of<AudioController>(context, listen: false);
    final allSongs = audioController.allSongs;
    final songs = playlist.getSongs(allSongs);
    final duration = playlist.getTotalDuration(allSongs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final durationText = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    // Generate a consistent gradient based on playlist ID
    final gradientColors = _getGradientColors(playlist);

    return GestureDetector(
      onTap: () {
        if (playlist.id == 'auto_recently_added') {
          context.pushNamed('recently_added', extra: songs);
        } else if (playlist.id == 'auto_most_played') {
          context.pushNamed('most_played', extra: songs);
        } else if (playlist.id == 'auto_favorites') {
          context.pushNamed('favorites', extra: songs);
        } else if (playlist.id == 'auto_all_songs') {
          context.pushNamed('all_songs', extra: songs);
        } else if (playlist.id == 'auto_recent') {
          context.pushNamed('recently_played', extra: songs);
        } else {
          context.pushNamed(
            'playlist_details',
            pathParameters: {'id': playlist.id},
            extra: {
              'title': playlist.name,
              'songs': songs,
              'gradientColors': gradientColors,
              'isAuto': playlist.isAuto,
            },
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji Cover Art
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Center(child: _buildPlaylistIcon(playlist, size: 48)),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${playlist.songCount} songs • $durationText',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistListTile(Playlist playlist) {
    final audioController = Provider.of<AudioController>(context, listen: false);
    final allSongs = audioController.allSongs;
    final songs = playlist.getSongs(allSongs);
    final duration = playlist.getTotalDuration(allSongs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final durationText = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    final gradientColors = _getGradientColors(playlist);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradientColors),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: _buildPlaylistIcon(playlist, size: 24)),
        ),
        title: Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(
          '${playlist.songCount} songs • $durationText',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () {
          if (playlist.id == 'auto_recently_added') {
            context.pushNamed('recently_added', extra: songs);
          } else if (playlist.id == 'auto_most_played') {
            context.pushNamed('most_played', extra: songs);
          } else if (playlist.id == 'auto_favorites') {
            context.pushNamed('favorites', extra: songs);
          } else if (playlist.id == 'auto_all_songs') {
            context.pushNamed('all_songs', extra: songs);
          } else if (playlist.id == 'auto_recent') {
            context.pushNamed('recently_played', extra: songs);
          } else {
            context.pushNamed(
              'playlist_details',
              pathParameters: {'id': playlist.id},
              extra: {
                'title': playlist.name,
                'songs': songs,
                'gradientColors': gradientColors,
                'isAuto': playlist.isAuto,
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildPlaylistIcon(Playlist playlist, {required double size}) {
    if (playlist.isAuto) {
      String assetName = 'playlist_open.png'; // Default
      if (playlist.id == 'auto_favorites') assetName = 'favorite.png';
      if (playlist.id == 'auto_recent') assetName = 'recently_played.png';
      if (playlist.id == 'auto_recently_added') assetName = 'duration.png';
      if (playlist.id == 'auto_most_played') assetName = 'most_played.png';
      if (playlist.id == 'auto_all_songs') assetName = 'song.png';

      return Image.asset('assets/images/$assetName', width: size, height: size, color: Colors.white);
    }
    // Check if it's an asset path (ends with .png)
    if (playlist.iconEmoji.endsWith('.png')) {
      return Image.asset('assets/images/${playlist.iconEmoji}', width: size, height: size, color: Colors.white);
    }
    return Text(playlist.iconEmoji, style: TextStyle(fontSize: size));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(color: Colors.deepPurple.shade50, shape: BoxShape.circle),
            child: Image.asset(
              'assets/images/playlist_open.png',
              width: 50,
              height: 50,
              color: Colors.deepPurple.shade300,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Playlists Found',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first playlist to get started',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  List<Color> _getGradientColors(Playlist playlist) {
    // Generate consistent colors based on playlist ID hash
    final hash = playlist.id.hashCode;

    // Define some nice gradient pairs
    final gradients = [
      [Colors.purple.shade300, Colors.deepPurple.shade400],
      [Colors.pink.shade300, Colors.red.shade400],
      [Colors.blue.shade300, Colors.indigo.shade400],
      [Colors.teal.shade300, Colors.green.shade400],
      [Colors.orange.shade300, Colors.deepOrange.shade400],
      [Colors.cyan.shade300, Colors.blue.shade400],
      [Colors.amber.shade300, Colors.orange.shade400],
    ];

    // Use specific colors for auto playlists
    if (playlist.isAuto) {
      if (playlist.id == 'auto_favorites') return [Colors.purple.shade300, Colors.deepPurple.shade400];
      if (playlist.id == 'auto_recent') return [Colors.blue.shade300, Colors.indigo.shade400];
      if (playlist.id == 'auto_most_played') return [Colors.orange.shade300, Colors.deepOrange.shade400];
      if (playlist.id == 'auto_all_songs') return [Colors.teal.shade300, Colors.green.shade400];
    }

    return gradients[hash.abs() % gradients.length];
  }
}
