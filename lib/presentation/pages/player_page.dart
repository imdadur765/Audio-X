import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/song_model.dart';
import '../../data/models/lyrics_model.dart';
import '../../services/lyrics_service.dart';
import '../controllers/audio_controller.dart';
import '../widgets/lyrics_view.dart';
import 'equalizer_page.dart';

class PlayerPage extends StatefulWidget {
  final Song song;
  final String? heroTag;

  const PlayerPage({super.key, required this.song, this.heroTag});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with SingleTickerProviderStateMixin {
  final LyricsService _lyricsService = LyricsService();
  Lyrics? _lyrics;
  bool _showLyrics = false;
  bool _isLoadingLyrics = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animationController.forward();
    _loadLyrics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics() async {
    setState(() {
      _isLoadingLyrics = true;
    });

    try {
      final lyrics = await _lyricsService.getLyrics(
        songId: widget.song.id,
        title: widget.song.title,
        artist: widget.song.artist,
        album: widget.song.album,
        durationSeconds: widget.song.duration ~/ 1000,
        manualLyricsPath: widget.song.lyricsPath,
      );

      if (mounted) {
        setState(() {
          _lyrics = lyrics;
          _isLoadingLyrics = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLyrics = false;
        });
      }
    }
  }

  Future<void> _pickLyricsFile() async {
    final path = await _lyricsService.pickLRCFile();
    if (path != null && mounted) {
      widget.song.lyricsPath = path;
      widget.song.lyricsSource = 'manual';
      await widget.song.save();
      _loadLyrics();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Lyrics file loaded!'),
          backgroundColor: Colors.deepPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _searchOnline() async {
    setState(() {
      _isLoadingLyrics = true;
    });

    await _lyricsService.deleteCachedLyrics(widget.song.id);

    final lyrics = await _lyricsService.fetchFromLRCLIB(
      title: widget.song.title,
      artist: widget.song.artist,
      album: widget.song.album,
      durationSeconds: widget.song.duration ~/ 1000,
    );

    if (lyrics != null && mounted) {
      final lrcString = lyrics.lines.map((line) => line.toString()).join('\n');
      await _lyricsService.saveLRCFile(widget.song.id, lrcString);

      setState(() {
        _lyrics = lyrics;
        _isLoadingLyrics = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Found ${lyrics.lines.length} lyrics lines!'),
          backgroundColor: Colors.deepPurple,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      if (mounted) {
        setState(() {
          _isLoadingLyrics = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lyrics not found'),
            backgroundColor: Colors.deepPurple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioController>(
      builder: (context, controller, child) {
        final currentSong = controller.currentSong ?? widget.song;

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
                // Gradient Background matching HomePage theme
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.deepPurple.shade50, Colors.white, Colors.purple.shade50],
                      ),
                    ),
                  ),
                ),
                // Subtle Blur Effect with gradient
                Positioned.fill(
                  child: currentSong.localArtworkPath != null
                      ? Image.file(File(currentSong.localArtworkPath!), fit: BoxFit.cover)
                      : Container(),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(color: Colors.white.withOpacity(0.3)),
                  ),
                ),
                // Gradient Overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.6),
                          Colors.deepPurple.shade50.withOpacity(0.4),
                          Colors.deepPurple.shade100.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),

                // Content
                SafeArea(
                  child: Column(
                    children: [
                      _buildAppBar(context),
                      Expanded(
                        child: _showLyrics && _lyrics != null
                            ? Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.white.withOpacity(0.9), Colors.deepPurple.shade50.withOpacity(0.9)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                margin: EdgeInsets.all(16),
                                child: LyricsView(
                                  lyrics: _lyrics!,
                                  currentPosition: controller.position,
                                  onSeek: (position) => controller.seek(position),
                                ),
                              )
                            : _buildAlbumArtSection(currentSong, controller),
                      ),
                      RepaintBoundary(child: _buildPlayerControls(controller)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.deepPurple.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.deepPurple, size: 24),
            ),
          ),
          Column(
            children: [
              const Text(
                'NOW PLAYING',
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your Library',
                style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_lyrics != null && !_isLoadingLyrics)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.deepPurple.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(_showLyrics ? Icons.album_rounded : Icons.lyrics_rounded, color: Colors.deepPurple),
                    onPressed: () {
                      setState(() {
                        _showLyrics = !_showLyrics;
                      });
                    },
                  ),
                ),
              SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.deepPurple.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.deepPurple),
                  onSelected: (value) async {
                    switch (value) {
                      case 'upload':
                        await _pickLyricsFile();
                        break;
                      case 'search':
                        await _searchOnline();
                        break;
                      case 'equalizer':
                        Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (context) => const EqualizerPage(), fullscreenDialog: true));
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'upload',
                      child: Row(
                        children: [
                          Icon(Icons.upload_file_rounded, color: Colors.deepPurple),
                          SizedBox(width: 12),
                          Text('Upload .lrc file', style: TextStyle(color: Colors.black87)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'search',
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: Colors.deepPurple),
                          SizedBox(width: 12),
                          Text('Search lyrics', style: TextStyle(color: Colors.black87)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'equalizer',
                      child: Row(
                        children: [
                          Icon(Icons.equalizer_rounded, color: Colors.deepPurple),
                          SizedBox(width: 12),
                          Text('Equalizer', style: TextStyle(color: Colors.black87)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArtSection(Song currentSong, AudioController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Album Art with Hero Animation
          Expanded(
            child: Center(
              child: Hero(
                tag: widget.heroTag ?? 'song_${currentSong.id}',
                child: Container(
                  width: 280,
                  height: 280,
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
                    child: currentSong.localArtworkPath != null
                        ? Image.file(File(currentSong.localArtworkPath!), fit: BoxFit.cover)
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.deepPurple.shade300, Colors.purple.shade400],
                              ),
                            ),
                            child: Center(
                              child: Icon(Icons.music_note_rounded, size: 100, color: Colors.white.withOpacity(0.8)),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 32),

          // Song Info
          Column(
            children: [
              Text(
                currentSong.title,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),
              Text(
                currentSong.artist,
                style: TextStyle(color: Colors.deepPurple.shade700, fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                currentSong.album,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPlayerControls(AudioController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8, elevation: 4, pressedElevation: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: Colors.deepPurple,
                    inactiveTrackColor: Colors.deepPurple.withOpacity(0.2),
                    thumbColor: Colors.deepPurple,
                    overlayColor: Colors.deepPurple.withOpacity(0.1),
                  ),
                  child: Slider(
                    value: controller.position.inSeconds.toDouble().clamp(
                      0.0,
                      controller.duration.inSeconds.toDouble(),
                    ),
                    max: controller.duration.inSeconds.toDouble() > 0 ? controller.duration.inSeconds.toDouble() : 1.0,
                    onChanged: (value) {
                      controller.seek(Duration(seconds: value.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(controller.position),
                        style: TextStyle(color: Colors.deepPurple.shade600, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _formatDuration(controller.duration),
                        style: TextStyle(color: Colors.deepPurple.shade600, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),

          // Control Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                imagePath: 'assets/images/shuffle.png',
                isActive: controller.isShuffleEnabled,
                onTap: controller.toggleShuffle,
                size: 22,
              ),
              _buildControlButton(imagePath: 'assets/images/skip_previous.png', size: 32, onTap: controller.previous),
              _buildPlayButton(controller),
              _buildControlButton(imagePath: 'assets/images/skip_next.png', size: 32, onTap: controller.next),
              _buildControlButton(
                imagePath: 'assets/images/repeat.png',
                isActive: controller.repeatMode > 0,
                onTap: controller.toggleRepeat,
                size: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required String imagePath,
    double size = 28,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: Image.asset(
            imagePath,
            width: size,
            height: size,
            color: isActive ? Colors.deepPurple : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton(AudioController controller) {
    return GestureDetector(
      onTap: () {
        if (controller.isPlaying) {
          controller.pause();
        } else {
          controller.resume();
        }
      },
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepPurple.shade600, Colors.purple.shade600],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Image.asset(
            controller.isPlaying ? 'assets/images/pause.png' : 'assets/images/play.png',
            width: 36,
            height: 36,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (duration.inHours > 0) {
      return "${duration.inHours}:${twoDigits(minutes)}:${twoDigits(seconds)}";
    }
    return "$minutes:${twoDigits(seconds)}";
  }
}
