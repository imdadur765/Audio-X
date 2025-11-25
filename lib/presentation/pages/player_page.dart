import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/song_model.dart';
import '../controllers/audio_controller.dart';
import 'equalizer_page.dart';

class PlayerPage extends StatelessWidget {
  final Song song;

  const PlayerPage({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => Navigator.of(context).pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.equalizer),
            tooltip: 'Equalizer',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const EqualizerPage()));
            },
          ),
        ],
      ),
      body: Consumer<AudioController>(
        builder: (context, controller, child) {
          // Find current song in controller to get latest state (like artwork)
          final currentSong = controller.songs.firstWhere((s) => s.id == song.id, orElse: () => song);

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Artwork
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.grey[200],
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: currentSong.localArtworkPath != null
                        ? Image.file(File(currentSong.localArtworkPath!), fit: BoxFit.cover)
                        : const Icon(Icons.music_note, size: 100, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 40),

                // Title & Artist
                Text(
                  currentSong.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  currentSong.artist,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 40),

                // Progress Bar
                Column(
                  children: [
                    Slider(
                      value: controller.position.inSeconds.toDouble().clamp(
                        0.0,
                        controller.duration.inSeconds.toDouble(),
                      ),
                      max: controller.duration.inSeconds.toDouble() > 0
                          ? controller.duration.inSeconds.toDouble()
                          : 1.0,
                      onChanged: (value) {
                        controller.seek(Duration(seconds: value.toInt()));
                      },
                      activeColor: Theme.of(context).primaryColor,
                      inactiveColor: Colors.grey[300],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(controller.position)),
                          Text(_formatDuration(controller.duration)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.shuffle,
                        color: controller.isShuffleEnabled ? Theme.of(context).primaryColor : Colors.grey,
                      ),
                      onPressed: controller.toggleShuffle,
                    ),
                    IconButton(icon: const Icon(Icons.skip_previous, size: 40), onPressed: controller.previous),
                    Container(
                      decoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
                      child: IconButton(
                        icon: Icon(
                          controller.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 40,
                        ),
                        onPressed: () {
                          if (controller.isPlaying) {
                            controller.pause();
                          } else {
                            controller.resume();
                          }
                        },
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.skip_next, size: 40), onPressed: controller.next),
                    IconButton(
                      icon: Icon(
                        controller.repeatMode == 1 ? Icons.repeat_one : Icons.repeat,
                        color: controller.repeatMode > 0 ? Theme.of(context).primaryColor : Colors.grey,
                      ),
                      onPressed: controller.toggleRepeat,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
