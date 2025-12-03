import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/audio_controller.dart';
import 'package:go_router/go_router.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioController>(
      builder: (context, controller, child) {
        if (controller.songs.isEmpty) return const SizedBox.shrink();

        final song = controller.currentSong;
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            context.pushNamed('player', extra: {'song': song, 'heroTag': 'mini_player_${song.id}'});
          },
          child: Container(
            height: 68,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.deepPurple.shade50],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.deepPurple.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  // Album Art
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.deepPurple.shade300, Colors.purple.shade400],
                      ),
                    ),
                    child: song.localArtworkPath != null
                        ? Image.file(File(song.localArtworkPath!), fit: BoxFit.cover)
                        : Center(child: Icon(Icons.music_note_rounded, color: Colors.white.withOpacity(0.8), size: 28)),
                  ),
                  const SizedBox(width: 10),

                  // Song Info
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),

                  // Controls
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildControlButton(
                        imagePath: 'assets/images/skip_previous.png',
                        size: 18,
                        onTap: () => controller.previous(),
                      ),
                      const SizedBox(width: 6),
                      _buildPlayPauseButton(
                        isPlaying: controller.isPlaying,
                        onTap: () {
                          if (controller.isPlaying) {
                            controller.pause();
                          } else {
                            controller.resume();
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildControlButton(
                        imagePath: 'assets/images/skip_next.png',
                        size: 18,
                        onTap: () => controller.next(),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton({required String imagePath, required double size, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Center(
          child: Image.asset(imagePath, width: size, height: size, color: Colors.deepPurple),
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton({required bool isPlaying, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepPurple.shade600, Colors.purple.shade600],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: Image.asset(
            isPlaying ? 'assets/images/pause.png' : 'assets/images/play.png',
            width: 20,
            height: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
