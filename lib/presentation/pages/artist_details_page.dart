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
    final controller = Provider.of<AudioController>(context);
    final theme = Theme.of(context);

    return Scaffold(
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

          // Find songs by this artist
          final artistSongs = controller.songs
              .where((s) => s.artist.toLowerCase().contains(artist.name.toLowerCase()))
              .toList();

          return CustomScrollView(
            slivers: [
              // App Bar with Image
              SliverAppBar(
                expandedHeight: 350,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    artist.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black54)],
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
                                return const Center(child: CircularProgressIndicator());
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(color: Colors.grey[800], child: const Icon(Icons.person, size: 100)),
                            ),
                          )
                        : Container(color: Colors.grey[800], child: const Icon(Icons.person, size: 100)),
                  ),
                ),
              ),

              // Stats Card
              SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.primaryColor.withOpacity(0.1), theme.primaryColor.withOpacity(0.05)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          icon: Icons.people,
                          label: 'Followers',
                          value: _formatNumber(artist.followers),
                          theme: theme,
                        ),
                        _buildDivider(theme),
                        _buildStatItem(
                          icon: Icons.trending_up,
                          label: 'Popularity',
                          value: '${artist.popularity}%',
                          theme: theme,
                        ),
                        _buildDivider(theme),
                        _buildStatItem(
                          icon: Icons.music_note,
                          label: 'Songs',
                          value: artistSongs.length.toString(),
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Genres/Tags
              if (artist.tags.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Genres', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: artist.tags.map((tag) {
                            return Chip(label: Text(tag), backgroundColor: theme.primaryColor.withOpacity(0.2));
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

              // Biography
              if (artist.biography != null && artist.biography!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Biography', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text(artist.biography!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

              // Songs Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Songs (${artistSongs.length})',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // Songs List
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final song = artistSongs[index];
                  return RepaintBoundary(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: song.localArtworkPath != null ? FileImage(File(song.localArtworkPath!)) : null,
                        child: song.localArtworkPath == null ? const Icon(Icons.music_note) : null,
                      ),
                      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(song.album, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_circle_outline),
                        onPressed: () {
                          controller.playSong(song);
                        },
                      ),
                      onTap: () {
                        controller.playSong(song);
                      },
                    ),
                  );
                }, childCount: artistSongs.length),
              ),

              // Bottom Padding
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
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
        Icon(icon, color: theme.primaryColor, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Container(height: 60, width: 1, color: theme.primaryColor.withOpacity(0.2));
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(expandedHeight: 350, flexibleSpace: Container(color: Colors.white)),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Container(
                    height: 120,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  ),
                  const SizedBox(height: 24),
                  Container(height: 200, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Failed to load artist details'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
        ],
      ),
    );
  }
}
