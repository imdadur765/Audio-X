import 'package:cached_network_image/cached_network_image.dart';
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

  // In a real app, you'd pass the artist name via constructor or route arguments.
  // For this demo, we'll fetch a default artist or list all artists from the library.
  // Since the user asked for an "Artist Page" (singular context usually implies details),
  // but the tab is "Artists" (plural), we should probably list artists first.
  // However, the requirement was about "fetching metadata".
  // Let's make this page list artists from the library, and when tapped, show details.
  // But for now, to demonstrate the feature, let's just show a list of artists found in the songs.

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
                return FutureBuilder<Artist?>(
                  future: _artistService.getArtistInfo(artistName),
                  builder: (context, snapshot) {
                    final artist = snapshot.data;
                    final image = artist?.imageUrl;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        backgroundImage: image != null && image.isNotEmpty ? CachedNetworkImageProvider(image) : null,
                        child: image == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(artistName),
                      subtitle: artist?.tags.isNotEmpty == true
                          ? Text(artist!.tags.take(3).join(", "), maxLines: 1, overflow: TextOverflow.ellipsis)
                          : const Text("Unknown Genre"),
                      onTap: () {
                        // Navigate to details (could be a bottom sheet or new page)
                        _showArtistDetails(context, artistName, artist);
                      },
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
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.zero,
            children: [
              if (artist?.imageUrl != null)
                CachedNetworkImage(
                  imageUrl: artist!.imageUrl!,
                  height: 300,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(height: 300, color: Colors.grey[300]),
                  errorWidget: (context, url, error) =>
                      Container(height: 300, color: Colors.grey[300], child: const Icon(Icons.error)),
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
}
