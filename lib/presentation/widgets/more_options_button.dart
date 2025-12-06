import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/song_model.dart';
import 'hybrid_song_artwork.dart';
import 'add_to_playlist_sheet.dart';

class MoreOptionsButton extends StatelessWidget {
  final Song song;
  final Widget? trailing; // Optional existing trailing widget (e.g. Favorite button to include in row)

  const MoreOptionsButton({super.key, required this.song, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trailing != null) ...[trailing!, const SizedBox(width: 4)],
        IconButton(
          icon: Image.asset('assets/images/more.png', width: 24, height: 24, color: Colors.grey),
          onPressed: () => _showOptionsSheet(context),
        ),
      ],
    );
  }

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Image.asset('assets/images/song.png', width: 24, height: 24, color: Colors.deepPurple),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          song.artist,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Options
            ListTile(
              leading: Image.asset('assets/images/playlist_open.png', width: 24, height: 24, color: Colors.black87),
              title: const Text('Add to Playlist'),
              onTap: () {
                Navigator.pop(context); // Close this sheet
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => AddToPlaylistSheet(songs: [song]),
                );
              },
            ),
            ListTile(
              leading: Image.asset('assets/images/info.png', width: 24, height: 24, color: Colors.black87),
              title: const Text('Album Info'),
              onTap: () {
                Navigator.pop(context); // Close sheet
                context.pushNamed(
                  'album_info',
                  extra: {
                    'albumName': song.album,
                    'artistName': song.artist,
                    'albumArt': HybridSongArtwork(localArtworkPath: song.localArtworkPath, size: 200, borderRadius: 20),
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
