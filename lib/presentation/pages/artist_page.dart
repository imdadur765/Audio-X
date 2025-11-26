import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_x/data/models/artist_model.dart';
import 'package:audio_x/data/models/song_model.dart';
import 'package:audio_x/presentation/controllers/artist_controller.dart';

class ArtistPage extends StatefulWidget {
  final String artistName;
  final List<Song> localSongs;

  const ArtistPage({super.key, required this.artistName, required this.localSongs});

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  late ArtistController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ArtistController();
    _loadArtistData();
  }

  Future<void> _loadArtistData() async {
    await _controller.loadArtist(artistName: widget.artistName, localSongs: widget.localSongs);
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
      child: const Icon(Icons.person, size: 120, color: Colors.white54),
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
                  const Icon(Icons.people, size: 20),
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
                  const Icon(Icons.trending_up, size: 20),
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
                const Icon(Icons.music_note, color: Colors.blue),
                const SizedBox(height: 4),
                Text('${artist.songCount}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Text('Songs'),
              ],
            ),
            Column(
              children: [
                const Icon(Icons.access_time, color: Colors.blue),
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
        Icon(Icons.info_outline, size: 14, color: Colors.grey),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.offline_bolt, size: 16, color: Colors.orange),
          SizedBox(width: 8),
          Text('Offline mode - Spotify data unavailable', style: TextStyle(fontSize: 12, color: Colors.orange)),
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
                icon: const Icon(Icons.play_arrow),
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
                icon: const Icon(Icons.shuffle),
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
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final song = artist.localSongs[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.deepPurple.shade100,
            child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(song.album, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(_formatDuration(song.duration), style: TextStyle(color: Colors.grey.shade600)),
          onTap: () => _playSong(artist.localSongs, index),
        );
      }, childCount: artist.localSongs.length),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _playAll(List<Song> songs) {
    // TODO: Integrate with your audio player
    // Example: audioPlayerController.playPlaylist(songs, startIndex: 0);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Playing all songs...')));
  }

  void _shuffleAll(List<Song> songs) {
    // TODO: Integrate with your audio player with shuffle
    // Example: audioPlayerController.playPlaylist(songs, shuffle: true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shuffling songs...')));
  }

  void _playSong(List<Song> songs, int index) {
    // TODO: Integrate with your audio player
    // Example: audioPlayerController.playPlaylist(songs, startIndex: index);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Playing: ${songs[index].title}')));
  }
}
