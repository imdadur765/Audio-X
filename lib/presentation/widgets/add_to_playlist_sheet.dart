import 'dart:ui';
import 'package:flutter/material.dart';
import '../../data/models/playlist_model.dart';
import '../../services/playlist_service.dart';
import '../../data/models/song_model.dart';

class AddToPlaylistSheet extends StatefulWidget {
  final List<Song> songs;

  const AddToPlaylistSheet({super.key, required this.songs});

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
            backgroundColor: Colors.black.withValues(alpha: 0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            title: const Text(
              'New Playlist',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Playlist Name',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Choose Icon',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 250,
                  width: double.maxFinite,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1,
                    ),
                    itemCount: icons.length,
                    itemBuilder: (context, index) {
                      final iconName = icons[index];
                      final isSelected = selectedIcon == iconName;
                      return GestureDetector(
                        onTap: () => setState(() => selectedIcon = iconName),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.deepPurple.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: isSelected
                                ? Border.all(color: Colors.deepPurple, width: 2)
                                : Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Image.asset(
                            'assets/images/$iconName',
                            color: isSelected ? Colors.deepPurple.shade200 : Colors.white70,
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
                child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
                    final newPlaylist = await _playlistService.createPlaylist(
                      nameController.text,
                      iconEmoji: selectedIcon,
                    );

                    // Add songs to the new playlist
                    for (var song in widget.songs) {
                      await _playlistService.addSongToPlaylist(newPlaylist.id, song.id);
                    }

                    if (mounted) {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Close sheet
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added ${widget.songs.length} song(s) to "${newPlaylist.name}"'),
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
    for (var song in widget.songs) {
      await _playlistService.addSongToPlaylist(playlist.id, song.id);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${widget.songs.length} song(s) to ${playlist.name}'),
          backgroundColor: Colors.deepPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
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
                    const Text(
                      'Add to Playlist',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: () => _showCreatePlaylistDialog(context),
                      icon: Image.asset(
                        'assets/images/create.png',
                        width: 28,
                        height: 28,
                        color: Colors.deepPurple.shade200,
                      ),
                      tooltip: 'Create New',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: Colors.deepPurple),
                  ),
                )
              else if (_playlists.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Image.asset('assets/images/playlist_open.png', width: 48, height: 48, color: Colors.white24),
                        const SizedBox(height: 16),
                        Text('No playlists yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                        TextButton(
                          onPressed: () => _showCreatePlaylistDialog(context),
                          child: const Text('Create one'),
                        ),
                        const SizedBox(height: 120), // Add padding for empty state too
                      ],
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 120), // Bottom padding for MiniPlayer
                    itemCount: _playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = _playlists[index];
                      // For multiple songs, "alreadyIn" is complex. We'll show "Add" generally.

                      final allIn = widget.songs.every((s) => playlist.songIds.contains(s.id));

                      return ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: playlist.iconEmoji.endsWith('.png')
                                ? Image.asset(
                                    'assets/images/${playlist.iconEmoji}',
                                    width: 24,
                                    height: 24,
                                    color: Colors.deepPurple.shade200,
                                  )
                                : Text(playlist.iconEmoji, style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                        title: Text(
                          playlist.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        subtitle: Text(
                          '${playlist.songIds.length} songs',
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                        ),
                        trailing: allIn
                            ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                            : Image.asset('assets/images/create.png', width: 24, height: 24, color: Colors.white70),
                        onTap: allIn ? null : () => _addToPlaylist(playlist),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
