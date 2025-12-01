import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../controllers/audio_controller.dart';
import '../controllers/home_controller.dart';
import '../../data/models/song_model.dart';
import '../../data/services/auth_service.dart';
import 'playlist_details_page.dart';
import 'profile_page.dart';
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
        backgroundColor: Colors.grey[50],
        body: Consumer<HomeController>(
          builder: (context, homeController, child) {
            final audioController = context.read<AudioController>();

            if (audioController.songs.isEmpty && !homeController.isLoading) {
              return _buildEmptyState(audioController);
            }

            if (homeController.isLoading && audioController.songs.isEmpty) {
              return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
            }

            return CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                _buildHeader(),
                _buildRecentlyPlayed(homeController, audioController),
                _buildTopArtists(homeController),
                _buildQuickPlaylists(homeController, audioController),
                _buildGenreSections(homeController, audioController),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final opacity = (_scrollOffset / 100).clamp(0.0, 1.0);

    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: opacity * 4,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (opacity > 0.5)
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5)),
            ],
          ),
          child: IconButton(
            icon: Icon(Icons.search_rounded, color: opacity > 0.5 ? Colors.deepPurple : Colors.white),
            onPressed: () {},
          ),
        ),
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfilePage(
                  userName: _homeController.userName,
                  onNameUpdate: (name) async {
                    await _homeController.updateUserName(name);
                    setState(() {}); // Refresh UI after name update
                  },
                ),
              ),
            );
            // Refresh UI when returning from profile page (in case user signed in/out)
            setState(() {});
          },
          child: Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
            ),
            child: _authService.isLoggedIn && _authService.userPhotoUrl != null
                ? CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(_authService.userPhotoUrl!),
                    backgroundColor: Colors.grey[200],
                  )
                : const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.deepPurple, size: 20),
                  ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 200),
          child: Text(
            _getGreeting(),
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade500, Colors.purple.shade400],
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(offset: Offset(0, 2), blurRadius: 8, color: Colors.black26)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Your personal music feed', style: TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ),
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
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
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
                    width: 140, // Reduced width
                    height: 140, // Reduced height
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
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
                    top: 6, // Adjusted position
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4), // Reduced padding
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withValues(alpha: 0.5),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 14), // Reduced icon
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8), // Reduced spacing
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13, // Reduced font
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11, // Reduced font
              ),
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
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 12), // Reduced padding
              child: Text(
                'Your Top Artists',
                style: TextStyle(
                  fontSize: 22, // Reduced font
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
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
          borderRadius: BorderRadius.circular(16), // Reduced radius
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepPurple.shade400, Colors.purple.shade600],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withValues(alpha: 0.3),
              blurRadius: 12, // Reduced blur
              offset: const Offset(0, 6), // Reduced offset
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background image if available
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
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12), // Reduced padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16, // Reduced font
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1), // Reduced shadow
                          blurRadius: 4,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2), // Reduced spacing
                  Text(
                    '${artist.songCount} songs',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11, // Reduced font
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

  Widget _buildQuickPlaylists(HomeController homeController, AudioController audioController) {
    return SliverToBoxAdapter(
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 12), // Reduced padding
              child: Text(
                'Made For You',
                style: TextStyle(
                  fontSize: 22, // Reduced font
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            SizedBox(
              height: 160, // Reduced height
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildPlaylistCard(
                    'Most Played',
                    '${homeController.mostPlayed.length} songs',
                    Icons.trending_up_rounded,
                    [Colors.orange.shade400, Colors.deepOrange.shade600],
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
                    Icons.new_releases_rounded,
                    [Colors.blue.shade400, Colors.indigo.shade600],
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
    IconData icon,
    List<Color> gradientColors,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150, // Reduced width
        margin: const EdgeInsets.symmetric(horizontal: 6), // Reduced margin
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), // Reduced radius
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradientColors),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.4),
              blurRadius: 12, // Reduced blur
              offset: const Offset(0, 6), // Reduced offset
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
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

    // Limit to 3 genres to prevent overflow
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
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12), // Reduced padding
            child: Text(
              genre,
              style: const TextStyle(
                fontSize: 20, // Reduced font
                fontWeight: FontWeight.bold,
                color: Colors.black87,
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
        width: 120, // Reduced width
        margin: const EdgeInsets.symmetric(horizontal: 6), // Reduced margin
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 120, // Reduced width
                  height: 120, // Reduced height
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12), // Reduced radius
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8, // Reduced blur
                        offset: const Offset(0, 4), // Reduced offset
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
                      padding: const EdgeInsets.all(3), // Reduced padding
                      decoration: BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                      child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 12), // Reduced icon
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6), // Reduced spacing
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12, // Reduced font
                color: Colors.black87,
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
      context.pushNamed('player', extra: song);
    }
  }

  Widget _buildEmptyState(AudioController audioController) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0), // Reduced padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120, // Reduced size
              height: 120,
              decoration: BoxDecoration(color: Colors.deepPurple.shade50, shape: BoxShape.circle),
              child: Icon(Icons.library_music_outlined, size: 50, color: Colors.deepPurple.shade300), // Reduced icon
            ),
            const SizedBox(height: 20), // Reduced spacing
            const Text(
              'No Music Found',
              style: TextStyle(
                fontSize: 22, // Reduced font
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8), // Reduced spacing
            const Text(
              'We need permission to access your audio files',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14, // Reduced font
              ),
            ),
            const SizedBox(height: 20), // Reduced spacing
            GestureDetector(
              onTap: () async {
                await audioController.loadSongs();
                await _homeController.loadHomeData(audioController);
              },
              child: Container(
                height: 48, // Reduced height
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.deepPurple.shade600, Colors.purple.shade600]),
                  borderRadius: BorderRadius.circular(12), // Reduced radius
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withValues(alpha: 0.3),
                      blurRadius: 12, // Reduced blur
                      offset: const Offset(0, 6), // Reduced offset
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Grant Permission & Reload',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14, // Reduced font
                      fontWeight: FontWeight.w600,
                    ),
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
