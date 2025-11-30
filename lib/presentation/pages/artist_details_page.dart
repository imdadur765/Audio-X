import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../data/models/artist_model.dart';
import '../../data/services/artist_service.dart';
import '../controllers/audio_controller.dart';

class ArtistDetailsPage extends StatefulWidget {
  final String artistName;
  final String? heroTag;

  const ArtistDetailsPage({super.key, required this.artistName, this.heroTag});

  @override
  State<ArtistDetailsPage> createState() => _ArtistDetailsPageState();
}

class _ArtistDetailsPageState extends State<ArtistDetailsPage> {
  final ArtistService _artistService = ArtistService();
  late Future<Artist?> _artistFuture;

  @override
  void initState() {
    super.initState();
    // Fetch WITH bio for detail page
    _artistFuture = _artistService.getArtistInfo(widget.artistName, fetchBio: true);
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<AudioController>(context, listen: false);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<Artist?>(
        future: _artistFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmer();
          }

          final artist = snapshot.data;
          if (artist == null) {
            return _buildError();
          }

          // Find songs by this artist - Performance: Do this once
          final artistSongs = controller.songs
              .where((s) => s.artist.toLowerCase().contains(artist.name.toLowerCase()))
              .toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Spotify Style App Bar with Image
              SliverAppBar(
                expandedHeight: 350,
                pinned: true,
                stretch: true,
                backgroundColor: Colors.black,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.blurBackground],
                  title: Text(
                    artist.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(blurRadius: 10, color: Colors.black87),
                        Shadow(blurRadius: 5, color: Colors.black54),
                      ],
                    ),
                  ),
                  background: RepaintBoundary(
                    child: artist.imageUrl != null
                        ? Hero(
                            tag: widget.heroTag ?? 'artist_${artist.name}',
                            child: Image.network(
                              artist.imageUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey[900],
                                child: const Icon(Icons.person, size: 100, color: Colors.grey),
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey[900],
                            child: const Icon(Icons.person, size: 100, color: Colors.grey),
                          ),
                  ),
                ),
              ),

              // Stats Card - Spotify Style
              SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[900]!.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[700]!.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          icon: Icons.people_alt_outlined,
                          label: 'Followers',
                          value: _formatNumber(artist.followers),
                          theme: theme,
                        ),
                        _buildDivider(theme),
                        _buildStatItem(
                          icon: Icons.trending_up_rounded,
                          label: 'Popularity',
                          value: '${artist.popularity}%',
                          theme: theme,
                        ),
                        _buildDivider(theme),
                        _buildStatItem(
                          icon: Icons.music_note_rounded,
                          label: 'Songs',
                          value: artistSongs.length.toString(),
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Play Button - Spotify Style
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ElevatedButton(
                    onPressed: artistSongs.isNotEmpty
                        ? () {
                            if (artistSongs.isNotEmpty) {
                              controller.playSong(artistSongs.first);
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954), // Spotify Green
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      elevation: 4,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'PLAY',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Genres/Tags - Spotify Style
              if (artist.tags.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Genres',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: artist.tags.map((tag) {
                            return Chip(
                              label: Text(
                                tag,
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Colors.grey[800],
                              side: BorderSide.none,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

              // Biography - Spotify Style
              if (artist.biography != null && artist.biography!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'About',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          artist.biography!,
                          style: TextStyle(
                            color: Colors.grey[300],
                            height: 1.6,
                            fontSize: 14,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (artist.biography!.length > 200)
                          GestureDetector(
                            onTap: () {
                              _showFullBiography(context, artist.biography!);
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Read more',
                                style: TextStyle(
                                  color: const Color(0xFF1DB954),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

              // Songs Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Popular (${artistSongs.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Songs List - Spotify Style with Performance
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = artistSongs[index];
                    return _SpotifySongItem(
                      song: song,
                      onTap: () => controller.playSong(song),
                    );
                  },
                  childCount: artistSongs.length,
                ),
              ),

              // Bottom Padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Container(
      height: 50,
      width: 1,
      color: Colors.grey[700],
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[850]!,
      highlightColor: Colors.grey[700]!,
      child: CustomScrollView(
        slivers: [
          const SliverAppBar(expandedHeight: 350, flexibleSpace: SizedBox()),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  // Stats shimmer
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Play button shimmer
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Genres shimmer
                  Container(
                    width: 80,
                    height: 24,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 32,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  // Songs shimmer
                  Container(
                    width: 120,
                    height: 24,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(5, (index) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    height: 60,
                    color: Colors.white,
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'Failed to load artist details',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullBiography(BuildContext context, String biography) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Biography',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  biography,
                  style: TextStyle(
                    color: Colors.grey[300],
                    height: 1.6,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Performance Optimized Song Item Widget
class _SpotifySongItem extends StatelessWidget {
  final dynamic song;
  final VoidCallback onTap;

  const _SpotifySongItem({
    required this.song,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.grey[800],
            ),
            child: song.localArtworkPath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      File(song.localArtworkPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.music_note, color: Colors.grey[400]),
                    ),
                  )
                : Icon(Icons.music_note, color: Colors.grey[400]),
          ),
          title: Text(
            song.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            song.album,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: Icon(Icons.play_circle_fill, color: const Color(0xFF1DB954), size: 32),
            onPressed: onTap,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}