import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../data/models/song_model.dart';
import '../controllers/audio_controller.dart';
import '../widgets/hybrid_song_artwork.dart';
import '../widgets/more_options_button.dart';
import '../widgets/glass_background.dart';

enum SortOrder { aToZ, zToA, dateAdded, duration }

class AllSongsPage extends StatefulWidget {
  final List<Song> songs;

  const AllSongsPage({super.key, required this.songs});

  @override
  State<AllSongsPage> createState() => _AllSongsPageState();
}

class _AllSongsPageState extends State<AllSongsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  SortOrder _sortOrder = SortOrder.aToZ;
  double _scrollOffset = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Simulate premium loading feel
    Future.delayed(const Duration(milliseconds: 800), () {
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
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Song> _getFilteredAndSortedSongs() {
    var filteredSongs = List<Song>.from(widget.songs);

    // Filter
    if (_searchQuery.isNotEmpty) {
      filteredSongs = filteredSongs.where((song) {
        return song.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            song.artist.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            song.album.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Sort
    switch (_sortOrder) {
      case SortOrder.aToZ:
        filteredSongs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortOrder.zToA:
        filteredSongs.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case SortOrder.dateAdded:
        filteredSongs.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case SortOrder.duration:
        filteredSongs.sort((a, b) => b.duration.compareTo(a.duration));
        break;
    }

    return filteredSongs;
  }

  String _formatTotalDuration(List<Song> songs) {
    int totalMillis = songs.fold(0, (sum, item) => sum + item.duration);
    final duration = Duration(milliseconds: totalMillis);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '$hours hr $minutes min';
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final filteredSongs = _getFilteredAndSortedSongs();

    return Consumer<AudioController>(builder: (context, controller, child) {
      final artworkPath = controller.currentSong?.localArtworkPath;
      final accentColor = controller.accentColor;

      return Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            GlassBackground(
              artworkPath: artworkPath,
              accentColor: accentColor,
              isDark: true,
            ),
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                _buildHeader(accentColor),

                if (_isLoading)
                  _buildShimmerList()
                else if (filteredSongs.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset('assets/images/song.png', width: 64, height: 64, color: Colors.white38),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty ? 'No songs found' : 'No music available',
                            style: const TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _buildSongList(filteredSongs, accentColor),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildHeader(Color accentColor) {
    final isScrolled = _scrollOffset > 100;
    final totalDuration = _formatTotalDuration(widget.songs);

    return SliverAppBar(
      expandedHeight: 280,
      floating: false,
      pinned: true,
      backgroundColor: isScrolled ? Colors.black.withOpacity(0.4) : Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        // Sort Button
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: PopupMenuButton<SortOrder>(
            icon: Image.asset(
              'assets/images/sort.png',
              width: 20,
              height: 20,
              color: Colors.white,
            ),
            onSelected: (order) => setState(() => _sortOrder = order),
            color: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            itemBuilder: (context) => [
              const PopupMenuItem(value: SortOrder.aToZ, child: Text('A to Z', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: SortOrder.zToA, child: Text('Z to A', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(
                  value: SortOrder.dateAdded, child: Text('Recently Added', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(
                  value: SortOrder.duration, child: Text('Duration', style: TextStyle(color: Colors.white))),
            ],
          ),
        ),
      ],
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: isScrolled ? 20 : 0, sigmaY: isScrolled ? 20 : 0),
          child: FlexibleSpaceBar(
            title: AnimatedOpacity(
              opacity: isScrolled ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
               child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'All Songs',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      '${widget.songs.length}',
                      style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child:
                              Image.asset('assets/images/song.png', width: 28, height: 28, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'All Songs',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(offset: Offset(0, 2), blurRadius: 8, color: Colors.black26)],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.songs.length} tracks • $totalDuration',
                      style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 20),

                    // Search Bar
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
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(fontSize: 15, color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search collection...',
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
                              onChanged: (value) => setState(() => _searchQuery = value),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildHeaderActionButton(
                            text: 'Play All',
                            icon: 'assets/images/play.png',
                            onTap: _playAll,
                            isPrimary: true,
                            accentColor: accentColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildHeaderActionButton(
                            text: 'Shuffle',
                            icon: 'assets/images/shuffle.png',
                            onTap: _shuffleAll,
                            isPrimary: false,
                            accentColor: accentColor,
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
    );
  }

  Widget _buildHeaderActionButton({
    required String text,
    required String icon,
    required VoidCallback onTap,
    required bool isPrimary,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: isPrimary ? accentColor : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(icon, width: 20, height: 20, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSongList(List<Song> songs, Color accentColor) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final song = songs[index];
            return RepaintBoundary(child: _buildSongTile(song, index, accentColor));
          },
          childCount: songs.length,
          addAutomaticKeepAlives: true,
        ),
      ),
    );
  }

  Widget _buildSongTile(Song song, int index, Color accentColor) {
    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        final isPlaying = audioController.currentSong?.id == song.id && audioController.isPlaying;
        final isCurrent = audioController.currentSong?.id == song.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isCurrent ? accentColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onTap: () => _playSong(song),
            leading: Stack(
              children: [
                HybridSongArtwork.fromSong(song: song, size: 52, borderRadius: 10),
                if (isPlaying)
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Image.asset('assets/images/equalizer.png', width: 24, height: 24, color: accentColor),
                    ),
                  )
                else if (isCurrent)
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Image.asset('assets/images/pause.png', width: 20, height: 20, color: Colors.white),
                    ),
                  ),
              ],
            ),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                color: isCurrent ? accentColor : Colors.white,
                fontSize: 15,
              ),
            ),
            subtitle: Row(
              children: [
                Flexible(
                  child: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text('•', style: TextStyle(color: Colors.white38, fontSize: 10)),
                ),
                Text(_formatDuration(song.duration), style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
            trailing: MoreOptionsButton(
              song: song,
              trailing: IconButton(
                icon: Image.asset(
                  'assets/images/favorite.png',
                  width: 20,
                  height: 20,
                  color: song.isFavorite ? Colors.red : Colors.white38,
                ),
                onPressed: () => audioController.toggleFavorite(song),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerList() {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.white.withOpacity(0.1),
            highlightColor: Colors.white.withOpacity(0.05),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration:
                  BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration:
                        BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: 140,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 12,
                          width: 80,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }, childCount: 10),
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _playAll() {
    final filteredSongs = _getFilteredAndSortedSongs();
    if (filteredSongs.isEmpty) return;

    final controller = Provider.of<AudioController>(context, listen: false);
    controller.playSongList(filteredSongs, 0);
    context.pushNamed('player', extra: {'song': filteredSongs.first, 'heroTag': 'all_song_${filteredSongs.first.id}'});
  }

  void _shuffleAll() {
    final filteredSongs = _getFilteredAndSortedSongs();
    if (filteredSongs.isEmpty) return;

    final controller = Provider.of<AudioController>(context, listen: false);
    controller.playSongList(filteredSongs, 0, shuffle: true);
    context.pushNamed('player', extra: {'song': filteredSongs.first, 'heroTag': 'all_song_${filteredSongs.first.id}'});
  }

  void _playSong(Song song) {
    final filteredSongs = _getFilteredAndSortedSongs();
    final index = filteredSongs.indexOf(song);

    if (index != -1) {
      final controller = Provider.of<AudioController>(context, listen: false);
      controller.playSongList(filteredSongs, index);
      context.pushNamed('player', extra: {'song': song, 'heroTag': 'all_song_${song.id}'});
    }
  }
}
