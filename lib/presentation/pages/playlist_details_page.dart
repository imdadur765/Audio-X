import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/song_model.dart';
import '../controllers/audio_controller.dart';
import 'player_page.dart';

class PlaylistDetailsPage extends StatelessWidget {
  final String title;
  final List<Song> songs;
  final List<Color> gradientColors;

  const PlaylistDetailsPage({
    super.key,
    required this.title,
    required this.songs,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          _buildSongList(context),
        ],
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: () {
            if (songs.isNotEmpty) {
              final audioController = Provider.of<AudioController>(context, listen: false);
              audioController.playSong(songs.first);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerPage(song: songs.first)));
            }
          },
          backgroundColor: gradientColors.last,
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.play_arrow_rounded, color: gradientColors.last, size: 24),
          ),
          label: const Text(
            'Play All',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      floating: false,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black45,
                blurRadius: 12,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
          ),
          child: Stack(
            children: [
              // Background Pattern
              Positioned(
                right: -60,
                top: -60,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                left: -40,
                bottom: -40,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              
              // Music Notes
              Positioned(
                right: 30,
                bottom: 30,
                child: Icon(Icons.music_note_rounded, size: 80, color: Colors.white.withOpacity(0.15)),
              ),
              Positioned(
                left: 30,
                top: 50,
                child: Icon(Icons.library_music_rounded, size: 60, color: Colors.white.withOpacity(0.15)),
              ),
              
              // Content Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                    ],
                  ),
                ),
              ),
              
              // Playlist Info
              Positioned(
                left: 24,
                bottom: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Text(
                        'PLAYLIST',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${songs.length} ${songs.length == 1 ? 'Song' : 'Songs'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongList(BuildContext context) {
    if (songs.isEmpty) {
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
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.music_off_rounded, size: 50, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Songs Yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add some songs to this playlist',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        // Navigate to add songs
                      },
                      child: const Center(
                        child: Text(
                          'Add Songs',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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

    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final song = songs[index];
              final isCurrentlyPlaying = audioController.currentSong?.id == song.id;
              final isPlaying = isCurrentlyPlaying && audioController.isPlaying;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrentlyPlaying ? gradientColors.first.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (!isCurrentlyPlaying)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                  border: Border.all(
                    color: isCurrentlyPlaying ? gradientColors.first.withOpacity(0.3) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      audioController.playSong(song);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerPage(song: song)));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Song Number/Artwork with Animation
                          Stack(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: isCurrentlyPlaying 
                                      ? gradientColors.first.withOpacity(0.2) 
                                      : Colors.grey.shade100,
                                  image: song.localArtworkPath != null
                                      ? DecorationImage(
                                          image: FileImage(File(song.localArtworkPath!)),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: song.localArtworkPath == null
                                    ? Center(
                                        child: isCurrentlyPlaying && isPlaying
                                            ? const SizedBox()
                                            : Text(
                                                '${index + 1}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: isCurrentlyPlaying 
                                                      ? gradientColors.first 
                                                      : Colors.grey.shade600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                      )
                                    : null,
                              ),
                              
                              // Playing Animation Overlay
                              if (isCurrentlyPlaying && isPlaying)
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: _PlayingAnimation(),
                                  ),
                                ),
                            ],
                          ),
                          
                          const SizedBox(width: 12),
                          
                          // Song Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isCurrentlyPlaying ? gradientColors.first : Colors.black87,
                                    fontWeight: isCurrentlyPlaying ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isCurrentlyPlaying 
                                        ? gradientColors.first.withOpacity(0.8) 
                                        : Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Playing Indicator and Duration
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isPlaying)
                                TweenAnimationBuilder(
                                  tween: Tween<double>(begin: 0.8, end: 1.2),
                                  duration: const Duration(milliseconds: 500),
                                  builder: (context, double value, child) {
                                    return Transform.scale(
                                      scale: value,
                                      child: Icon(
                                        Icons.volume_up_rounded, 
                                        color: gradientColors.first, 
                                        size: 18
                                      ),
                                    );
                                  },
                                ),
                              if (isPlaying) const SizedBox(width: 8),
                              Text(
                                _formatDuration(song.duration),
                                style: TextStyle(
                                  color: isCurrentlyPlaying ? gradientColors.first : Colors.grey.shade600,
                                  fontWeight: isCurrentlyPlaying ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  Icons.more_vert_rounded,
                                  color: Colors.grey.shade400,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _showSongOptions(context, song);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            childCount: songs.length,
          ),
        );
      },
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showSongOptions(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Song Info
                ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade100,
                      image: song.localArtworkPath != null
                          ? DecorationImage(
                              image: FileImage(File(song.localArtworkPath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: song.localArtworkPath == null
                        ? Icon(Icons.music_note_rounded, color: Colors.grey.shade400)
                        : null,
                  ),
                  title: Text(
                    song.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Divider(),
                // Options
                _buildOptionItem(Icons.play_arrow_rounded, 'Play Now', () {
                  Navigator.pop(context);
                  final audioController = Provider.of<AudioController>(context, listen: false);
                  audioController.playSong(song);
                }),
                _buildOptionItem(Icons.playlist_add_rounded, 'Add to Queue', () {
                  Navigator.pop(context);
                  // Add to queue logic
                }),
                _buildOptionItem(Icons.favorite_border_rounded, 'Add to Favorites', () {
                  Navigator.pop(context);
                  // Add to favorites logic
                }),
                _buildOptionItem(Icons.delete_outline_rounded, 'Remove from Playlist', () {
                  Navigator.pop(context);
                  // Remove from playlist logic
                }),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionItem(IconData icon, String text, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(text, style: TextStyle(color: Colors.grey.shade800)),
      onTap: onTap,
      minLeadingWidth: 0,
    );
  }
}

// Custom Playing Animation Widget
class _PlayingAnimation extends StatefulWidget {
  const _PlayingAnimation();

  @override
  State<_PlayingAnimation> createState() => _PlayingAnimationState();
}

class _PlayingAnimationState extends State<_PlayingAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: const Icon(
            Icons.equalizer_rounded,
            color: Colors.white,
            size: 24,
          ),
        );
      },
    );
  }
}