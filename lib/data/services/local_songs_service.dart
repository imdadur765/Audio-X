import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'package:audio_x/data/models/song_model.dart';
import 'package:audio_x/data/models/local_song_model.dart';
import 'package:audio_x/services/audio_handler.dart';

class LocalSongsService {
  Future<void> preloadData() async {
    // In a real app, this might trigger a background scan
    // For now, we rely on Hive being populated by AudioController
  }

  Future<Map<String, int>> getArtistsWithSongCounts() async {
    final songs = await getAllSongs();
    final Map<String, int> counts = {};

    for (var song in songs) {
      counts[song.artist] = (counts[song.artist] ?? 0) + 1;
    }

    return counts;
  }

  Future<List<LocalSong>> getAllSongs() async {
    // Access Hive box directly for speed
    // Assuming 'songs' box is already opened by AudioController
    if (!Hive.isBoxOpen('songs')) {
      await Hive.openBox<Song>('songs');
    }

    final box = Hive.box<Song>('songs');
    final songs = box.values.toList();

    return songs
        .map(
          (s) => LocalSong(
            id: s.id,
            title: s.title,
            artist: s.artist,
            album: s.album,
            path: s.uri, // Using uri as path
            duration: s.duration,
            size: 0, // Size not available in Song model, defaulting to 0
          ),
        )
        .toList();
  }

  Future<Uint8List?> getAlbumArt(String songId, String title, String artist) async {
    try {
      if (!Hive.isBoxOpen('songs')) {
        await Hive.openBox<Song>('songs');
      }
      final box = Hive.box<Song>('songs');
      final song = box.values.firstWhere(
        (s) => s.id == songId,
        orElse: () => Song(id: '', title: '', artist: '', album: '', uri: '', duration: 0, artworkUri: null),
      );

      if (song.artworkUri != null) {
        final uriParts = song.artworkUri!.split('/');
        final albumId = uriParts.last;
        // We need to instantiate AudioHandler here or make it a singleton/mixin
        // Since AudioHandler uses MethodChannel, it's stateless mostly.
        // However, importing it from services/audio_handler.dart
        final audioHandler = AudioHandler();
        return await audioHandler.getAlbumArt(albumId);
      }
    } catch (e) {
      print('Error getting album art: $e');
    }
    return null;
  }

  void clearCache() {
    // No specific cache to clear for now
  }
}
