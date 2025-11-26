import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/audio_controller.dart';
import '../controllers/home_controller.dart';
import '../../data/models/song_model.dart';
import 'player_page.dart';
import 'artist_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late HomeController _homeController;

  @override
  void initState() {
    super.initState();
    _homeController = HomeController();
    _loadData();
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
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _homeController,
      child: Scaffold(
        body: Consumer2<HomeController, AudioController>(
          builder: (context, homeController, audioController, child) {
            if (audioController.songs.isEmpty) {
              return _buildEmptyState(audioController);
            }

            if (homeController.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return CustomScrollView(
              slivers: [
                _buildHeader(),
                _buildRecentlyPlayed(homeController, audioController),
                _buildTopArtists(homeController),
                _buildQuickPlaylists(homeController, audioController),
                _buildGenreSections(homeController, audioController),
                const SliverPadding(padding: EdgeInsets.only(bottom: 80)), // Space for mini player
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _getGreeting(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(offset: Offset(0, 2), blurRadius: 4, color: Colors.black26)],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Your personal music feed', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded, color: Colors.white),
          onPressed: () {},
        ),
      ],
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
            padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text('Recently Played', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            height: 200,
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
    return GestureDetector(
      onTap: () async {
        await audioController.playSong(song);
        await _homeController.trackRecentlyPlayed(song.id);
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => PlayerPage(song: song)));
        }
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'song_${song.id}',
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: song.localArtworkPath != null
                      ? Image.file(File(song.localArtworkPath!), fit: BoxFit.cover)
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.deepPurple.shade300, Colors.purple.shade500],
                            ),
                          ),
                          child: const Icon(Icons.music_note_rounded, size: 48, color: Colors.white70),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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

    final artists = homeController.topArtists.values.take(6).toList();

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text('Your Top Artists', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                ArtistPage(artistName: artist.name, localSongs: artist.songs, cachedSpotifyData: artist.cachedData),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepPurple.shade400.withValues(alpha: 0.8), Colors.purple.shade600.withValues(alpha: 0.8)],
          ),
          boxShadow: [
            BoxShadow(color: Colors.deepPurple.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Stack(
          children: [
            // Background image if available
            if (artist.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: [Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black45)],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('${artist.songCount} songs', style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
            padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text('Made For You', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            height: 180,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildPlaylistCard(
                  'Most Played',
                  '${homeController.mostPlayed.length} songs',
                  Icons.trending_up_rounded,
                  [Colors.orange.shade400, Colors.deepOrange.shade600],
                  () => _playPlaylist(homeController.mostPlayed, audioController),
                ),
                _buildPlaylistCard(
                  'Recently Added',
                  '${homeController.recentlyAdded.length} songs',
                  Icons.new_releases_rounded,
                  [Colors.green.shade400, Colors.teal.shade600],
                  () => _playPlaylist(homeController.recentlyAdded, audioController),
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
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradientColors),
          boxShadow: [
            BoxShadow(color: gradientColors.first.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white, size: 48),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final entry = homeController.genreSongs.entries.elementAt(index);
        return _buildGenreSection(entry.key, entry.value, audioController);
      }, childCount: homeController.genreSongs.length),
    );
  }

  Widget _buildGenreSection(String genre, List<Song> songs, AudioController audioController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(genre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: songs.take(10).length,
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
    return GestureDetector(
      onTap: () async {
        await audioController.playSong(song);
        await _homeController.trackRecentlyPlayed(song.id);
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => PlayerPage(song: song)));
        }
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 3)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: song.localArtworkPath != null
                    ? Image.file(File(song.localArtworkPath!), fit: BoxFit.cover)
                    : Container(
                        color: Colors.deepPurple.shade100,
                        child: const Icon(Icons.music_note_rounded, size: 40, color: Colors.deepPurple),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _playPlaylist(List<Song> songs, AudioController audioController) async {
    if (songs.isEmpty) return;
    await audioController.playSong(songs.first);
    await _homeController.trackRecentlyPlayed(songs.first.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('Playing ${songs.length} songs'),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.deepPurple,
        ),
      );
    }
  }

  Widget _buildEmptyState(AudioController audioController) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_music_outlined, size: 80, color: Colors.deepPurple.withValues(alpha: 0.5)),
            const SizedBox(height: 24),
            const Text('No Music Found', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'We need permission to access your audio files',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await audioController.loadSongs();
                await _homeController.loadHomeData(audioController);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Grant Permission & Reload'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
