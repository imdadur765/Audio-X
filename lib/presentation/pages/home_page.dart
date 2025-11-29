import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/audio_controller.dart';
import '../controllers/home_controller.dart';
import '../../data/models/song_model.dart';
import '../../data/services/auth_service.dart';
import 'player_page.dart';
import 'package:audio_x/presentation/pages/artists_screen.dart';
import 'package:audio_x/data/models/artist_model.dart';
import 'package:audio_x/data/models/local_song_model.dart';
import 'playlist_details_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late HomeController _homeController;
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _homeController = HomeController();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  Future<void> _loadData() async {
    final audioController = Provider.of<AudioController>(context, listen: false);
    await audioController.loadSongs();
    await _homeController.loadHomeData(audioController);

    // Listen for playback changes to refresh recently played
    audioController.addListener(() {
      if (audioController.isPlaying &&
          _homeController.recentlyPlayed.firstOrNull?.id != audioController.currentSong?.id) {
        _homeController.loadHomeData(audioController);
      }
    });
  }

  @override
  void dispose() {
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
        body: Consumer2<HomeController, AudioController>(
          builder: (context, homeController, audioController, child) {
            if (audioController.songs.isEmpty) {
              return _buildEmptyState(audioController);
            }

            if (homeController.isLoading) {
              return _buildLoadingState();
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
                _buildAllSongsSection(homeController, audioController),
                const SliverToBoxAdapter(child: SizedBox(height: 120)), // Increased bottom padding
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: Colors.deepPurple.shade100, shape: BoxShape.circle),
            child: const Icon(Icons.music_note_rounded, size: 40, color: Colors.deepPurple),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Your Music',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.deepPurple.shade800),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyPlayed(HomeController homeController, AudioController audioController) {
    if (homeController.recentlyPlayed.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Text(
              'Recently Played',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          SizedBox(
            height: 190, // Reduced height
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: homeController.recentlyPlayed.length,
              itemBuilder: (context, index) {
                final song = homeController.recentlyPlayed[index];
                return _buildRecentSongCard(song, audioController);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSongCard(Song song, AudioController audioController) {
    final isCurrentlyPlaying = audioController.currentSong?.id == song.id;
    final isPlaying = isCurrentlyPlaying && audioController.isPlaying;

    return GestureDetector(
      onTap: () => _playSong(song, audioController),
      child: Container(
        width: 140, // Reduced width
        margin: const EdgeInsets.symmetric(horizontal: 6), // Reduced margin
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: song.localArtworkPath != null
                          ? Image.file(
                              File(song.localArtworkPath!),
                              fit: BoxFit.cover,
                              cacheWidth: 280, // Optimized image loading
                              cacheHeight: 280,
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Colors.deepPurple.shade300, Colors.purple.shade500],
                                ),
                              ),
                              child: const Icon(
                                Icons.music_note_rounded,
                                size: 40,
                                color: Colors.white70,
                              ), // Reduced icon
                            ),
                    ),
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

    final artists = homeController.topArtists.values.take(4).toList(); // Reduced to 4 artists

    return SliverToBoxAdapter(
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
              childAspectRatio: 1.4, // Slightly reduced aspect ratio
              crossAxisSpacing: 12, // Reduced spacing
              mainAxisSpacing: 12,
            ),
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artist = artists[index];
              return _buildArtistCard(artist);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildArtistCard(ArtistStats artist) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => ArtistDetailsSheet(
            artist: Artist(
              id: artist.cachedData?.spotifyId ?? '',
              name: artist.name,
              imageUrl: artist.imageUrl,
              songsCount: artist.songCount,
              localSongsCount: artist.songs.length,
              followers: artist.cachedData?.followers != null ? '${artist.cachedData!.followers}' : 'Local Artist',
              popularSongs: [],
              localSongs: artist.songs
                  .map(
                    (s) => LocalSong(
                      id: s.id,
                      title: s.title,
                      artist: s.artist,
                      album: s.album,
                      path: s.uri.toString(),
                      duration: s.duration,
                      size: 0, // Default size as it's not available in Song model
                    ),
                  )
                  .toList(),
              popularity: artist.cachedData?.popularity ?? 0,
              genres: artist.cachedData?.genres ?? [],
            ),
          ),
        );
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
    return Column(
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
          height: 150, // Reduced height
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: songs.take(8).length, // Reduced items
            itemBuilder: (context, index) {
              final song = songs[index];
              return _buildGenreSongCard(song, audioController);
            },
          ),
        ),
      ],
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: song.localArtworkPath != null
                        ? Image.file(
                            File(song.localArtworkPath!),
                            fit: BoxFit.cover,
                            cacheWidth: 240, // Optimized image loading
                            cacheHeight: 240,
                          )
                        : Container(
                            color: Colors.deepPurple.shade100,
                            child: const Icon(
                              Icons.music_note_rounded,
                              size: 32,
                              color: Colors.deepPurple,
                            ), // Reduced icon
                          ),
                  ),
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

  Widget _buildAllSongsSection(HomeController homeController, AudioController audioController) {
    if (homeController.allSongs.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    // Limit songs to prevent overflow
    final limitedSongs = homeController.allSongs.take(20).toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12), // Reduced padding
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'All Songs',
                  style: TextStyle(
                    fontSize: 22, // Reduced font
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final songs = List<Song>.from(homeController.allSongs)..shuffle();
                    await audioController.playSong(songs.first);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduced padding
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(10), // Reduced radius
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shuffle_rounded, color: Colors.white, size: 16), // Reduced icon
                        SizedBox(width: 4), // Reduced spacing
                        Text(
                          'Shuffle',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12, // Reduced font
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final song = limitedSongs[index - 1];
        final isCurrentlyPlaying = audioController.currentSong?.id == song.id;
        final isPlaying = isCurrentlyPlaying && audioController.isPlaying;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2), // Reduced margin
          decoration: BoxDecoration(
            color: isCurrentlyPlaying ? Colors.deepPurple.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12), // Reduced radius
            boxShadow: [
              if (!isCurrentlyPlaying)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6, // Reduced blur
                  offset: const Offset(0, 1), // Reduced offset
                ),
            ],
            border: Border.all(
              color: isCurrentlyPlaying ? Colors.deepPurple.withValues(alpha: 0.3) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _playSong(song, audioController),
              child: Padding(
                padding: const EdgeInsets.all(10), // Reduced padding
                child: Row(
                  children: [
                    // Song Artwork
                    Stack(
                      children: [
                        Container(
                          width: 44, // Reduced size
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8), // Reduced radius
                            color: Colors.grey.shade100,
                            image: song.localArtworkPath != null
                                ? DecorationImage(image: FileImage(File(song.localArtworkPath!)), fit: BoxFit.cover)
                                : null,
                          ),
                          child: song.localArtworkPath == null
                              ? const Center(
                                  child: Icon(Icons.music_note_rounded, color: Colors.grey, size: 18),
                                ) // Reduced icon
                              : null,
                        ),
                        if (isPlaying)
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(Icons.equalizer_rounded, color: Colors.white, size: 16), // Reduced icon
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10), // Reduced spacing
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
                              color: isCurrentlyPlaying ? Colors.deepPurple : Colors.black87,
                              fontWeight: isCurrentlyPlaying ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 14, // Reduced font
                            ),
                          ),
                          const SizedBox(height: 1), // Reduced spacing
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrentlyPlaying ? Colors.deepPurple.shade600 : Colors.grey.shade600,
                              fontSize: 11, // Reduced font
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Playing Indicator
                    if (isPlaying)
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0.8, end: 1.2),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, double value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Icon(Icons.volume_up_rounded, color: Colors.deepPurple, size: 16), // Reduced icon
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }, childCount: limitedSongs.length + 1),
    );
  }

  // Helper method to play song and navigate
  Future<void> _playSong(Song song, AudioController audioController) async {
    await audioController.playSong(song);
    await _homeController.trackRecentlyPlayed(song.id);
    if (mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => PlayerPage(song: song)));
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
