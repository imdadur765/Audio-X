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

        // Find current song (mock logic: just take the one being played or first)
        // In real app, controller should expose currentSong
        // For now, let's assume the first one if playing, or find by ID if we had it
        // We need to update controller to expose currentSong.
        // For this step, I'll update controller first.

        // Wait, I can't update controller in this file write.
        // I will assume controller has `currentSong` getter.
        // I will add it in next step.

        final song = controller.currentSong;
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            context.pushNamed('player', extra: song);
          },
          child: Container(
            height: 70,
            color: Theme.of(context).cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Artwork
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: song.localArtworkPath != null
                      ? Image.file(File(song.localArtworkPath!), width: 50, height: 50, fit: BoxFit.cover)
                      : Container(width: 50, height: 50, color: Colors.grey[300], child: const Icon(Icons.music_note)),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                // Controls
                IconButton(
                  icon: Icon(controller.isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: () {
                    if (controller.isPlaying) {
                      controller.pause();
                    } else {
                      controller.resume();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
