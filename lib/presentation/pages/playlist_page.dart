import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/playlist_model.dart';
import '../../data/models/song_model.dart';
import '../../services/playlist_service.dart';
import '../controllers/audio_controller.dart';
import 'playlist_details_page.dart';

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
    _loadPlaylists();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
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

  void _showCreatePlaylistDialog() {
    final nameController = TextEditingController();
    String selectedEmoji = '🎵';

    final emojis = ['🎵', '🎸', '🎹', '🎤', '🎧', '🎼', '🎺', '🎷', '🥁', '🎻', '💜', '❤️', '🔥', '⚡', '🌟'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Create Playlist', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Playlist Name',
                    hintStyle: TextStyle(color: Colors.white54),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.deepPurpleAccent)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Choose Icon', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  width: double.maxFinite,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: emojis.length,
                    itemBuilder: (context, index) {
                      final emoji = emojis[index];
                      final isSelected = selectedEmoji == emoji;
                      return GestureDetector(
                        onTap: () => setState(() => selectedEmoji = emoji),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.deepPurpleAccent.withOpacity(0.3) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? Border.all(color: Colors.deepPurpleAccent) : null,
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 20)),
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
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
                    await _playlistService.createPlaylist(nameController.text, iconEmoji: selectedEmoji);
                    Navigator.pop(context);
                    _loadPlaylists();
                  }
                },
                child: const Text('Create', style: TextStyle(color: Colors.deepPurpleAccent)),
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
        onPressed: _showCreatePlaylistDialog,
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
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
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(10),
            boxShadow: opacity > 0.5
                ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Row(
            children: [
              _buildViewButton(
                icon: Icons.grid_view_rounded,
                isSelected: _viewMode == ViewMode.grid,
                onTap: () => setState(() => _viewMode = ViewMode.grid),
                isCompact: opacity > 0.5,
              ),
              _buildViewButton(
                icon: Icons.view_list_rounded,
                isSelected: _viewMode == ViewMode.list,
                onTap: () => setState(() => _viewMode = ViewMode.list),
                isCompact: opacity > 0.5,
              ),
            ],
          ),
        ),
        // Sort button
        PopupMenuButton<SortOrder>(
          icon: Icon(Icons.sort_rounded, color: opacity > 0.5 ? Colors.deepPurple : Colors.white),
          onSelected: (order) => setState(() => _sortOrder = order),
          offset: const Offset(0, 40),
          itemBuilder: (context) => [
            const PopupMenuItem(value: SortOrder.newest, child: Text('Newest First')),
            const PopupMenuItem(value: SortOrder.oldest, child: Text('Oldest First')),
            const PopupMenuItem(value: SortOrder.aToZ, child: Text('A to Z')),
            const PopupMenuItem(value: SortOrder.zToA, child: Text('Z to A')),
          ],
        ),
        const SizedBox(width: 8),
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
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
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

  Widget _buildViewButton({
    required IconData icon,
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
              ? (isCompact ? Colors.deepPurple.shade50 : Colors.white.withOpacity(0.3))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isCompact
              ? (isSelected ? Colors.deepPurple : Colors.grey[600])
              : (isSelected ? Colors.white : Colors.white60),
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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PlaylistDetailsPage(
              playlistId: playlist.id,
              title: playlist.name,
              songs: songs,
              gradientColors: gradientColors,
              isAuto: playlist.isAuto,
            ),
          ),
        );
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
                child: Center(child: Text(playlist.iconEmoji, style: const TextStyle(fontSize: 48))),
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
          child: Center(child: Text(playlist.iconEmoji, style: const TextStyle(fontSize: 24))),
        ),
        title: Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(
          '${playlist.songCount} songs • $durationText',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PlaylistDetailsPage(
                playlistId: playlist.id,
                title: playlist.name,
                songs: songs,
                gradientColors: gradientColors,
                isAuto: playlist.isAuto,
              ),
            ),
          );
        },
      ),
    );
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
            child: Icon(Icons.queue_music_rounded, size: 50, color: Colors.deepPurple.shade300),
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
