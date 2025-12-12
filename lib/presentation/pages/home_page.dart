import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../controllers/audio_controller.dart';
import '../controllers/home_controller.dart';
import '../../data/models/song_model.dart';
import '../../data/services/auth_service.dart';
import 'playlist_details_page.dart';
import 'dart:ui';
import '../widgets/glass_background.dart';
import '../widgets/hybrid_song_artwork.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late HomeController _homeController;
  AudioController? _audioController;
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService();
  double _scrollOffset = 0;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _homeController = HomeController();
    _scrollController.addListener(_onScroll);
    // Defer loading to next frame to ensure context is available if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _onScroll() {
    // Throttle scroll updates - only update if difference > 10 pixels
    final currentOffset = _scrollController.offset;
    if ((currentOffset - _lastScrollOffset).abs() > 10) {
      setState(() {
        _scrollOffset = currentOffset;
        _lastScrollOffset = currentOffset;
      });
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    _audioController = Provider.of<AudioController>(context, listen: false);
    // Only load songs if the list is empty to prevent resetting playback on tab switch
    if (_audioController!.songs.isEmpty) {
      await _audioController!.loadSongs();
    }
    if (!mounted) return;
    await _homeController.loadHomeData(_audioController!);

    // Listen for playback changes to refresh recently played
    // Note: This listener is added only once during initialization
    _audioController!.addListener(_onPlaybackChanged);
  }

  void _onPlaybackChanged() {
    if (!mounted) return;
    final audioController = Provider.of<AudioController>(context, listen: false);
    // Only reload if a new song started playing
    if (audioController.isPlaying &&
        _homeController.recentlyPlayed.firstOrNull?.id != audioController.currentSong?.id) {
      _homeController.loadHomeData(audioController);
    }
  }

  @override
  void dispose() {
    _audioController?.removeListener(_onPlaybackChanged);
    _homeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    return _authService.getGreeting(includeUserName: true);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _homeController,
      child: Scaffold(
        extendBody: true, // Allow content to flow behind nav bar
        body: Stack(
          children: [
            // Dynamic Glass Background
            Consumer<AudioController>(
              builder: (context, controller, child) {
                return GlassBackground(
                  artworkPath: controller.currentSong?.localArtworkPath,
                  accentColor: controller.accentColor,
                  isDark: Theme.of(context).brightness == Brightness.dark,
                );
              },
            ),

            // Content
            Consumer<HomeController>(
              builder: (context, homeController, child) {
                final audioController = context.watch<AudioController>(); // Watch for color changes

                if (audioController.songs.isEmpty && !homeController.isLoading) {
                  return _buildEmptyState(audioController);
                }

                if (homeController.isLoading && audioController.songs.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }

                return CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    _buildHeader(audioController.accentColor),
                    _buildRecentlyPlayed(homeController, audioController),
                    _buildTopArtists(homeController),
                    _buildQuickPlaylists(homeController, audioController),
                    _buildGenreSections(homeController, audioController),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color accentColor) {
    // Standardize opacity logic (0 to 1 based on scroll)
    final opacity = (_scrollOffset / 100).clamp(0.0, 1.0);

    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      // Standard Dark Glass Header Background
      backgroundColor: opacity > 0.8
          ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.8)
          : Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      // Add blur when scrolled
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: opacity * 20, sigmaY: opacity * 20),
          child: FlexibleSpaceBar(
            title: AnimatedOpacity(
              opacity: opacity,
              duration: const Duration(milliseconds: 200),
              child: Text(
                _getGreeting(),
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
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0.2), // Adaptive fade
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 36,
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
                      const SizedBox(height: 8),
                      Text(
                        'Your personal music feed',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      actions: [
        // Search Button - tailored for glass (Dynamic)
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha: 0.2)),
          ),
          child: IconButton(
            icon: Image.asset(
              'assets/images/search.png',
              width: 24,
              height: 24,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {},
          ),
        ),
        // Profile Avatar
        GestureDetector(
          onTap: () async {
            final result = await context.push<String>('/profile');
            if (result != null) {
              await _homeController.updateUserName(result);
            }
            if (mounted) setState(() {});
          },
          child: Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), width: 2),
            ),
            child: _authService.isLoggedIn && _authService.userPhotoUrl != null
                ? CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(_authService.userPhotoUrl!),
                    backgroundColor: Colors.grey[900],
                  )
                : CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    child: Image.asset(
                      'assets/images/profile.png',
                      width: 20,
                      height: 20,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentlyPlayed(HomeController homeController, AudioController audioController) {
    if (homeController.recentlyPlayed.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Text(
                'Recently Played',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            SizedBox(
              height: 190,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: homeController.recentlyPlayed.length,
                addAutomaticKeepAlives: true,
                cacheExtent: 500,
                itemBuilder: (context, index) {
                  final song = homeController.recentlyPlayed[index];
                  return RepaintBoundary(
                    key: ValueKey('recent_${song.id}'),
                    child: _buildRecentSongCard(song, audioController),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSongCard(Song song, AudioController audioController) {
    final isCurrentlyPlaying = audioController.currentSong?.id == song.id;
    final isPlaying = isCurrentlyPlaying && audioController.isPlaying;

    return GestureDetector(
      onTap: () => _playSong(song, audioController),
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Hero(
                  tag: 'song_${song.id}',
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).shadowColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: HybridSongArtwork.fromSong(song: song, size: 140, borderRadius: 16),
                  ),
                ),
                if (isPlaying)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: audioController.accentColor, // Dynamic
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: audioController.accentColor.withValues(alpha: 0.5),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Image.asset('assets/images/equalizer.png', width: 14, height: 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopArtists(HomeController homeController) {
    if (homeController.topArtists.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final artists = homeController.topArtists.values.take(4).toList();

    return SliverToBoxAdapter(
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Text(
                'Your Top Artists',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: artists.length,
              itemBuilder: (context, index) {
                final artist = artists[index];
                return RepaintBoundary(child: _buildArtistCard(artist));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistCard(ArtistStats artist) {
    return GestureDetector(
      onTap: () {
        context.pushNamed('artist_details', pathParameters: {'name': artist.name});
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.05), // Subtle glass fill
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (artist.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  artist.imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(),
                ),
              ),
            // Gradient overlay - darker for better image visibility
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8), // Dark gradient only at bottom
                  ],
                  stops: const [0.0, 0.5, 1.0], // Keep top 50% completely clear
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white, // Always white for better contrast on dark gradient
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: [
                        Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black.withValues(alpha: 0.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${artist.songCount} songs',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPlaylists(HomeController homeController, AudioController audioController) {
    return SliverToBoxAdapter(
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Text(
                'Made For You',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            SizedBox(
              height: 160,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildPlaylistCard(
                    'Most Played',
                    '${homeController.mostPlayed.length} songs',
                    'most_played.png',
                    [Colors.orange.shade600, Colors.deepOrange.shade600], // Solid vibrant gradient
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PlaylistDetailsPage(
                            title: 'Most Played',
                            songs: homeController.mostPlayed,
                            gradientColors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                          ),
                        ),
                      );
                    },
                  ),
                  _buildPlaylistCard(
                    'Recently Added',
                    '${homeController.recentlyAdded.length} songs',
                    'recently_added.png',
                    [Colors.blue.shade600, Colors.indigo.shade600], // Solid vibrant gradient
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PlaylistDetailsPage(
                            title: 'Recently Added',
                            songs: homeController.recentlyAdded,
                            gradientColors: [Colors.blue.shade400, Colors.indigo.shade600],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistCard(
    String title,
    String subtitle,
    String iconAsset,
    List<Color> gradientColors,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [
            BoxShadow(color: gradientColors.first.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25), // Semi-transparent white background for icon
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/images/$iconAsset',
                  color: Colors.white, // White icon for visibility
                  width: 24,
                  height: 24,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenreSections(HomeController homeController, AudioController audioController) {
    if (homeController.genreSongs.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final limitedGenres = homeController.genreSongs.entries.take(3).toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final entry = limitedGenres[index];
        return _buildGenreSection(entry.key, entry.value, audioController);
      }, childCount: limitedGenres.length),
    );
  }

  Widget _buildGenreSection(String genre, List<Song> songs, AudioController audioController) {
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Text(
              genre,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface, // Dark theme text
              ),
            ),
          ),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: songs.take(8).length,
              addAutomaticKeepAlives: true,
              cacheExtent: 400,
              itemBuilder: (context, index) {
                final song = songs[index];
                return RepaintBoundary(child: _buildGenreSongCard(song, audioController));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreSongCard(Song song, AudioController audioController) {
    final isCurrentlyPlaying = audioController.currentSong?.id == song.id;
    final isPlaying = isCurrentlyPlaying && audioController.isPlaying;

    return GestureDetector(
      onTap: () => _playSong(song, audioController),
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: HybridSongArtwork.fromSong(song: song, size: 120, borderRadius: 12),
                ),
                if (isPlaying)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: audioController.accentColor, shape: BoxShape.circle), // Dynamic
                      child: Image.asset('assets/images/equalizer.png', width: 12, height: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface, // White text
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to play song and navigate
  Future<void> _playSong(Song song, AudioController audioController) async {
    await audioController.playSong(song);
    await _homeController.trackRecentlyPlayed(song.id);
    if (mounted) {
      context.pushNamed('player', extra: {'song': song, 'heroTag': 'song_${song.id}'});
    }
  }

  Widget _buildEmptyState(AudioController audioController) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Dark glass empty state
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.05), // Dark glass
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
              ),
              child: Image.asset(
                'assets/images/album_list_open.png',
                width: 50,
                height: 50,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Music Found',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We need permission to access your audio files',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                await audioController.loadSongs();
                await _homeController.loadHomeData(audioController);
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.deepPurple.shade600, Colors.purple.shade600]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Grant Permission & Reload',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
