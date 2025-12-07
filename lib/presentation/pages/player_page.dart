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
import '../widgets/add_to_playlist_sheet.dart';
import '../../data/models/artist_model.dart';
import '../../data/services/artist_service.dart';
import '../../data/services/lastfm_service.dart';
import '../../core/utils/color_utils.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

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
  bool _showBlur = false; // Delay blur effect for faster opening

  final ArtistService _artistService = ArtistService();
  Artist? _artist;

  final LastFmService _lastFmService = LastFmService();
  Map<String, dynamic>? _trackInfo;

  // Static global cache shared across all instances for better performance
  static final Map<String, Color> _globalPaletteCache = {};

  final ScrollController _mainScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animationController.forward();

    // Set default color immediately - no blocking
    _accentColor = Colors.deepPurple;

    // Defer ALL heavy operations to after first frame for instant opening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Enable blur after initial render
      if (mounted) {
        setState(() => _showBlur = true);
      }

      // Load palette in background
      _updatePalette(widget.song.localArtworkPath, widget.song.id);

      // Load lyrics in background
      _loadLyrics();

      // Load artist info
      _loadArtistInfo();

      // Load credits
      _loadCredits();

      // Scroll hint animation to show page is scrollable
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted && _mainScrollController.hasClients) {
          _mainScrollController.animateTo(50, duration: Duration(milliseconds: 400), curve: Curves.easeOut).then((_) {
            Future.delayed(Duration(milliseconds: 200), () {
              if (mounted && _mainScrollController.hasClients) {
                _mainScrollController.animateTo(0, duration: Duration(milliseconds: 400), curve: Curves.easeOut);
              }
            });
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _updatePalette(String? artworkPath, String songId) async {
    if (artworkPath == null) {
      if (mounted) setState(() => _accentColor = Colors.deepPurple);
      return;
    }

    // Check global cache first (persists across instances)
    if (_globalPaletteCache.containsKey(songId)) {
      if (mounted) {
        setState(() => _accentColor = _globalPaletteCache[songId]);
      }
      return;
    }

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        FileImage(File(artworkPath)),
        maximumColorCount: 6,
        timeout: const Duration(milliseconds: 300),
      );

      if (mounted) {
        // Vibrant > LightVibrant > DarkVibrant > Fallback
        Color extracted =
            palette.vibrantColor?.color ??
            palette.lightVibrantColor?.color ??
            palette.darkVibrantColor?.color ??
            const Color(0xFF9B51E0);

        // Safety Net and Contrast Check
        extracted = ColorUtils.getSafeAccentColor(extracted);

        _globalPaletteCache[songId] = extracted;
        setState(() => _accentColor = extracted);
      }
    } catch (e) {
      // Fallback on any error or timeout
      if (mounted) setState(() => _accentColor = const Color(0xFF9B51E0));
    }
  }

  Future<void> _loadLyrics([Song? song]) async {
    if (!mounted) return; // Early exit if widget disposed

    final targetSong = song ?? widget.song; // Use provided song or default to widget.song

    setState(() {
      _isLoadingLyrics = true;
    });

    try {
      final lyrics = await _lyricsService.getLyrics(
        songId: targetSong.id,
        title: targetSong.title,
        artist: targetSong.artist,
        album: targetSong.album,
        durationSeconds: targetSong.duration ~/ 1000,
        manualLyricsPath: targetSong.lyricsPath,
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

  Future<void> _loadArtistInfo([String? artistName]) async {
    final name = artistName ?? widget.song.artist;
    try {
      final artist = await _artistService.getArtistInfo(name, fetchBio: true);
      if (mounted) {
        setState(() {
          _artist = artist;
        });
      }
    } catch (e) {
      debugPrint('Error loading artist info: $e');
    }
  }

  Future<void> _loadCredits([String? artistName, String? songTitle]) async {
    final artist = artistName ?? widget.song.artist;
    final title = songTitle ?? widget.song.title;
    try {
      final info = await _lastFmService.getTrackInfo(artist, title);
      if (mounted && info != null) {
        setState(() {
          _trackInfo = info;
        });
      }
    } catch (e) {
      debugPrint('Error loading credits: $e');
    }
  }

  Future<void> pickLyricsFile() async {
    final path = await _lyricsService.pickLRCFile();
    if (path != null && mounted) {
      widget.song.lyricsPath = path;
      widget.song.lyricsSource = 'manual';
      await widget.song.save();
      _loadLyrics();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lyrics file loaded!'),
          backgroundColor: Colors.deepPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> searchOnline() async {
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
            content: const Text('Lyrics not found'),
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

        // Only update palette when song actually changes
        if (_lastSongId != currentSong.id) {
          _lastSongId = currentSong.id;
          // Clear lyrics and reload for new song
          _lyrics = null;
          _showLyrics = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updatePalette(currentSong.localArtworkPath, currentSong.id);
            // Reload lyrics for new song
            _loadLyrics(currentSong);
            _loadArtistInfo(currentSong.artist);
            _loadCredits(currentSong.artist, currentSong.title);
          });
        }

        final accentColor = _accentColor ?? const Color(0xFF9B51E0);
        final uiColors = ColorUtils.getUiColors(accentColor);
        final textColor = uiColors.textColor;
        final buttonColor = uiColors.backgroundColor;
        final isDark = uiColors.isDark;

        return Scaffold(
          backgroundColor: isDark ? Colors.black : Colors.white,
          body: Dismissible(
            key: const Key('player_dismiss'),
            direction: DismissDirection.down,
            onDismissed: (_) => Navigator.of(context).pop(),
            child: Stack(
              children: [
                // Background
                _showBlur
                    ? _CachedBlurBackground(
                        artworkPath: currentSong.localArtworkPath,
                        accentColor: accentColor,
                        isDark: isDark,
                      )
                    : _SimpleGradientBackground(accentColor: accentColor, isDark: isDark),

                // Content
                SafeArea(
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity != null) {
                        if (details.primaryVelocity! > 500) {
                          // Swipe right → Previous song
                          controller.previous();
                          HapticFeedback.mediumImpact();
                        } else if (details.primaryVelocity! < -500) {
                          // Swipe left → Next song
                          controller.next();
                          HapticFeedback.mediumImpact();
                        }
                      }
                    },
                    child: CustomScrollView(
                      controller: _mainScrollController,
                      slivers: [
                        // Sticky header for "Now Playing"
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _StickyAppBarDelegate(
                            minHeight: 70,
                            maxHeight: 70,
                            child: buildAppBar(context, accentColor, textColor, buttonColor),
                          ),
                        ),

                        // Main Player Section (Full Screen Height minus header)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Column(
                            children: [
                              Expanded(
                                child: _showLyrics && _lyrics != null
                                    ? Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.black.withOpacity(0.9), // Always dark for white lyrics
                                              accentColor.withOpacity(0.4),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        margin: const EdgeInsets.all(16),
                                        child: LyricsView(
                                          lyrics: _lyrics!,
                                          currentPosition: controller.position,
                                          onSeek: (position) => controller.seek(position),
                                          onOffsetChanged: (newOffset) {
                                            setState(() {
                                              _lyrics = _lyrics!.copyWith(syncOffset: newOffset);
                                            });
                                          },
                                        ),
                                      )
                                    : _AlbumArtSection(
                                        currentSong: currentSong,
                                        heroTag: widget.heroTag,
                                        accentColor: accentColor,
                                        textColor: textColor,
                                      ),
                              ),
                              // Player controls
                              _PlayerControls(
                                controller: controller,
                                accentColor: accentColor,
                                textColor: textColor,
                                buttonColor: buttonColor,
                                bottomPadding: 50.0,
                              ),

                              // Arrow hint to scroll down
                              if (!_showLyrics) ...[
                                // Lyrics Card
                                if (_lyrics != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: _LyricsCard(
                                      lyrics: _lyrics!,
                                      currentPosition: controller.position,
                                      accentColor: accentColor,
                                      textColor: textColor,
                                      onTap: () {
                                        _mainScrollController.animateTo(
                                          0,
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                        setState(() {
                                          _showLyrics = true;
                                        });
                                      },
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Icon(Icons.keyboard_arrow_down_rounded, color: textColor.withOpacity(0.5)),
                              ],
                            ],
                          ),
                        ),

                        // About Artist Section
                        if (_artist != null && !_showLyrics)
                          SliverToBoxAdapter(
                            child: _AboutArtistSection(
                              artist: _artist!,
                              textColor: textColor,
                              accentColor: accentColor,
                              buttonColor: buttonColor,
                            ),
                          ),

                        // Credits Section
                        if (!_showLyrics)
                          SliverToBoxAdapter(
                            child: _CreditsSection(
                              song: currentSong,
                              trackInfo: _trackInfo,
                              textColor: textColor,
                              accentColor: accentColor,
                            ),
                          ),

                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildAppBar(BuildContext context, Color accentColor, Color textColor, Color buttonColor) {
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
              decoration: BoxDecoration(color: buttonColor, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Image.asset('assets/images/down.png', width: 20, height: 20, color: textColor)),
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
                style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
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
                    decoration: BoxDecoration(color: buttonColor, borderRadius: BorderRadius.circular(12)),
                    child: Center(
                      child: Image.asset(
                        _showLyrics ? 'assets/images/album.png' : 'assets/images/lyrics.png',
                        width: 20,
                        height: 20,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: buttonColor, borderRadius: BorderRadius.circular(12)),
                child: PopupMenuButton<String>(
                  icon: Image.asset('assets/images/more.png', width: 20, height: 20, color: textColor),
                  onSelected: (value) async {
                    switch (value) {
                      case 'upload':
                        await pickLyricsFile();
                        break;
                      case 'search':
                        await searchOnline();
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
                          const SizedBox(width: 12),
                          const Text('Upload .lrc file', style: TextStyle(color: Colors.black87)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'search',
                      child: Row(
                        children: [
                          Image.asset('assets/images/search.png', width: 20, height: 20, color: Colors.black87),
                          const SizedBox(width: 12),
                          const Text('Search lyrics', style: TextStyle(color: Colors.black87)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'equalizer',
                      child: Row(
                        children: [
                          Image.asset('assets/images/equalizer.png', width: 20, height: 20, color: Colors.black87),
                          const SizedBox(width: 12),
                          const Text('Equalizer', style: TextStyle(color: Colors.black87)),
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
}

// Separate widget for cached blur background to prevent rebuilds
class _CachedBlurBackground extends StatelessWidget {
  final String? artworkPath;
  final Color accentColor;
  final bool isDark;

  const _CachedBlurBackground({required this.artworkPath, required this.accentColor, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          // Gradient Background
          // Artwork Background
          if (artworkPath != null)
            Positioned.fill(
              child: Image.file(
                File(artworkPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: accentColor.withOpacity(0.1)),
              ),
            )
          else
            Positioned.fill(
              child: Image.asset('assets/images/album.png', fit: BoxFit.cover, color: accentColor.withOpacity(0.3)),
            ),

          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.6),
                    isDark ? Colors.black.withOpacity(0.9) : Colors.white.withOpacity(0.9),
                  ],
                ),
              ),
            ),
          ),

          // Blur Effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}

// Separate widget for album art section to prevent rebuilds
class _AlbumArtSection extends StatelessWidget {
  final Song currentSong;
  final String? heroTag;
  final Color accentColor;
  final Color textColor;

  const _AlbumArtSection({
    required this.currentSong,
    required this.heroTag,
    required this.accentColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Hero(
                  tag: heroTag ?? 'song_${currentSong.id}',
                  child: Container(
                    width: 240,
                    height: 240,
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
                          ? Image.file(File(currentSong.localArtworkPath!), fit: BoxFit.cover, cacheWidth: 600)
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
            const SizedBox(height: 24),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        currentSong.title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Favorite Button
                    GestureDetector(
                      onTap: () {
                        Provider.of<AudioController>(context, listen: false).toggleFavorite(currentSong);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(
                          'assets/images/favorite.png',
                          width: 24,
                          height: 24,
                          color: currentSong.isFavorite ? Colors.pink : textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Add to Playlist Button
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) => AddToPlaylistSheet(songs: [currentSong]),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Image.asset('assets/images/create.png', width: 24, height: 24, color: textColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  currentSong.artist,
                  style: TextStyle(color: accentColor, fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  currentSong.album,
                  style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// Separate widget for player controls with optimized rebuilds
class _PlayerControls extends StatelessWidget {
  final AudioController controller;
  final Color accentColor;
  final Color textColor;
  final Color buttonColor;
  final double bottomPadding;

  const _PlayerControls({
    required this.controller,
    required this.accentColor,
    required this.textColor,
    required this.buttonColor,
    this.bottomPadding = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 8, 24, bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5, elevation: 2, pressedElevation: 4),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: accentColor,
                      inactiveTrackColor: accentColor.withOpacity(0.3),
                      thumbColor: accentColor,
                      overlayColor: accentColor.withOpacity(0.1),
                    ),
                    child: Slider(
                      value: controller.position.inSeconds.toDouble().clamp(
                        0.0,
                        controller.duration.inSeconds.toDouble(),
                      ),
                      max: controller.duration.inSeconds.toDouble() > 0
                          ? controller.duration.inSeconds.toDouble()
                          : 1.0,
                      onChanged: (value) {
                        controller.seek(Duration(seconds: value.toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatDuration(controller.position),
                          style: TextStyle(
                            color: textColor.withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          formatDuration(controller.duration),
                          style: TextStyle(
                            color: textColor.withOpacity(0.8),
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
            const SizedBox(height: 16),
            // Control Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ControlButton(
                  imagePath: 'assets/images/shuffle.png',
                  isActive: controller.isShuffleEnabled,
                  onTap: controller.toggleShuffle,
                  size: 18,
                  accentColor: accentColor,
                  iconColor: textColor,
                  backgroundColor: buttonColor,
                  containerSize: 40,
                ),
                _ControlButton(
                  imagePath: 'assets/images/skip_previous.png',
                  size: 24,
                  onTap: controller.previous,
                  accentColor: accentColor,
                  iconColor: textColor,
                  backgroundColor: buttonColor,
                  containerSize: 40,
                ),
                _PlayButton(controller: controller, accentColor: accentColor),
                _ControlButton(
                  imagePath: 'assets/images/skip_next.png',
                  size: 24,
                  onTap: controller.next,
                  accentColor: accentColor,
                  iconColor: textColor,
                  backgroundColor: buttonColor,
                  containerSize: 40,
                ),
                _ControlButton(
                  imagePath: 'assets/images/repeat.png',
                  isActive: controller.repeatMode > 0,
                  onTap: controller.toggleRepeat,
                  size: 18,
                  accentColor: accentColor,
                  iconColor: textColor,
                  backgroundColor: buttonColor,
                  containerSize: 40,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (duration.inHours > 0) {
      return "${duration.inHours}:${twoDigits(minutes)}:${twoDigits(seconds)}";
    }
    return "$minutes:${twoDigits(seconds)}";
  }
}

// Optimized control button widget
class _ControlButton extends StatelessWidget {
  final String imagePath;
  final double size;
  final double containerSize;
  final bool isActive;
  final VoidCallback onTap;
  final Color accentColor;
  final Color iconColor;
  final Color backgroundColor;

  const _ControlButton({
    required this.imagePath,
    this.size = 24,
    this.containerSize = 48,
    this.isActive = false,
    required this.onTap,
    required this.accentColor,
    required this.iconColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: containerSize,
        height: containerSize,
        decoration: BoxDecoration(
          color: isActive ? accentColor.withOpacity(0.2) : backgroundColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Image.asset(imagePath, width: size, height: size, color: isActive ? accentColor : iconColor),
        ),
      ),
    );
  }
}

class _StickyAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _StickyAppBarDelegate({required this.minHeight, required this.maxHeight, required this.child});

  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight || minHeight != oldDelegate.minHeight || child != oldDelegate.child;
  }
}

class _AboutArtistSection extends StatelessWidget {
  final Artist artist;
  final Color textColor;
  final Color accentColor;
  final Color buttonColor;

  const _AboutArtistSection({
    required this.artist,
    required this.textColor,
    required this.accentColor,
    required this.buttonColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: buttonColor.withOpacity(0.1), // Slightly distinct background
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About the Artist',
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (artist.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  artist.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: accentColor.withOpacity(0.2),
                    child: Center(child: Icon(Icons.music_note, size: 48, color: accentColor)),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: accentColor.withOpacity(0.1),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          color: accentColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                artist.name,
                style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Icon(Icons.verified, color: Colors.blue, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          if (artist.biography != null) ...[
            Text(
              artist.biography!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                // Navigate to full artist details properly?
                // For now, simpler to just show snackbar or implement navigation if requested
                // User said "dekho mere pass artist detail page hain... sab yaha use hoga"
                // Ideally we navigate:
                // Navigator.of(context).push(...)
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: textColor.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'See more',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CreditsSection extends StatelessWidget {
  final Song song;
  final Map<String, dynamic>? trackInfo;
  final Color textColor;
  final Color accentColor;

  const _CreditsSection({required this.song, this.trackInfo, required this.textColor, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Credits',
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          buildCreditRow('Performed by', song.artist),
          const SizedBox(height: 12),
          buildCreditRow('Written by', _getWriter()),
          const SizedBox(height: 12),
          buildCreditRow('Produced by', _getProducer()),
          if (trackInfo != null && trackInfo!['track'] != null && trackInfo!['track']['wiki'] != null) ...[
            const SizedBox(height: 20),
            Text(
              'Track Info',
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              stripHtml(trackInfo!['track']['wiki']['summary'] ?? ''),
              style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String _getWriter() {
    // Extract writer from Spotify trackInfo
    if (trackInfo != null && trackInfo!['track'] != null) {
      final track = trackInfo!['track'];
      // Spotify response has 'writer' field
      if (track['writer'] != null && track['writer'] is String) {
        return track['writer'];
      }
      // Fallback to artist field
      if (track['artist'] != null && track['artist'] is String) {
        return track['artist'];
      }
    }
    return song.artist;
  }

  String _getProducer() {
    // Extract producer from Spotify trackInfo
    if (trackInfo != null && trackInfo!['track'] != null) {
      final track = trackInfo!['track'];
      // Spotify response has 'producer' or 'label' field
      if (track['producer'] != null && track['producer'] is String && track['producer'] != 'Unknown') {
        return track['producer'];
      }
      // Fallback to label
      if (track['label'] != null && track['label'] is String && track['label'] != 'Unknown') {
        return track['label'];
      }
    }
    return 'Unknown';
  }

  String stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  Widget buildCreditRow(String role, String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(role, style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14)),
        Text(
          name,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }
}

class _LyricsCard extends StatelessWidget {
  final Lyrics lyrics;
  final Duration currentPosition;
  final Color accentColor;
  final Color textColor;
  final VoidCallback onTap;

  const _LyricsCard({
    required this.lyrics,
    required this.currentPosition,
    required this.accentColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Find current line
    int currentIndex = 0;
    for (int i = 0; i < lyrics.lines.length; i++) {
      if (currentPosition >= lyrics.lines[i].timestamp) {
        currentIndex = i;
      } else {
        break;
      }
    }

    final currentLine = currentIndex < lyrics.lines.length ? lyrics.lines[currentIndex].text : '';
    final nextLine = currentIndex + 1 < lyrics.lines.length ? lyrics.lines[currentIndex + 1].text : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: accentColor.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LYRICS',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: textColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    'SHOW',
                    style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              currentLine.isNotEmpty ? currentLine : (lyrics.lines.isEmpty ? 'Lyrics available' : '...'),
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (nextLine.isNotEmpty)
              Text(
                nextLine,
                style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 16, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

// Optimized play button widget
class _PlayButton extends StatelessWidget {
  final AudioController controller;
  final Color accentColor;

  const _PlayButton({required this.controller, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (controller.isPlaying) {
          controller.pause();
        } else {
          controller.resume();
        }
      },
      child: Container(
        width: 64,
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
}

// Simple gradient background for instant opening (no blur)
class _SimpleGradientBackground extends StatelessWidget {
  final Color accentColor;
  final bool isDark;

  const _SimpleGradientBackground({required this.accentColor, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accentColor.withOpacity(0.1), isDark ? Colors.black : Colors.white, accentColor.withOpacity(0.05)],
          ),
        ),
      ),
    );
  }
}
