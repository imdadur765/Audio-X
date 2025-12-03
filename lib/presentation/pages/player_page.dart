import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:palette_generator/palette_generator.dart';
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

  Color? _accentColor;
  String? _lastSongId;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animationController.forward();
    _loadLyrics();
    _updatePalette(widget.song.localArtworkPath);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _updatePalette(String? artworkPath) async {
    if (artworkPath == null) {
      setState(() => _accentColor = Colors.deepPurple);
      return;
    }
    try {
      final palette = await PaletteGenerator.fromImageProvider(FileImage(File(artworkPath)), maximumColorCount: 20);
      if (mounted) {
        setState(() {
          _accentColor = palette.dominantColor?.color ?? palette.vibrantColor?.color ?? Colors.deepPurple;
        });
      }
    } catch (e) {
      // Fallback
      if (mounted) setState(() => _accentColor = Colors.deepPurple);
    }
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
          content: Text('Lyrics file loaded!'),
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
          content: Text('Found ${lyrics.lines.length} lyrics lines!'),
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
            content: Text('Lyrics not found'),
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

        if (_lastSongId != currentSong.id) {
          _lastSongId = currentSong.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updatePalette(currentSong.localArtworkPath);
          });
        }

        final accentColor = _accentColor ?? Colors.deepPurple;

        return Scaffold(
          backgroundColor: Colors.white,
          body: Dismissible(
            key: const Key('player_dismiss'),
            direction: DismissDirection.down,
            onDismissed: (_) => Navigator.of(context).pop(),
            child: RepaintBoundary(
              child: Stack(
                children: [
                  // Gradient Background
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [accentColor.withOpacity(0.1), Colors.white, accentColor.withOpacity(0.05)],
                        ),
                      ),
                    ),
                  ),
                  // Subtle Blur Effect
                  Positioned.fill(
                    child: currentSong.localArtworkPath != null
                        ? Image.file(File(currentSong.localArtworkPath!), fit: BoxFit.cover)
                        : Container(),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(color: Colors.white.withOpacity(0.5)),
                    ),
                  ),

                  // Content
                  SafeArea(
                    child: Column(
                      children: [
                        _buildAppBar(context, accentColor),
                        Expanded(
                          child: _showLyrics && _lyrics != null
                              ? Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.white.withOpacity(0.9), accentColor.withOpacity(0.1)],
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
                              : _buildAlbumArtSection(currentSong, controller, accentColor),
                        ),
                        RepaintBoundary(child: _buildPlayerControls(controller, accentColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context, Color accentColor) {
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
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Image.asset('assets/images/down.png', width: 20, height: 20, color: Colors.black87)),
            ),
          ),
          Column(
            children: [
              Text(
                'NOW PLAYING',
                style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
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
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showLyrics = !_showLyrics;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Image.asset(
                        _showLyrics ? 'assets/images/album.png' : 'assets/images/lyrics.png',
                        width: 20,
                        height: 20,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: PopupMenuButton<String>(
                  icon: Image.asset('assets/images/more.png', width: 20, height: 20, color: Colors.black87),
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
                          Image.asset('assets/images/upload_lrc.png', width: 20, height: 20, color: Colors.black87),
                          SizedBox(width: 12),
                          Text('Upload .lrc file', style: TextStyle(color: Colors.black87)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'search',
                      child: Row(
                        children: [
                          Image.asset('assets/images/search.png', width: 20, height: 20, color: Colors.black87),
                          SizedBox(width: 12),
                          Text('Search lyrics', style: TextStyle(color: Colors.black87)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'equalizer',
                      child: Row(
                        children: [
                          Image.asset('assets/images/equalizer.png', width: 20, height: 20, color: Colors.black87),
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

  Widget _buildAlbumArtSection(Song currentSong, AudioController controller, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Hero(
                tag: widget.heroTag ?? 'song_${currentSong.id}',
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 2,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: currentSong.localArtworkPath != null
                        ? Image.file(File(currentSong.localArtworkPath!), fit: BoxFit.cover)
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [accentColor.withOpacity(0.6), accentColor],
                              ),
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/images/album.png',
                                width: 100,
                                height: 100,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 32),
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
                style: TextStyle(color: accentColor, fontSize: 18, fontWeight: FontWeight.w600),
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

  Widget _buildPlayerControls(AudioController controller, Color accentColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16), // Lifted up
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
                    trackHeight: 3, // Thinner track
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                      elevation: 2,
                      pressedElevation: 4,
                    ), // Smaller thumb
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: accentColor,
                    inactiveTrackColor: accentColor.withOpacity(0.2),
                    thumbColor: accentColor,
                    overlayColor: accentColor.withOpacity(0.1),
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
                        style: TextStyle(
                          color: accentColor.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatDuration(controller.duration),
                        style: TextStyle(
                          color: accentColor.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16), // Reduced spacing
          // Control Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                imagePath: 'assets/images/shuffle.png',
                isActive: controller.isShuffleEnabled,
                onTap: controller.toggleShuffle,
                size: 18, // Smaller icon
                accentColor: accentColor,
                containerSize: 40, // Smaller container
              ),
              _buildControlButton(
                imagePath: 'assets/images/skip_previous.png',
                size: 24, // Smaller icon
                onTap: controller.previous,
                accentColor: accentColor,
                containerSize: 40,
              ),
              _buildPlayButton(controller, accentColor),
              _buildControlButton(
                imagePath: 'assets/images/skip_next.png',
                size: 24, // Smaller icon
                onTap: controller.next,
                accentColor: accentColor,
                containerSize: 40,
              ),
              _buildControlButton(
                imagePath: 'assets/images/repeat.png',
                isActive: controller.repeatMode > 0,
                onTap: controller.toggleRepeat,
                size: 18, // Smaller icon
                accentColor: accentColor,
                containerSize: 40,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required String imagePath,
    double size = 24,
    double containerSize = 48,
    bool isActive = false,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              color: isActive ? accentColor.withOpacity(0.2) : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
            ),
            child: Center(
              child: Image.asset(imagePath, width: size, height: size, color: isActive ? accentColor : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton(AudioController controller, Color accentColor) {
    return GestureDetector(
      onTap: () {
        if (controller.isPlaying) {
          controller.pause();
        } else {
          controller.resume();
        }
      },
      child: Container(
        width: 64, // Smaller play button
        height: 64,
        decoration: BoxDecoration(
          color: accentColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 16, spreadRadius: 4, offset: const Offset(0, 6)),
          ],
        ),
        child: Center(
          child: Image.asset(
            controller.isPlaying ? 'assets/images/pause.png' : 'assets/images/play.png',
            width: 28,
            height: 28,
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
