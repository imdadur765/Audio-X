import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_x/data/models/artist_model.dart';
import 'package:audio_x/data/models/song_model.dart';
import 'package:audio_x/data/models/cached_spotify_artist.dart';
import 'package:audio_x/data/models/spotify_artist_model.dart';
import 'package:audio_x/presentation/controllers/artist_controller.dart';
import 'package:audio_x/presentation/controllers/audio_controller.dart';
import 'package:audio_x/presentation/pages/player_page.dart';

class ArtistPage extends StatefulWidget {
  final String artistName;
  final List<Song> localSongs;
  final CachedSpotifyArtist? cachedSpotifyData;

  const ArtistPage({super.key, required this.artistName, required this.localSongs, this.cachedSpotifyData});

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  late ArtistController _controller;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _controller = ArtistController();
    _scrollController.addListener(_onScroll);

    // Pre-set artist with local data for INSTANT UI
    if (widget.cachedSpotifyData == null) {
      _controller.currentArtist = ArtistModel.localOnly(name: widget.artistName, localSongs: widget.localSongs);
    }

    _loadArtistData();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  Future<void> _loadArtistData() async {
    // If we have cached data, create artist model immediately
    if (widget.cachedSpotifyData != null) {
      final spotifyModel = SpotifyArtistModel(
        id: widget.cachedSpotifyData!.spotifyId ?? '',
        name: widget.cachedSpotifyData!.artistName,
        imageUrl: widget.cachedSpotifyData!.imageUrl,
        images: [],
        followers: widget.cachedSpotifyData!.followers ?? 0,
        genres: widget.cachedSpotifyData!.genres,
        popularity: widget.cachedSpotifyData!.popularity ?? 0,
      );

      _controller.currentArtist = ArtistModel.withSpotify(
        name: widget.artistName,
        localSongs: widget.localSongs,
        spotifyData: spotifyModel,
      );
      setState(() {}); // Trigger rebuild with cached data
    } else {
      // Load normally if no cached data
      await _controller.loadArtist(artistName: widget.artistName, localSongs: widget.localSongs);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: Consumer<ArtistController>(
          builder: (context, controller, child) {
            final artist = controller.currentArtist;

            if (artist == null) {
              return _buildLoadingScreen();
            }

            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                _buildAppBar(artist),
                _buildArtistHeader(artist),
                _buildStatsSection(artist),
                _buildActionButtons(artist),
                _buildSongsList(artist),
              ],
            );
          },
        ),
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
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.person_rounded, size: 40, color: Colors.deepPurple),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading Artist...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.deepPurple.shade800,
              ),
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

  Widget _buildAppBar(ArtistModel artist) {
    final opacity = (_scrollOffset / 100).clamp(0.0, 1.0);
    
    return SliverAppBar(
      expandedHeight: 350,
      pinned: true,
      floating: true,
      backgroundColor: Colors.white,
      elevation: opacity * 4,
      shadowColor: Colors.black.withOpacity(0.1),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(opacity),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (opacity > 0.5)
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: opacity > 0.5 ? Colors.black87 : Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      actions: [
        if (!artist.hasSpotifyData)
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(opacity),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (opacity > 0.5)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.refresh_rounded, color: opacity > 0.5 ? Colors.deepPurple : Colors.white),
              tooltip: 'Refresh Spotify data',
              onPressed: () async {
                if (_controller.isLoading) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          padding: const EdgeInsets.all(2),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('Fetching Spotify data...'),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );

                await _controller.refreshSpotifyData();

                if (mounted && _controller.hasSpotifyData) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Text('Spotify data updated'),
                        ],
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 200),
          child: Text(
            artist.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 18,
            ),
          ),
        ),
        background: artist.hasSpotifyData && artist.imageUrl != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    artist.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildPlaceholderImage();
                    },
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                        stops: [0.5, 1.0],
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
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: [0.0, 0.3, 1.0],
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
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
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
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

  Widget _buildArtistHeader(ArtistModel artist) {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              artist.name,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            // Spotify Attribution with better styling
            if (artist.hasSpotifyData) ...[
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
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(ArtistModel artist) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Spotify Stats Card
            if (artist.hasSpotifyData) _buildSpotifyStatsCard(artist),
            
            const SizedBox(height: 16),
            
            // Local Stats Card
            _buildLocalStatsCard(artist),
            
            // Offline Indicator
            if (!artist.hasSpotifyData && artist.spotifyDataFetched) ...[
              const SizedBox(height: 16),
              _buildOfflineIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpotifyStatsCard(ArtistModel artist) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple.shade50, Colors.purple.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_awesome_rounded, size: 20, color: Colors.deepPurple.shade800),
              ),
              const SizedBox(width: 12),
              const Text(
                'Spotify Stats',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Followers
          if (artist.followers != null)
            _buildStatRow(
              icon: Icons.people_alt_rounded,
              value: artist.spotifyData!.getFormattedFollowers(),
              label: 'Followers',
              color: Colors.deepPurple,
            ),
          
          const SizedBox(height: 12),
          
          // Popularity
          if (artist.popularity != null) ...[
            _buildPopularityBar(artist.popularity!),
            const SizedBox(height: 12),
          ],
          
          // Genres
          if (artist.genres.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Genres',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: artist.genres.map((genre) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.deepPurple.shade100),
                  ),
                  child: Text(
                    genre,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.deepPurple.shade800,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow({required IconData icon, required String value, required String label, required Color color}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
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
            Icon(Icons.trending_up_rounded, size: 20, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            Text(
              'Popularity',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const Spacer(),
            Text(
              '$popularity%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              Container(
                height: 8,
                width: (popularity / 100) * MediaQuery.of(context).size.width - 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocalStatsCard(ArtistModel artist) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 248, 247, 247).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLocalStatItem(
            icon: Icons.music_note_rounded,
            value: '${artist.songCount}',
            label: 'Songs',
            color: Colors.blue.shade600,
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.shade200,
          ),
          _buildLocalStatItem(
            icon: Icons.schedule_rounded,
            value: artist.getFormattedTotalDuration(),
            label: 'Total Duration',
            color: Colors.green.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildLocalStatItem({required IconData icon, required String value, required String label, required Color color}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_off_rounded, size: 20, color: Colors.orange.shade800),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline Mode',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade900,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Connect to internet to get Spotify artist data',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ArtistModel artist) {
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
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.shade600, Colors.purple.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _playAll(artist.localSongs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Play All',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
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
                    BoxShadow(
                      color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _shuffleAll(artist.localSongs),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shuffle_rounded, color: Colors.deepPurple, size: 20),
                        const SizedBox(height: 2),
                        Text(
                          'Shuffle',
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
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

  Widget _buildSongsList(ArtistModel artist) {
    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final song = artist.localSongs[index];
            final isCurrentlyPlaying = audioController.currentSong?.id == song.id;
            final isPlaying = isCurrentlyPlaying && audioController.isPlaying;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isCurrentlyPlaying ? Colors.deepPurple.withOpacity(0.05) : Colors.white,
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
                  color: isCurrentlyPlaying ? Colors.deepPurple.withOpacity(0.3) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _playSong(artist.localSongs, index),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Song Number/Artwork
                        Stack(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: isCurrentlyPlaying ? Colors.deepPurple.shade100 : Colors.grey.shade100,
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
                                                color: isCurrentlyPlaying ? Colors.deepPurple : Colors.grey.shade600,
                                                fontSize: 14,
                                              ),
                                            ),
                                    )
                                  : null,
                            ),
                            if (isCurrentlyPlaying && isPlaying)
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
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
          }, childCount: artist.localSongs.length),
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

  void _playAll(List<Song> songs) async {
    if (songs.isEmpty) return;

    final audioController = Provider.of<AudioController>(context, listen: false);
    await audioController.playSong(songs.first);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow_rounded, size: 16, color: Colors.deepPurple),
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

  void _shuffleAll(List<Song> songs) async {
    if (songs.isEmpty) return;

    final audioController = Provider.of<AudioController>(context, listen: false);

    // Enable shuffle if not already
    if (!audioController.isShuffleEnabled) {
      await audioController.toggleShuffle();
    }

    // Play first song (shuffle will handle randomization)
    await audioController.playSong(songs.first);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shuffle_rounded, size: 16, color: Colors.deepPurple),
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

  void _playSong(List<Song> songs, int index) async {
    final audioController = Provider.of<AudioController>(context, listen: false);
    await audioController.playSong(songs[index]);

    // Navigate to player page
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => PlayerPage(song: songs[index])));
  }
}