import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/song_model.dart';
import '../../services/playlist_service.dart';
import '../controllers/audio_controller.dart';

class PlaylistDetailsPage extends StatefulWidget {
  final String playlistId;
  final String title;
  final List<Song> songs;
  final List<Color> gradientColors;
  final bool isAuto;

  const PlaylistDetailsPage({
    super.key,
    this.playlistId = '',
    required this.title,
    required this.songs,
    required this.gradientColors,
    this.isAuto = false,
  });

  @override
  State<PlaylistDetailsPage> createState() => _PlaylistDetailsPageState();
}

class _PlaylistDetailsPageState extends State<PlaylistDetailsPage> {
  final PlaylistService _playlistService = PlaylistService();
  late List<Song> _songs;

  @override
  void initState() {
    super.initState();
    _songs = widget.songs;
  }

  Future<void> _removeSongFromPlaylist(Song song) async {
    if (widget.isAuto) return; // Can't modify auto playlists

    await _playlistService.removeSongFromPlaylist(widget.playlistId, song.id);

    setState(() {
      _songs.removeWhere((s) => s.id == song.id);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${song.title}"'),
          backgroundColor: Colors.deepPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _deletePlaylist() async {
    if (widget.isAuto) return; // Can't delete auto playlists

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Playlist?'),
        content: Text('Are you sure you want to delete "${widget.title}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _playlistService.deletePlaylist(widget.playlistId);
      if (mounted) {
        Navigator.of(context).pop(); // Go back to playlist page
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioController = Provider.of<AudioController>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Gradient Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [widget.gradientColors.first.withOpacity(0.4), Colors.white],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Playlist Info
                _buildPlaylistInfo(),

                // Control Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _songs.isEmpty
                              ? null
                              : () {
                                  audioController.playSongList(_songs, 0);
                                },
                          icon: const Icon(Icons.play_arrow, color: Colors.white),
                          label: const Text(
                            'Play All',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.gradientColors.first,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _songs.isEmpty
                              ? null
                              : () {
                                  audioController.playSongList(_songs, 0, shuffle: true);
                                },
                          icon: Image.asset(
                            'assets/images/shuffle.png',
                            width: 18,
                            height: 18,
                            color: widget.gradientColors.first,
                          ),
                          label: Text(
                            'Shuffle',
                            style: TextStyle(color: widget.gradientColors.first, fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: widget.gradientColors.first, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Songs List
                Expanded(
                  child: _songs.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: _songs.length,
                          itemBuilder: (context, index) {
                            final song = _songs[index];
                            return _buildSongTile(song, index, audioController);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
              ),
              child: Center(child: Image.asset('assets/images/back.png', width: 20, height: 20, color: Colors.black87)),
            ),
          ),
          if (!widget.isAuto)
            PopupMenuButton<String>(
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                ),
                child: Center(
                  child: Image.asset('assets/images/more.png', width: 20, height: 20, color: Colors.black87),
                ),
              ),
              onSelected: (value) {
                if (value == 'delete') {
                  _deletePlaylist();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Image.asset('assets/images/delete.png', width: 20, height: 20, color: Colors.red),
                      const SizedBox(width: 12),
                      const Text('Delete Playlist', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPlaylistInfo() {
    final totalDuration = _songs.fold(Duration.zero, (sum, song) => sum + Duration(milliseconds: song.duration));
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);
    final durationText = hours > 0 ? '$hours hr $minutes min' : '$minutes min';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text(
            '${_songs.length} songs • $durationText',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSongTile(Song song, int index, AudioController audioController) {
    final isPlaying = audioController.currentSong?.id == song.id && audioController.isPlaying;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isPlaying ? widget.gradientColors.first.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        onTap: () {
          audioController.playSongList(_songs, index);
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: song.localArtworkPath != null
              ? Image.file(File(song.localArtworkPath!), width: 50, height: 50, fit: BoxFit.cover)
              : Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [widget.gradientColors.first, widget.gradientColors.last]),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.white),
                ),
        ),
        title: Text(
          song.title,
          style: TextStyle(
            fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w600,
            color: isPlaying ? widget.gradientColors.first : Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: !widget.isAuto
            ? IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: () => _removeSongFromPlaylist(song),
              )
            : null,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No songs in this playlist', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
