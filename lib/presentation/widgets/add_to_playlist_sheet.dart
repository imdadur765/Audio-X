import 'package:flutter/material.dart';
import '../../data/models/playlist_model.dart';
import '../../services/playlist_service.dart';
import '../../data/models/song_model.dart';

class AddToPlaylistSheet extends StatefulWidget {
  final Song song;

  const AddToPlaylistSheet({super.key, required this.song});

  @override
  State<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<AddToPlaylistSheet> {
  final PlaylistService _playlistService = PlaylistService();
  List<Playlist> _playlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final playlists = await _playlistService.getCustomPlaylists();
    if (mounted) {
      setState(() {
        _playlists = playlists;
        _isLoading = false;
      });
    }
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final nameController = TextEditingController();
    String selectedIcon = 'playlist_open.png'; // Default asset

    final icons = [
      'playlist_open.png',
      'favorite.png',
      'most_played.png',
      'recently_played.png',
      'recently_added.png',
      'song.png',
      'album.png',
      'popularity.png',
      'followers.png',
      'share.png',
      'info.png',
      'lyrics.png',
      'equalizer.png',
      'upload_lrc.png',
      'search.png',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text(
              'New Playlist',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Playlist Name',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Choose Icon',
                  style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  width: double.maxFinite,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: icons.length,
                    itemBuilder: (context, index) {
                      final iconName = icons[index];
                      final isSelected = selectedIcon == iconName;
                      return GestureDetector(
                        onTap: () => setState(() => selectedIcon = iconName),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.deepPurple.withOpacity(0.1) : Colors.grey.shade500,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected ? Border.all(color: Colors.deepPurple, width: 2) : null,
                          ),
                          child: Image.asset(
                            'assets/images/$iconName',
                            color: isSelected ? Colors.deepPurple : Colors.grey.shade600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
                    final newPlaylist = await _playlistService.createPlaylist(
                      nameController.text,
                      iconEmoji: selectedIcon,
                    );

                    // Add song to the new playlist immediately
                    await _playlistService.addSongToPlaylist(newPlaylist.id, widget.song.id);

                    if (mounted) {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Close sheet
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added to "${newPlaylist.name}"'),
                          backgroundColor: Colors.deepPurple,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addToPlaylist(Playlist playlist) async {
    await _playlistService.addSongToPlaylist(playlist.id, widget.song.id);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added to ${playlist.name}'),
          backgroundColor: Colors.deepPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Add to Playlist', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => _showCreatePlaylistDialog(context),
                  icon: Image.asset('assets/images/create.png', width: 28, height: 28, color: Colors.deepPurple),
                  tooltip: 'Create New',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
            )
          else if (_playlists.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Image.asset('assets/images/playlist_open.png', width: 48, height: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('No playlists yet', style: TextStyle(color: Colors.grey.shade600)),
                    TextButton(onPressed: () => _showCreatePlaylistDialog(context), child: const Text('Create one')),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _playlists.length,
                itemBuilder: (context, index) {
                  final playlist = _playlists[index];
                  final bool alreadyIn = playlist.songIds.contains(widget.song.id);

                  return ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: playlist.iconEmoji.endsWith('.png')
                            ? Image.asset(
                                'assets/images/${playlist.iconEmoji}',
                                width: 24,
                                height: 24,
                                color: Colors.deepPurple,
                              )
                            : Text(playlist.iconEmoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                    title: Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${playlist.songIds.length} songs', style: const TextStyle(fontSize: 12)),
                    trailing: alreadyIn
                        ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                        : Image.asset('assets/images/create.png', width: 24, height: 24, color: Colors.grey),
                    onTap: alreadyIn ? null : () => _addToPlaylist(playlist),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
