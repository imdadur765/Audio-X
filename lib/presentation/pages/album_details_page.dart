import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/song_model.dart';
import '../controllers/audio_controller.dart';
import '../widgets/hybrid_song_artwork.dart';
import '../widgets/glass_button.dart';

class AlbumDetailsPage extends StatefulWidget {
  final String albumName;
  final List<Song> songs;
  final String? heroTag;

  const AlbumDetailsPage({super.key, required this.albumName, required this.songs, this.heroTag});

  @override
  State<AlbumDetailsPage> createState() => _AlbumDetailsPageState();
}

class _AlbumDetailsPageState extends State<AlbumDetailsPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String get _artistName {
    // Get the most common artist from songs
    if (widget.songs.isEmpty) return 'Unknown Artist';
    final artistCounts = <String, int>{};
    for (final song in widget.songs) {
      artistCounts[song.artist] = (artistCounts[song.artist] ?? 0) + 1;
    }
    return artistCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  int get _totalDuration {
    return widget.songs.fold(0, (sum, song) => sum + song.duration);
  }

  Widget? get _albumArtwork {
    final firstSong = widget.songs.firstOrNull;
    if (firstSong?.localArtworkPath != null) {
      return Image.file(File(firstSong!.localArtworkPath!), fit: BoxFit.cover);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta! > 10) {
            Navigator.of(context).pop();
          }
        },
        child: Stack(
          children: [
            // Blur background with album art
            if (_albumArtwork != null) Positioned.fill(child: _albumArtwork!),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(color: Colors.white.withOpacity(0.4)),
              ),
            ),
            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.7),
                      Colors.deepPurple.shade50.withOpacity(0.5),
                      Colors.deepPurple.shade100.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            SafeArea(
              child: Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildAlbumArtSection(),
                          const SizedBox(height: 24),
                          _buildAlbumInfo(),
                          const SizedBox(height: 24),
                          _buildActionButtons(),
                          const SizedBox(height: 24),
                          _buildTrackList(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GlassButton(
            imagePath: 'assets/images/back.png',
            onTap: () => Navigator.of(context).pop(),
            size: 24,
            containerSize: 40,
            accentColor: Colors.deepPurple,
          ),
          Column(
            children: [
              const Text(
                'ALBUM',
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.songs.length} Songs',
                style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          GlassButton(
            imagePath: 'assets/images/more.png',
            onTap: _showOptionsMenu,
            size: 20,
            containerSize: 40,
            accentColor: Colors.deepPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArtSection() {
    return Hero(
      tag: widget.heroTag ?? 'album_${widget.albumName}',
      child: Container(
        width: 280,
        height: 280,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.3),
              blurRadius: 40,
              spreadRadius: 5,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child:
              _albumArtwork ??
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.deepPurple.shade300, Colors.purple.shade400],
                  ),
                ),
                child: Center(child: Icon(Icons.album_rounded, size: 100, color: Colors.white.withOpacity(0.8))),
              ),
        ),
      ),
    );
  }

  Widget _buildAlbumInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            widget.albumName,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              context.pushNamed('artist_details', pathParameters: {'name': _artistName});
            },
            child: Text(
              _artistName,
              style: TextStyle(
                color: Colors.deepPurple.shade700,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: Colors.deepPurple.shade200,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildInfoChip(icon: Icons.music_note_rounded, text: '${widget.songs.length} songs'),
              const SizedBox(width: 12),
              _buildInfoChip(icon: Icons.access_time_rounded, text: _formatTotalDuration(_totalDuration)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.deepPurple),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: Colors.deepPurple.shade700, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildGlassButton(
              text: 'Play All',
              iconPath: 'assets/images/play.png',
              onTap: _playAll,
              isPrimary: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildGlassButton(
              text: 'Shuffle',
              iconPath: 'assets/images/shuffle.png',
              onTap: _shuffleAll,
              isPrimary: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required String text,
    required String iconPath,
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
            height: 56,
            decoration: BoxDecoration(
              color: isPrimary ? Colors.deepPurple.withOpacity(0.8) : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isPrimary ? Colors.transparent : Colors.deepPurple.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: isPrimary ? Colors.deepPurple.withOpacity(0.3) : Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(iconPath, width: 24, height: 24, color: isPrimary ? Colors.white : Colors.deepPurple),
                if (isPrimary) ...[
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackList() {
    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Tracks',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 12),
            ...widget.songs.asMap().entries.map((entry) {
              final index = entry.key;
              final song = entry.value;
              final isCurrentlyPlaying = audioController.currentSong?.id == song.id;
              final isPlaying = isCurrentlyPlaying && audioController.isPlaying;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrentlyPlaying ? Colors.deepPurple.withOpacity(0.1) : Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCurrentlyPlaying ? Colors.deepPurple.withOpacity(0.3) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _playSong(index),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Album artwork thumbnail with track number
                          Stack(
                            children: [
                              HybridSongArtwork.fromSong(song: song, size: 48, borderRadius: 8),
                              // Track number overlay or playing indicator
                              if (isPlaying)
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.equalizer_rounded, color: Colors.white, size: 20),
                                  ),
                                )
                              else if (isCurrentlyPlaying)
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(child: Icon(Icons.pause_rounded, color: Colors.white, size: 24)),
                                )
                              else
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          // Song info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isCurrentlyPlaying ? Colors.deepPurple : Colors.black87,
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
                                    color: isCurrentlyPlaying ? Colors.deepPurple.shade600 : Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Duration
                          Text(
                            _formatDuration(song.duration),
                            style: TextStyle(
                              color: isCurrentlyPlaying ? Colors.deepPurple : Colors.grey.shade600,
                              fontWeight: isCurrentlyPlaying ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void _playAll() {
    if (widget.songs.isEmpty) return;
    final controller = Provider.of<AudioController>(context, listen: false);
    controller.playSong(widget.songs.first);
    context.pushNamed('player', extra: {'song': widget.songs.first, 'heroTag': 'album_song_${widget.songs.first.id}'});
  }

  void _shuffleAll() {
    if (widget.songs.isEmpty) return;
    final controller = Provider.of<AudioController>(context, listen: false);
    final shuffled = List<Song>.from(widget.songs)..shuffle();
    controller.playSong(shuffled.first);
    context.pushNamed('player', extra: {'song': shuffled.first, 'heroTag': 'album_song_${shuffled.first.id}'});
  }

  void _playSong(int index) {
    final song = widget.songs[index];
    final controller = Provider.of<AudioController>(context, listen: false);
    controller.playSong(song);
    context.pushNamed('player', extra: {'song': song, 'heroTag': 'album_song_${song.id}'});
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatTotalDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours hr $minutes min';
    }
    return '$minutes min';
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            // Header with Album Art
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child:
                          _albumArtwork ??
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.deepPurple.shade300, Colors.purple.shade400],
                              ),
                            ),
                            child: const Icon(Icons.album_rounded, color: Colors.white54, size: 28),
                          ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.albumName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _artistName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.deepPurple.shade700,
                            fontWeight: FontWeight.w600,
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
            const SizedBox(height: 24),
            const Divider(height: 1),
            // Options
            _buildOptionTile(
              iconPath: 'assets/images/playlist_open.png',
              title: 'Add to Playlist',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Playlist feature coming soon!'),
                    backgroundColor: Colors.deepPurple,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            ),
            _buildOptionTile(
              iconPath: 'assets/images/share.png',
              title: 'Share Album',
              onTap: () async {
                Navigator.pop(context);
                final firstSong = widget.songs.firstOrNull;
                final path = firstSong?.localArtworkPath;
                final text =
                    '🎵 Check out this album on Audio X!\n\nAlbum: ${widget.albumName}\nArtist: $_artistName\n\n#AudioX #Music';

                if (path != null && File(path).existsSync()) {
                  await Share.shareXFiles([XFile(path)], text: text);
                } else {
                  await Share.share(text);
                }
              },
            ),
            _buildOptionTile(
              iconPath: 'assets/images/info.png',
              title: 'Album Info',
              onTap: () {
                Navigator.pop(context);
                context.pushNamed(
                  'album_info',
                  extra: {'albumName': widget.albumName, 'artistName': _artistName, 'albumArt': _albumArtwork},
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({required String iconPath, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(8)),
        child: Image.asset(iconPath, width: 24, height: 24, color: Colors.deepPurple),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
