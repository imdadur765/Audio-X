import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/audio_controller.dart';
import 'package:go_router/go_router.dart';
import 'glass_button.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioController>(
      builder: (context, controller, child) {
        if (controller.songs.isEmpty) return const SizedBox.shrink();

        final song = controller.currentSong;
        if (song == null) return const SizedBox.shrink();

        // Use primary color if no specific accent color logic here yet
        final accentColor = Colors.deepPurple;

        return GestureDetector(
          onTap: () {
            context.pushNamed('player', extra: {'song': song, 'heroTag': 'mini_player_${song.id}'});
          },
          child: Container(
            height: 72, // Slightly increased height
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9), // Glassy background for miniplayer itself
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Row(
                children: [
                  // Album Art
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Hero(
                      tag: 'mini_player_${song.id}',
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: song.localArtworkPath != null
                              ? Image.file(File(song.localArtworkPath!), fit: BoxFit.cover)
                              : Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(Icons.music_note_rounded, color: Colors.grey.shade400),
                                ),
                        ),
                      ),
                    ),
                  ),

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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),

                  // Controls using GlassButton
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GlassButton(
                        imagePath: 'assets/images/skip_previous.png',
                        size: 20,
                        containerSize: 40,
                        onTap: () => controller.previous(),
                      ),
                      const SizedBox(width: 8),
                      GlassButton(
                        imagePath: controller.isPlaying ? 'assets/images/pause.png' : 'assets/images/play.png',
                        size: 22,
                        containerSize: 48,
                        isActive: true, // Highlight play button
                        accentColor: accentColor,
                        onTap: () {
                          if (controller.isPlaying) {
                            controller.pause();
                          } else {
                            controller.resume();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      GlassButton(
                        imagePath: 'assets/images/skip_next.png',
                        size: 20,
                        containerSize: 40,
                        onTap: () => controller.next(),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
