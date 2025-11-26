import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/song_model.dart';
import '../controllers/audio_controller.dart';
import 'player_page.dart';

class PlaylistDetailsPage extends StatelessWidget {
  final String title;
  final List<Song> songs;
  final List<Color> gradientColors;

  const PlaylistDetailsPage({super.key, required this.title, required this.songs, required this.gradientColors});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(slivers: [_buildAppBar(context), _buildSongList(context)]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (songs.isNotEmpty) {
            final audioController = Provider.of<AudioController>(context, listen: false);
            audioController.playSong(songs.first);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerPage(song: songs.first)));
          }
        },
        backgroundColor: gradientColors.last,
        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
        label: const Text(
          'Play All',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradientColors),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                bottom: -50,
                child: Icon(Icons.music_note_rounded, size: 200, color: Colors.white.withOpacity(0.1)),
              ),
              Positioned(
                left: 20,
                bottom: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${songs.length} Songs', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongList(BuildContext context) {
    if (songs.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_off_rounded, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text('No songs yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final song = songs[index];
            final isPlaying = audioController.currentSong?.id == song.id;

            return Container(
              color: isPlaying ? gradientColors.first.withOpacity(0.1) : null,
              child: ListTile(
                leading: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.withOpacity(0.1),
                        image: song.localArtworkPath != null
                            ? DecorationImage(image: FileImage(File(song.localArtworkPath!)), fit: BoxFit.cover)
                            : null,
                      ),
                      child: song.localArtworkPath == null ? Icon(Icons.music_note, color: Colors.grey[400]) : null,
                    ),
                    if (isPlaying)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.graphic_eq, color: Colors.white),
                      ),
                  ],
                ),
                title: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                    color: isPlaying ? gradientColors.first : null,
                  ),
                ),
                subtitle: Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                trailing: isPlaying
                    ? Icon(Icons.volume_up_rounded, color: gradientColors.first, size: 20)
                    : IconButton(
                        icon: const Icon(Icons.more_vert_rounded),
                        onPressed: () {
                          // Show options
                        },
                      ),
                onTap: () {
                  audioController.playSong(song);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerPage(song: song)));
                },
              ),
            );
          }, childCount: songs.length),
        );
      },
    );
  }
}
