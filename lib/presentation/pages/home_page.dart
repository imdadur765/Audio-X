import 'dart:io';
import 'package:audio_x/data/models/song_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../controllers/audio_controller.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final controller = Provider.of<AudioController>(context, listen: false);
      if (controller.songs.isEmpty) {
        controller.loadSongs();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Audio X'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () {},
          ),
        ],
      ),
      body: Consumer<AudioController>(
        builder: (context, controller, child) {
          if (controller.songs.isEmpty) {
            return _buildEmptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: controller.songs.length,
            itemBuilder: (context, index) {
              final song = controller.songs[index];
              return _buildSongCard(song, context, controller);
            },
          );
        },
      ),
      floatingActionButton: Consumer<AudioController>(
        builder: (context, controller, child) {
          return FloatingActionButton(
            onPressed: () {
              if (controller.isPlaying) {
                controller.pause();
              } else {
                controller.resume();
              }
            },
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            elevation: 4,
            child: Icon(controller.isPlaying ? Icons.pause : Icons.play_arrow),
          );
        },
      ),
    );
  }

  Widget _buildSongCard(Song song, BuildContext context, AudioController controller) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
          child: song.localArtworkPath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(song.localArtworkPath!), width: 56, height: 56, fit: BoxFit.cover),
                )
              : Icon(Icons.music_note, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 24),
        ),
        title: Text(
          song.title,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song.artist,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.primary),
            onPressed: () {
              controller.playSong(song);
              context.pushNamed('player', extra: song);
            },
          ),
        ),
        onTap: () {
          controller.playSong(song);
          context.pushNamed('player', extra: song);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_music_outlined, size: 80, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
            const SizedBox(height: 24),
            Text(
              'No Music Found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'We need permission to access your audio files',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                final controller = Provider.of<AudioController>(context, listen: false);
                await controller.loadSongs();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Grant Permission & Reload'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Audio X only accesses music files\nstored on your device',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}
