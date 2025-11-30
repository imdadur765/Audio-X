import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/artist_model.dart';
import '../../data/services/artist_service.dart';
import '../controllers/audio_controller.dart';

class ArtistPage extends StatefulWidget {
  const ArtistPage({super.key});

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  final ArtistService _artistService = ArtistService();
  final Map<String, Future<Artist?>> _artistFutures = {};

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<AudioController>(context);
    final artists = controller.songs.map((s) => s.artist).toSet().toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Artists')),
      body: artists.isEmpty
          ? const Center(child: Text("No artists found"))
          : ListView.builder(
              itemCount: artists.length,
              itemBuilder: (context, index) {
                final artistName = artists[index];

                _artistFutures.putIfAbsent(artistName, () => _artistService.getArtistInfo(artistName));

                return FutureBuilder<Artist?>(
                  future: _artistFutures[artistName],
                  builder: (context, snapshot) {
                    final artist = snapshot.data;
                    final image = artist?.imageUrl;
                    final isLoading = snapshot.connectionState == ConnectionState.waiting;

                    if (artist != null) {
                      print(
                        '🎭 UI: Artist "$artistName" - Image: ${image ?? "NULL"} (${image?.isEmpty == true ? "EMPTY" : "HAS DATA"})',
                      );
                    }

                    final hasImage = image != null && image.isNotEmpty;

                    return RepaintBoundary(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          foregroundImage: hasImage ? NetworkImage(image) : null,
                          onForegroundImageError: hasImage
                              ? (exception, stackTrace) {
                                  print('❌ Image load error for $artistName: $exception');
                                }
                              : null,
                          child: isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : (!hasImage ? const Icon(Icons.person) : null),
                        ),
                        title: Text(artistName),
                        subtitle: artist?.tags.isNotEmpty == true
                            ? Text(artist!.tags.take(3).join(", "), maxLines: 1, overflow: TextOverflow.ellipsis)
                            : Text(isLoading ? "Loading..." : "Unknown Genre"),
                        onTap: () {
                          _showArtistDetails(context, artistName, artist);
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  void _showArtistDetails(BuildContext context, String name, Artist? artist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              if (artist?.imageUrl != null && artist!.imageUrl!.isNotEmpty)
                RepaintBoundary(
                  child: Image.network(
                    artist.imageUrl!,
                    height: 300,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 300,
                        color: Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('❌ Detail image error for $name: $error');
                      return Container(height: 300, color: Colors.grey[300], child: const Icon(Icons.error, size: 60));
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (artist?.tags.isNotEmpty == true)
                      Wrap(spacing: 8, children: artist!.tags.map((tag) => Chip(label: Text(tag))).toList()),
                    const SizedBox(height: 16),
                    const Text("Biography", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(artist?.biography ?? "No biography available.", style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _artistFutures.clear();
    super.dispose();
  }
}
