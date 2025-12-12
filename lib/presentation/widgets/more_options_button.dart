import 'dart:ui';
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
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))),
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
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: HybridSongArtwork(localArtworkPath: song.localArtworkPath, size: 48, borderRadius: 8),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              song.artist,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 14,
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
                Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                // Options
                ListTile(
                  leading: Image.asset(
                    'assets/images/playlist_open.png',
                    width: 24,
                    height: 24,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  title: Text('Add to Playlist', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
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
                  leading: Image.asset(
                    'assets/images/info.png',
                    width: 24,
                    height: 24,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  title: Text('Album Info', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  onTap: () {
                    Navigator.pop(context); // Close sheet
                    context.pushNamed(
                      'album_info',
                      extra: {
                        'albumName': song.album,
                        'artistName': song.artist,
                        'albumArt': HybridSongArtwork(
                          localArtworkPath: song.localArtworkPath,
                          size: 200,
                          borderRadius: 20,
                        ),
                      },
                    );
                  },
                ),
                const SizedBox(height: 200), // Bottom padding for MiniPlayer
              ],
            ),
          ),
        ),
      ),
    );
  }
}
