import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../data/models/artist_model.dart';
import '../../data/services/artist_service.dart';
import '../controllers/audio_controller.dart';

class ArtistsListPage extends StatefulWidget {
  const ArtistsListPage({super.key});

  @override
  State<ArtistsListPage> createState() => _ArtistsListPageState();
}

class _ArtistsListPageState extends State<ArtistsListPage> {
  final ArtistService _artistService = ArtistService();
  final Map<String, Future<Artist?>> _artistFutures = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _artistFutures.clear();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<AudioController>(context);
    final artists = controller.songs.map((s) => s.artist).toSet().toList();
    artists.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(),
          if (artists.isEmpty)
            const SliverFillRemaining(child: Center(child: Text("No artists found")))
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final artistName = artists[index];
                  _artistFutures.putIfAbsent(artistName, () => _artistService.getArtistInfo(artistName));
                  return _buildArtistCard(artistName);
                }, childCount: artists.length),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      floating: false,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: const Text(
          'Artists',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.deepPurple.withValues(alpha: 0.05), Colors.white],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded, color: Colors.black87),
          onPressed: () {
            // TODO: Implement search
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildArtistCard(String artistName) {
    return FutureBuilder<Artist?>(
      future: _artistFutures[artistName],
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final artist = snapshot.data;
        final imageUrl = artist?.imageUrl;

        if (isLoading) {
          return _buildShimmerCard();
        }

        return GestureDetector(
          onTap: () {
            context.pushNamed('artist_details', pathParameters: {'name': artistName}, extra: 'artist_list_$artistName');
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background Image
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    Hero(
                      tag: 'artist_list_$artistName',
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderBackground(),
                      ),
                    )
                  else
                    _buildPlaceholderBackground(),

                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.2),
                          Colors.black.withValues(alpha: 0.8),
                        ],
                        stops: const [0.5, 0.7, 1.0],
                      ),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artistName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            shadows: [Shadow(color: Colors.black45, offset: Offset(0, 1), blurRadius: 2)],
                          ),
                        ),
                        if (artist?.tags.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            artist!.tags.first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildPlaceholderBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple.shade200, Colors.deepPurple.shade400],
        ),
      ),
      child: const Center(child: Icon(Icons.person_rounded, color: Colors.white54, size: 40)),
    );
  }
}
