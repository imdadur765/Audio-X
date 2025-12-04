import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/artist_model.dart';
import '../../data/models/song_model.dart';
import '../../data/services/artist_service.dart';
import '../controllers/audio_controller.dart';
import 'player_page.dart';
import '../widgets/glass_button.dart';

class ArtistDetailsPage extends StatefulWidget {
  final String artistName;
  final String? heroTag;

  const ArtistDetailsPage({super.key, required this.artistName, this.heroTag});

  @override
  State<ArtistDetailsPage> createState() => _ArtistDetailsPageState();
}

class _ArtistDetailsPageState extends State<ArtistDetailsPage> {
  final ArtistService _artistService = ArtistService();
  final ScrollController _scrollController = ScrollController();
  late Future<Artist?> _artistFuture;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Fetch WITH bio for detail page
    _artistFuture = _artistService.getArtistInfo(widget.artistName, fetchBio: true);
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<AudioController>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FutureBuilder<Artist?>(
        future: _artistFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScreen();
          }

          final artistData = snapshot.data;
          // Create a temporary Artist object if data is null (offline/error)
          final artist = artistData ?? Artist(name: widget.artistName, lastUpdated: DateTime.now(), tags: []);

          // Find songs by this artist
          final artistSongs = controller.songs
              .where((s) => s.artist.toLowerCase().contains(widget.artistName.toLowerCase()))
              .toList();

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildAppBar(artist),
              _buildArtistHeader(artist),
              _buildStatsSection(artist, artistSongs),
              _buildActionButtons(artistSongs),
              _buildSongsList(artistSongs),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple.shade100, Colors.blue.shade100],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: const Icon(Icons.person_rounded, size: 40, color: Colors.deepPurple),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading Artist...',
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
      ),
    );
  }

  Widget _buildAppBar(Artist artist) {
    final opacity = (_scrollOffset / 100).clamp(0.0, 1.0);

    return SliverAppBar(
      expandedHeight: 350,
      pinned: true,
      floating: false,
      backgroundColor: Colors.white,
      elevation: opacity * 4,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GlassButton(
          imagePath: 'assets/images/back.png',
          onTap: () => Navigator.of(context).pop(),
          size: 24,
          containerSize: 40,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 200),
          child: Text(
            artist.name,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18),
          ),
        ),
        background: artist.imageUrl != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: widget.heroTag ?? 'artist_${artist.name}',
                    child: Image.network(
                      artist.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderImage();
                      },
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                  // Gradient overlay for better text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const [0.0, 0.3, 1.0],
                      ),
                    ),
                  ),
                ],
              )
            : _buildPlaceholderImage(),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple.shade600, Colors.purple.shade800],
        ),
      ),
      child: Stack(
        children: [
          // Animated background elements
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Icon(Icons.person_rounded, size: 60, color: Colors.white54),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistHeader(Artist artist) {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              artist.name,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            // Verified Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, size: 16, color: Colors.green.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'Verified Artist',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(Artist artist, List<Song> songs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Spotify Stats Card
            _buildSpotifyStatsCard(artist),

            const SizedBox(height: 16),

            // Biography Section
            if (artist.biography != null && artist.biography!.isNotEmpty) ...[
              _buildBiographySection(artist.biography!),
              const SizedBox(height: 16),
            ],

            // Similar Artists Section
            if (artist.similarArtists.isNotEmpty) ...[
              _buildSectionTitle('Fans Also Like'),
              const SizedBox(height: 12),
              _buildSimilarArtistsList(artist.similarArtists),
              const SizedBox(height: 24),
            ],

            // Top Albums Section
            if (artist.topAlbums.isNotEmpty) ...[
              _buildSectionTitle('Top Albums'),
              const SizedBox(height: 12),
              _buildTopAlbumsList(artist.topAlbums),
              const SizedBox(height: 24),
            ],

            // Local Stats Card
            _buildLocalStatsCard(songs),

            const SizedBox(height: 16),

            // Partner Credits
            _buildPartnerCredits(),
          ],
        ),
      ),
    );
  }

  Widget _buildSpotifyStatsCard(Artist artist) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF191414), Color(0xFF121212)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1DB954).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1DB954).withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset('assets/images/spotify_logo.png', width: 24, height: 24),
              ),
              const SizedBox(width: 16),
              const Text(
                'Spotify Stats',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Followers
          if (artist.followers > 0)
            _buildStatRow(
              imagePath: 'assets/images/followers.png',
              value: _formatNumber(artist.followers),
              label: 'Followers',
              color: const Color(0xFF1DB954),
              textColor: Colors.white,
            ),

          const SizedBox(height: 20),

          // Popularity
          if (artist.popularity > 0) ...[_buildPopularityBar(artist.popularity), const SizedBox(height: 20)],

          // Genres
          if (artist.tags.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Genres',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: artist.tags.map((genre) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    genre,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade200),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required String imagePath,
    required String value,
    required String label,
    required Color color,
    Color? textColor,
  }) {
    return Row(
      children: [
        Image.asset(imagePath, width: 24, height: 24, color: color),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor ?? color),
            ),
            Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ],
        ),
      ],
    );
  }

  Widget _buildPopularityBar(int popularity) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset('assets/images/popularity.png', width: 24, height: 24, color: const Color(0xFF1DB954)),
            const SizedBox(width: 16),
            Text(
              'Popularity',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade400),
            ),
            const Spacer(),
            Text(
              '$popularity%',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1DB954)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3)),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: (popularity / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1DB954).withValues(alpha: 0.5),
                        blurRadius: 6,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocalStatsCard(List<Song> songs) {
    int totalDuration = songs.fold(0, (sum, item) => sum + item.duration);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLocalStatItem(
            imagePath: 'assets/images/song.png',
            value: '${songs.length}',
            label: 'Songs',
            color: Colors.blue.shade600,
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          _buildLocalStatItem(
            imagePath: 'assets/images/duration.png',
            value: _formatTotalDuration(totalDuration),
            label: 'Total Duration',
            color: Colors.green.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildLocalStatItem({
    required String imagePath,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Image.asset(imagePath, width: 20, height: 20, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildActionButtons(List<Song> songs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.deepPurple.shade600, Colors.purple.shade600]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _playAll(songs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/play.png', width: 24, height: 24, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text(
                          'Play All',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _shuffleAll(songs),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/shuffle.png', width: 20, height: 20, color: Colors.deepPurple),
                        const SizedBox(height: 2),
                        const Text(
                          'Shuffle',
                          style: TextStyle(color: Colors.deepPurple, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
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

  Widget _buildSongsList(List<Song> songs) {
    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final song = songs[index];
            final isCurrentlyPlaying = audioController.currentSong?.id == song.id;
            final isPlaying = isCurrentlyPlaying && audioController.isPlaying;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isCurrentlyPlaying ? Colors.deepPurple.withValues(alpha: 0.05) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (!isCurrentlyPlaying)
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
                border: Border.all(
                  color: isCurrentlyPlaying ? Colors.deepPurple.withValues(alpha: 0.3) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _playSong(songs, index),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Song Artwork (Using cached iTunes artwork)
                        Stack(
                          children: [
                            // Use HybridSongArtwork to show cached iTunes artwork
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: song.localArtworkPath != null
                                  ? Image.file(
                                      File(song.localArtworkPath!),
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _buildFallbackArt(index, isCurrentlyPlaying, isPlaying),
                                    )
                                  : _buildFallbackArt(index, isCurrentlyPlaying, isPlaying),
                            ),
                            if (isCurrentlyPlaying && isPlaying)
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Icon(Icons.equalizer_rounded, color: Colors.white, size: 20),
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
                                  color: isCurrentlyPlaying ? Colors.deepPurple : Colors.black87,
                                  fontWeight: isCurrentlyPlaying ? FontWeight.w700 : FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.album,
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

                        // Duration and Playing Indicator
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
                                    child: Icon(Icons.volume_up_rounded, color: Colors.deepPurple, size: 18),
                                  );
                                },
                              ),
                            if (isPlaying) const SizedBox(width: 8),
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
                      ],
                    ),
                  ),
                ),
              ),
            );
          }, childCount: songs.length),
        );
      },
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatTotalDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  void _playAll(List<Song> songs) async {
    if (songs.isEmpty) return;

    final audioController = Provider.of<AudioController>(context, listen: false);
    await audioController.playSong(songs.first);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.deepPurple),
              ),
              const SizedBox(width: 12),
              Text('Playing ${songs.length} songs'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.deepPurple,
        ),
      );
    }
  }

  void _shuffleAll(List<Song> songs) async {
    if (songs.isEmpty) return;

    final audioController = Provider.of<AudioController>(context, listen: false);

    // Enable shuffle if not already
    if (!audioController.isShuffleEnabled) {
      await audioController.toggleShuffle();
    }

    // Play first song (shuffle will handle randomization)
    await audioController.playSong(songs.first);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.shuffle_rounded, size: 16, color: Colors.deepPurple),
              ),
              const SizedBox(width: 12),
              Text('Shuffling ${songs.length} songs'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.deepPurple,
        ),
      );
    }
  }

  void _playSong(List<Song> songs, int index) async {
    final audioController = Provider.of<AudioController>(context, listen: false);
    final selectedSong = songs[index];

    // Check if the selected song is already the current one
    if (audioController.currentSong?.id != selectedSong.id) {
      await audioController.playSong(selectedSong);
    }

    // Navigate to player page
    if (mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => PlayerPage(song: selectedSong)));
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildSimilarArtistsList(List<Map<String, String>> artists) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: artists.length,
        itemBuilder: (context, index) {
          final artist = artists[index];
          return GestureDetector(
            onTap: () async {
              // Open Spotify search for the artist
              final query = Uri.encodeComponent(artist['name']!);
              final url = 'https://open.spotify.com/search/$query';
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade200,
                      image: artist['image']!.isNotEmpty
                          ? DecorationImage(image: NetworkImage(artist['image']!), fit: BoxFit.cover)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: artist['image']!.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    artist['name']!,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopAlbumsList(List<Map<String, String>> albums) {
    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 4),
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          return GestureDetector(
            onTap: () async {
              // Open Spotify search for the album
              final query = Uri.encodeComponent(album['name']!);
              final url = 'https://open.spotify.com/search/$query';
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12, bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade200,
                      image: album['image']!.isNotEmpty
                          ? DecorationImage(image: NetworkImage(album['image']!), fit: BoxFit.cover)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: album['image']!.isEmpty ? const Icon(Icons.album, color: Colors.grey, size: 40) : null,
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      album['name']!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFallbackArt(int index, bool isCurrentlyPlaying, bool isPlaying) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCurrentlyPlaying
              ? [Colors.deepPurple.shade100, Colors.deepPurple.shade200]
              : [Colors.grey.shade100, Colors.grey.shade200],
        ),
      ),
      child: Center(
        child: isCurrentlyPlaying && isPlaying
            ? const SizedBox()
            : Text(
                '${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isCurrentlyPlaying ? Colors.deepPurple : Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }

  Widget _buildBiographySection(String biography) {
    // Remove HTML tags and Last.fm footer
    String cleanBio = biography
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'Read more on Last\.fm.*', caseSensitive: false), '')
        .trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(12)),
                child: Image.asset('assets/images/info.png', width: 20, height: 20, color: Colors.deepPurple),
              ),
              const SizedBox(width: 12),
              const Text(
                'About',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            cleanBio,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.6),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerCredits() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade50, Colors.grey.shade100],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: [
          Text(
            'Powered By',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPartnerLogo('Spotify', Icons.music_note, Colors.green.shade600, 'https://spotify.com'),
              _buildPartnerLogo('iTunes', Icons.apple, Colors.black87, 'https://apple.com/itunes'),
              _buildPartnerLogo('Last.fm', Icons.radio, Colors.red.shade600, 'https://last.fm'),
            ],
          ),
          const SizedBox(height: 12),
          Text('Artist info, stats, and artwork', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text(
            'Data provided by partners. Content is property of respective owners.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade400, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerLogo(String name, IconData icon, Color color, String url) {
    // Map names to asset paths
    final Map<String, String> logoAssets = {
      'Spotify': 'assets/images/spotify_logo.png',
      'iTunes': 'assets/images/itunes_logo.png',
      'Last.fm': 'assets/images/lastfm_logo.png',
    };

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(logoAssets[name]!, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
