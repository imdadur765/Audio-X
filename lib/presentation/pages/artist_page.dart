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

  @override
  void initState() {
    super.initState();
    _controller = ArtistController();

    // Pre-set artist with local data for INSTANT UI
    if (widget.cachedSpotifyData == null) {
      _controller.currentArtist = ArtistModel.localOnly(name: widget.artistName, localSongs: widget.localSongs);
    }

    _loadArtistData();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        body: Consumer<ArtistController>(
          builder: (context, controller, child) {
            final artist = controller.currentArtist;

            if (artist == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return CustomScrollView(
              slivers: [
                _buildAppBar(artist),
                _buildArtistInfo(artist),
                _buildActionButtons(artist),
                _buildSongsList(artist),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(ArtistModel artist) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      actions: [
        // Manual refresh button for Spotify data
        if (!artist.hasSpotifyData)
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Spotify data',
            onPressed: () async {
              if (_controller.isLoading) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 12),
                      Text('Fetching Spotify data...'),
                    ],
                  ),
                  duration: Duration(seconds: 2),
                ),
              );

              await _controller.refreshSpotifyData();

              if (mounted && _controller.hasSpotifyData) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 12),
                        Text('Spotify data updated'),
                      ],
                    ),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          artist.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            shadows: [Shadow(offset: Offset(0, 1), blurRadius: 8, color: Colors.black54)],
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
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
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
          colors: [Colors.deepPurple.shade400, Colors.purple.shade600],
        ),
      ),
      child: const Icon(Icons.person_rounded, size: 120, color: Colors.white54),
    );
  }

  Widget _buildArtistInfo(ArtistModel artist) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Spotify Stats (if available)
            if (artist.hasSpotifyData) ...[_buildSpotifyStats(artist), const SizedBox(height: 16)],

            // Local Stats
            _buildLocalStats(artist),

            // Spotify Attribution
            if (artist.hasSpotifyData) ...[const SizedBox(height: 12), _buildSpotifyAttribution()],

            // Offline Indicator
            if (!artist.hasSpotifyData && artist.spotifyDataFetched) ...[
              const SizedBox(height: 12),
              _buildOfflineIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpotifyStats(ArtistModel artist) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Followers
            if (artist.followers != null)
              Row(
                children: [
                  const Icon(Icons.people_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${artist.spotifyData!.getFormattedFollowers()} followers',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),

            const SizedBox(height: 8),

            // Popularity
            if (artist.popularity != null) ...[
              Row(
                children: [
                  const Icon(Icons.trending_up_rounded, size: 20),
                  const SizedBox(width: 8),
                  const Text('Popularity: ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: artist.popularity! / 100,
                      backgroundColor: Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${artist.popularity}%'),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Genres
            if (artist.genres.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: artist.genres.map((genre) {
                  return Chip(label: Text(genre), visualDensity: VisualDensity.compact);
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocalStats(ArtistModel artist) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Icon(Icons.music_note_rounded, color: Colors.blue),
                const SizedBox(height: 4),
                Text('${artist.songCount}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Text('Songs'),
              ],
            ),
            Column(
              children: [
                const Icon(Icons.schedule_rounded, color: Colors.blue),
                const SizedBox(height: 4),
                Text(
                  artist.getFormattedTotalDuration(),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Text('Duration'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpotifyAttribution() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey),
        SizedBox(width: 4),
        Text(
          'Powered by Spotify',
          style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildOfflineIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off_rounded, size: 18, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(
                'Offline Mode',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Connect to internet and refresh to get Spotify artist data',
            style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ArtistModel artist) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _playAll(artist.localSongs),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play All'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _shuffleAll(artist.localSongs),
                icon: const Icon(Icons.shuffle_rounded),
                label: const Text('Shuffle'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
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

            return ListTile(
              selected: isCurrentlyPlaying,
              selectedTileColor: Colors.deepPurple.withOpacity(0.1),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isCurrentlyPlaying ? Colors.deepPurple : Colors.deepPurple.shade100,
                  image: song.localArtworkPath != null
                      ? DecorationImage(image: FileImage(File(song.localArtworkPath!)), fit: BoxFit.cover)
                      : null,
                ),
                child: song.localArtworkPath == null
                    ? Center(
                        child: isPlaying
                            ? const Icon(Icons.equalizer_rounded, color: Colors.white, size: 24)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCurrentlyPlaying ? Colors.white : Colors.deepPurple,
                                ),
                              ),
                      )
                    : isPlaying
                    ? Container(
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: const Center(child: Icon(Icons.equalizer_rounded, color: Colors.white, size: 24)),
                      )
                    : null,
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isCurrentlyPlaying ? Colors.deepPurple : null,
                  fontWeight: isCurrentlyPlaying ? FontWeight.bold : FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                song.album,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: isCurrentlyPlaying ? Colors.deepPurple.shade700 : Colors.grey.shade600),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPlaying)
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0.8, end: 1.2),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, double value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Icon(Icons.volume_up_rounded, color: Colors.deepPurple, size: 20),
                        );
                      },
                      onEnd: () {
                        // Loop animation
                      },
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(song.duration),
                    style: TextStyle(
                      color: isCurrentlyPlaying ? Colors.deepPurple : Colors.grey.shade600,
                      fontWeight: isCurrentlyPlaying ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
              onTap: () => _playSong(artist.localSongs, index),
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
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text('Playing ${songs.length} songs'),
          ],
        ),
        duration: const Duration(seconds: 2),
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
            const Icon(Icons.shuffle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text('Shuffling ${songs.length} songs'),
          ],
        ),
        duration: const Duration(seconds: 2),
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
