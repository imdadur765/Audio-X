import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/song_model.dart';
import '../controllers/audio_controller.dart';
import '../widgets/hybrid_song_artwork.dart';
import '../widgets/glass_button.dart';
import '../widgets/more_options_button.dart';
import '../widgets/glass_background.dart';

class RecentlyAddedPage extends StatefulWidget {
  final List<Song> songs;

  const RecentlyAddedPage({super.key, required this.songs});

  @override
  State<RecentlyAddedPage> createState() => _RecentlyAddedPageState();
}

class _RecentlyAddedPageState extends State<RecentlyAddedPage> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioController>(
      builder: (context, controller, child) {
        final artworkPath = controller.currentSong?.localArtworkPath;
        final accentColor = controller.accentColor;

        return Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              GlassBackground(
                artworkPath: artworkPath,
                accentColor: accentColor,
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
              CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  _buildAppBar(accentColor),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    sliver: _buildSongList(accentColor),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar(Color accentColor) {
    final isScrolled = _scrollOffset > 100;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: isScrolled ? Colors.black.withOpacity(0.4) : Colors.transparent,
      elevation: 0,
      leading: Center(
        child: GlassButton(
          imagePath: 'assets/images/back.png',
          onTap: () => Navigator.of(context).pop(),
          size: 20,
          containerSize: 40,
          accentColor: Colors.white,
        ),
      ),
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: isScrolled ? 20 : 0, sigmaY: isScrolled ? 20 : 0),
          child: FlexibleSpaceBar(
            title: AnimatedOpacity(
              opacity: isScrolled ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                'Recently Added',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
              ),
            ),
            background: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Image.asset(
                        'assets/images/duration.png',
                        width: 32,
                        height: 32,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Recently Added',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.songs.length} songs',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            text: 'Play All',
                            icon: 'assets/images/play.png',
                            onTap: _playAll,
                            isPrimary: true,
                            accentColor: accentColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionButton(
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

  Widget _buildActionButton({
    required String text,
    required String icon,
    required VoidCallback onTap,
    required bool isPrimary,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: isPrimary ? accentColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  icon,
                  width: 22,
                  height: 22,
                  color: isPrimary ? Colors.white : Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    color: isPrimary ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSongList(Color accentColor) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final song = widget.songs[index];
        return _buildSongTile(song, index, accentColor);
      }, childCount: widget.songs.length),
    );
  }

  Widget _buildSongTile(Song song, int index, Color accentColor) {
    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        final isPlaying = audioController.currentSong?.id == song.id && audioController.isPlaying;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isPlaying
                ? accentColor.withOpacity(0.2)
                : Theme.of(context).colorScheme.surface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onTap: () => _playSong(index),
            leading: Stack(
              children: [
                HybridSongArtwork.fromSong(song: song, size: 56, borderRadius: 12),
                if (isPlaying)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Image.asset('assets/images/equalizer.png', width: 24, height: 24, color: accentColor),
                    ),
                  ),
              ],
            ),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isPlaying ? FontWeight.bold : FontWeight.w600,
                color: isPlaying ? accentColor : Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Added ${_formatDate(song.dateAdded)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            trailing: MoreOptionsButton(
              song: song,
              trailing: IconButton(
                icon: Image.asset(
                  'assets/images/favorite.png',
                  width: 24,
                  height: 24,
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

  String _formatDate(int timestamp) {
    if (timestamp == 0) return 'Unknown';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';

    return '${date.day}/${date.month}/${date.year}';
  }

  void _playAll() {
    if (widget.songs.isEmpty) return;
    final controller = Provider.of<AudioController>(context, listen: false);
    controller.playSongList(widget.songs, 0);
    context.pushNamed('player', extra: {'song': widget.songs.first, 'heroTag': 'recent_song_${widget.songs.first.id}'});
  }

  void _shuffleAll() {
    if (widget.songs.isEmpty) return;
    final controller = Provider.of<AudioController>(context, listen: false);
    controller.playSongList(widget.songs, 0, shuffle: true);
    context.pushNamed('player', extra: {'song': widget.songs.first, 'heroTag': 'recent_song_${widget.songs.first.id}'});
  }

  void _playSong(int index) {
    final song = widget.songs[index];
    final controller = Provider.of<AudioController>(context, listen: false);
    controller.playSongList(widget.songs, index);
    context.pushNamed('player', extra: {'song': song, 'heroTag': 'recent_song_${song.id}'});
  }
}
