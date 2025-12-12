import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/playlist_model.dart';
import 'package:go_router/go_router.dart';
import '../../services/playlist_service.dart';
import '../controllers/audio_controller.dart';
import '../widgets/glass_background.dart';

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
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
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
          return ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: AlertDialog(
                backgroundColor: Theme.of(context).cardColor.withValues(alpha: 0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                ),
                title: Text(
                  'Create Playlist',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Playlist Name',
                        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Choose Icon',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 250, // Increased height
                      width: double.maxFinite,
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4, // Reduced count
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1,
                        ),
                        itemCount: icons.length,
                        itemBuilder: (context, index) {
                          final iconName = icons[index];
                          final isSelected = selectedIcon == iconName;
                          return GestureDetector(
                            onTap: () => setState(() => selectedIcon = iconName),
                            child: Container(
                              padding: const EdgeInsets.all(12), // Slightly more padding
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.deepPurple.withOpacity(0.4)
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(color: Colors.deepPurple, width: 2)
                                    : Border.all(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                      ),
                              ),
                              child: Image.asset(
                                'assets/images/$iconName',
                                color: isSelected
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
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
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlists = _getFilteredAndSortedPlaylists();

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
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),

              CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  _buildHeader(accentColor),
                  if (_isLoading)
                    const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                  else if (playlists.isEmpty)
                    SliverFillRemaining(child: _buildEmptyState())
                  else
                    SliverPadding(
                      key: ValueKey(_viewMode),
                      padding: const EdgeInsets.all(16),
                      sliver: _viewMode == ViewMode.grid ? _buildGridView(playlists) : _buildListView(playlists),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCreatePlaylistDialog(context),
            backgroundColor: accentColor,
            elevation: 4,
            icon: Image.asset('assets/images/create.png', width: 24, height: 24, color: Colors.white),
            label: Text(
              'Create',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(Color accentColor) {
    final opacity = (_scrollOffset / 100).clamp(0.0, 1.0);
    final isScrolled = _scrollOffset > 100;

    return SliverAppBar(
      expandedHeight: 220,
      floating: false,
      pinned: true,
      backgroundColor: isScrolled ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.8) : Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: isScrolled ? 20 : 0, sigmaY: isScrolled ? 20 : 0),
          child: FlexibleSpaceBar(
            title: AnimatedOpacity(
              opacity: isScrolled ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                'Playlists',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accentColor.withValues(alpha: 0.6),
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0.2), // Darker fade
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
              child: SafeArea(
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
                                  color: accentColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Image.asset(
                                  'assets/images/playlist_open.png',
                                  width: 28,
                                  height: 28,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Playlists',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 2),
                                      blurRadius: 8,
                                      color: Theme.of(context).shadowColor.withValues(alpha: 0.3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // View toggle buttons
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
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
                      Text(
                        'Your custom collections',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      // Search bar
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
                                  style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
                                  decoration: InputDecoration(
                                    hintText: 'Search playlists...',
                                    hintStyle: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Image.asset(
                                        'assets/images/search.png',
                                        height: 20,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    suffixIcon: _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: Image.asset(
                                              'assets/images/home_close.png',
                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Sort button
                          PopupMenuButton<SortOrder>(
                            onSelected: (order) => setState(() => _sortOrder = order),
                            offset: const Offset(0, 40),
                            color: const Color(0xFF1E1E1E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                            ),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: SortOrder.newest,
                                child: Text(
                                  'Newest First',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                ),
                              ),
                              PopupMenuItem(
                                value: SortOrder.oldest,
                                child: Text(
                                  'Oldest First',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                ),
                              ),
                              PopupMenuItem(
                                value: SortOrder.aToZ,
                                child: Text('A to Z', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                              ),
                              PopupMenuItem(
                                value: SortOrder.zToA,
                                child: Text('Z to A', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                              ),
                            ],
                            child: Container(
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
                                color: accentColor, // Dynamic color
                              ),
                            ),
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
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
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
                    colors: gradientColors.map((c) => c.withOpacity(0.8)).toList(),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${playlist.songCount} songs • $durationText',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
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
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors.map((c) => c.withOpacity(0.8)).toList(),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: _buildPlaylistIcon(playlist, size: 24)),
        ),
        title: Text(
          playlist.name,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
        ),
        subtitle: Text(
          '${playlist.songCount} songs • $durationText',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
        ),
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

      return Image.asset(
        'assets/images/$assetName',
        width: size,
        height: size,
        color: Theme.of(context).colorScheme.onSurface,
      );
    }
    // Check if it's an asset path (ends with .png)
    if (playlist.iconEmoji.endsWith('.png')) {
      return Image.asset(
        'assets/images/${playlist.iconEmoji}',
        width: size,
        height: size,
        color: Theme.of(context).colorScheme.onSurface,
      );
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
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/images/playlist_open.png',
              width: 50,
              height: 50,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Playlists Found',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first playlist to get started',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14),
          ),
        ],
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
        child: Image.asset(
          imagePath,
          width: 20,
          height: 20,
          color: isSelected ? accentColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
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
