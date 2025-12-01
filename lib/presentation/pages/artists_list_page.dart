import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/artist_model.dart';
import '../../data/services/artist_service.dart';
import '../controllers/audio_controller.dart';
import 'artist_details_page.dart';

class ArtistsListPage extends StatefulWidget {
  const ArtistsListPage({super.key});

  @override
  State<ArtistsListPage> createState() => _ArtistsListPageState();
}

class _ArtistsListPageState extends State<ArtistsListPage> {
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

                    final hasImage = image != null && image.isNotEmpty;

                    return RepaintBoundary(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          foregroundImage: hasImage ? NetworkImage(image) : null,
                          onForegroundImageError: hasImage
                              ? (exception, stackTrace) {
                                  // Image load error
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ArtistDetailsPage(artistName: artistName, heroTag: 'artist_list_$artistName'),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _artistFutures.clear();
    super.dispose();
  }
}
