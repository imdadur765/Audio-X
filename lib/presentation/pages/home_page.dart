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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<AudioController>(
        builder: (context, controller, child) {
          if (controller.songs.isEmpty) {
            return _buildEmptyState();
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Spotify-Style Header
              SliverAppBar(
                expandedHeight: 160,
                floating: false,
                pinned: true,
                backgroundColor: Colors.black,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1DB954).withOpacity(0.7),
                          Colors.deepPurple.withOpacity(0.5),
                          Colors.black,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _getGreeting(),
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${controller.songs.length} songs',
                          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),

              // Songs List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final song = controller.songs[index];
                    return _SpotifySongTile(
                      song: song,
                      onTap: () {
                        controller.playSong(song);
                        context.pushNamed('player', extra: song);
                      },
                    );
                  }, childCount: controller.songs.length),
                ),
              ),

              // Bottom Spacing
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.deepPurple.withOpacity(0.3), Colors.black],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.library_music_outlined, size: 100, color: const Color(0xFF1DB954).withOpacity(0.6)),
              const SizedBox(height: 32),
              const Text(
                'No Music Found',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'We need permission to access your audio files',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[400]),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () async {
                  final controller = Provider.of<AudioController>(context, listen: false);
                  await controller.loadSongs();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Grant Permission & Reload'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  backgroundColor: const Color(0xFF1DB954),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  elevation: 8,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Audio X only accesses music files\nstored on your device',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Performance Optimized Song Tile
class _SpotifySongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _SpotifySongTile({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(color: Colors.grey[900]!.withOpacity(0.4), borderRadius: BorderRadius.circular(8)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[800],
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: song.localArtworkPath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(song.localArtworkPath!),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.music_note_rounded, color: Colors.grey[400], size: 28),
                    ),
                  )
                : Icon(Icons.music_note_rounded, color: Colors.grey[400], size: 28),
          ),
          title: Text(
            song.title,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            song.artist,
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: const Color(0xFF1DB954).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
