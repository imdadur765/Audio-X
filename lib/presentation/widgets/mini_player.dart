import 'dart:io';
import 'dart:ui';
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

        // Use primary color if no specific accent color logic here yet

        return GestureDetector(
          onTap: () {
            context.pushNamed('player', extra: {'song': song, 'heroTag': 'mini_player_${song.id}'});
          },
          child: Container(
            height: 72, // Slightly increased height
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      controller.accentColor.withValues(alpha: 0.15),
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.85),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: controller.accentColor.withValues(alpha: 0.2), width: 1),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
                    ],
                  ),
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
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: song.localArtworkPath != null
                                  ? Image.file(File(song.localArtworkPath!), fit: BoxFit.cover)
                                  : Container(
                                      color: Colors.grey[900],
                                      child: Image.asset(
                                        'assets/images/song.png',
                                        width: 24,
                                        height: 24,
                                        color: Colors.grey.shade600,
                                      ),
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Controls using GlassButton
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Skip Previous (Small + Border)
                          GestureDetector(
                            onTap: controller.previous,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/skip_previous.png',
                                  width: 18,
                                  height: 18,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Custom Rounded Play Button
                          GestureDetector(
                            onTap: () {
                              if (controller.isPlaying) {
                                controller.pause();
                              } else {
                                controller.resume();
                              }
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: controller.accentColor, // Filled color
                                shape: BoxShape.circle, // Rounded
                                boxShadow: [
                                  BoxShadow(
                                    color: controller.accentColor.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Image.asset(
                                  controller.isPlaying ? 'assets/images/pause.png' : 'assets/images/play.png',
                                  width: 22,
                                  height: 22,
                                  color: Colors.white, // White icon on colored button
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Skip Next (Small + Border)
                          GestureDetector(
                            onTap: controller.next,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/skip_next.png',
                                  width: 18,
                                  height: 18,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
