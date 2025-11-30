import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/artist_model.dart';
import '../../data/services/artist_service.dart';
import '../controllers/audio_controller.dart';
import 'artist_details_page.dart';

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Artists',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: artists.isEmpty
          ? const Center(
              child: Text(
                "No artists found",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
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

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ArtistDetailsPage(
                              artistName: artistName,
                              heroTag: 'artist_grid_$artistName',
                            ),
                          ),
                        );
                      },
                      child: RepaintBoundary(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Artist Image
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.grey[800],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: hasImage
                                        ? Image.network(
                                            image,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Center(
                                                child: CircularProgressIndicator(
                                                  value: loadingProgress.expectedTotalBytes != null
                                                      ? loadingProgress.cumulativeBytesLoaded /
                                                          loadingProgress.expectedTotalBytes!
                                                      : null,
                                                ),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                              return _buildPlaceholderIcon();
                                            },
                                          )
                                        : _buildPlaceholderIcon(),
                                  ),
                                ),
                              ),
                              // Artist Info
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      artistName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      artist?.tags.isNotEmpty == true
                                          ? artist!.tags.take(2).join(", ")
                                          : isLoading ? "Loading..." : "Artist",
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
              },
            ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Center(
      child: Icon(
        Icons.person,
        size: 50,
        color: Colors.grey[600],
      ),
    );
  }

  @override
  void dispose() {
    _artistFutures.clear();
    super.dispose();
  }
}