
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/song_model.dart';
import '../controllers/audio_controller.dart';
import '../widgets/hybrid_song_artwork.dart';
import '../widgets/glass_button.dart';

class MostPlayedPage extends StatefulWidget {
  final List<Song> songs;

  const MostPlayedPage({super.key, required this.songs});

  @override
  State<MostPlayedPage> createState() => _MostPlayedPageState();
}

class _MostPlayedPageState extends State<MostPlayedPage> {
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverPadding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), sliver: _buildSongList()),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final opacity = (_scrollOffset / 200).clamp(0.0, 1.0);

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: Colors.transparent,
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
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient Background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                ),
              ),
            ),

            // Pattern/Decoration
            Positioned(
              right: -50,
              top: -50,
              child: Icon(Icons.local_fire_department_rounded, size: 250, color: Colors.white.withOpacity(0.1)),
            ),

            // Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Image.asset('assets/images/most_played.png', width: 32, height: 32, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Most Played',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.songs.length} songs',
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w500),
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
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionButton(
                            text: 'Shuffle',
                            icon: 'assets/images/shuffle.png',
                            onTap: _shuffleAll,
                            isPrimary: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        title: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 200),
          child: const Text(
            'Most Played',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
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
              color: isPrimary ? Colors.white : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(icon, width: 20, height: 20, color: isPrimary ? Colors.deepOrange : Colors.white),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    color: isPrimary ? Colors.deepOrange : Colors.white,
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

  Widget _buildSongList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final song = widget.songs[index];
        return _buildSongTile(song, index);
      }, childCount: widget.songs.length),
    );
  }

  Widget _buildSongTile(Song song, int index) {
    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        final isPlaying = audioController.currentSong?.id == song.id && audioController.isPlaying;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isPlaying ? Colors.deepOrange.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
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
                      color: Colors.deepOrange.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: Icon(Icons.equalizer_rounded, color: Colors.white)),
                  ),
                // Rank Badge
                if (index < 3)
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: index == 0 ? Colors.amber : (index == 1 ? Colors.grey.shade400 : Colors.brown.shade300),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
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
                color: isPlaying ? Colors.deepOrange : Colors.black87,
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
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 14, color: Colors.deepOrange.shade300),
                    const SizedBox(width: 2),
                    Text(
                      '${song.playCount} plays',
                      style: TextStyle(color: Colors.deepOrange.shade300, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(
                song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: song.isFavorite ? Colors.red : Colors.grey.shade400,
              ),
              onPressed: () => audioController.toggleFavorite(song),
            ),
          ),
        );
      },
    );
  }

  void _playAll() {
    if (widget.songs.isEmpty) return;
    final controller = Provider.of<AudioController>(context, listen: false);
    controller.playSongList(widget.songs, 0);
    context.pushNamed(
      'player',
      extra: {'song': widget.songs.first, 'heroTag': 'most_played_song_${widget.songs.first.id}'},
    );
  }

  void _shuffleAll() {
    if (widget.songs.isEmpty) return;
    final controller = Provider.of<AudioController>(context, listen: false);
    controller.playSongList(widget.songs, 0, shuffle: true);
    context.pushNamed(
      'player',
      extra: {'song': widget.songs.first, 'heroTag': 'most_played_song_${widget.songs.first.id}'},
    );
  }

  void _playSong(int index) {
    final song = widget.songs[index];
    final controller = Provider.of<AudioController>(context, listen: false);
    controller.playSongList(widget.songs, index);
    context.pushNamed('player', extra: {'song': song, 'heroTag': 'most_played_song_${song.id}'});
  }
}
