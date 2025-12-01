import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../data/models/song_model.dart';
import '../controllers/audio_controller.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/artist_service.dart';

class ArtistStats {
  final String name;
  final int songCount;
  final String? imageUrl;
  final List<Song> songs;
  final Map<String, dynamic>? cachedData;

  ArtistStats({required this.name, required this.songCount, this.imageUrl, required this.songs, this.cachedData});
}

class HomeController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ArtistService _artistService = ArtistService();

  bool _isLoading = true;
  List<Song> _recentlyPlayed = [];
  List<Song> _mostPlayed = [];
  List<Song> _recentlyAdded = [];
  List<Song> _allSongs = [];
  Map<String, ArtistStats> _topArtists = {};
  Map<String, List<Song>> _genreSongs = {};

  bool get isLoading => _isLoading;
  List<Song> get recentlyPlayed => _recentlyPlayed;
  List<Song> get mostPlayed => _mostPlayed;
  List<Song> get recentlyAdded => _recentlyAdded;
  List<Song> get allSongs => _allSongs;
  Map<String, ArtistStats> get topArtists => _topArtists;
  Map<String, List<Song>> get genreSongs => _genreSongs;

  String get userName => _authService.userName;

  Future<void> loadHomeData(AudioController audioController) async {
    _isLoading = true;
    notifyListeners();

    // 0. Ensure Artist Cache is ready
    await _artistService.openBox();

    // 1. Get all songs
    _allSongs = List.from(audioController.songs);

    // 2. Process Recently Played (from Hive/Settings)
    // For now, we'll just mock it or use a simple list if we had one.
    // Since AudioController has a simple session restore, we can try to infer or just show random for now if no history.
    // Ideally, AudioController or a HistoryService would track this.
    // Let's implement a basic tracker in AudioController later, but for now, we'll just take a subset or shuffle.
    // actually, let's use a real Hive box for history if we can, or just use the "last played" one.
    // For this MVP, let's just show the first few songs as "Recently Played" if we don't have real history,
    // OR we can implement a real history tracker.
    // Let's use a separate Hive box for 'history' in trackRecentlyPlayed.
    await _loadRecentlyPlayed();

    // 3. Process Top Artists
    _processTopArtists();

    // 4. Process Genres (Mock/Simple grouping)
    _processGenres();

    // 5. Recently Added (Reverse order of ID or file date if available, here just reverse list)
    _recentlyAdded = List.from(_allSongs.reversed.take(15)); // Reduced from 20 to 15

    // 6. Most Played (Mock/Random for now until we track play counts)
    _mostPlayed = List.from(_allSongs)..shuffle();
    _mostPlayed = _mostPlayed.take(15).toList(); // Reduced from 20 to 15

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadRecentlyPlayed() async {
    final box = await Hive.openBox<String>('recently_played_ids');
    final ids = box.values.toList().reversed.take(15); // Reduced from 20 to 15

    _recentlyPlayed = [];
    for (var id in ids) {
      try {
        final song = _allSongs.firstWhere((s) => s.id == id);
        // Avoid duplicates in display if needed, but simple list is fine
        if (!_recentlyPlayed.contains(song)) {
          _recentlyPlayed.add(song);
        }
      } catch (e) {
        // Song might have been deleted
      }
    }

    // Fallback: If no history exists, show some recent songs from the library
    if (_recentlyPlayed.isEmpty && _allSongs.isNotEmpty) {
      _recentlyPlayed = _allSongs.take(8).toList(); // Reduced from 10 to 8
    }
  }

  Future<void> trackRecentlyPlayed(String songId) async {
    final box = await Hive.openBox<String>('recently_played_ids');
    // Remove if exists to move to end (most recent)
    final keysToDelete = box.toMap().entries.where((e) => e.value == songId).map((e) => e.key).toList();

    for (var key in keysToDelete) {
      await box.delete(key);
    }

    await box.add(songId);
    await _loadRecentlyPlayed();
    notifyListeners();
  }

  void _processTopArtists() {
    final Map<String, List<Song>> artistMap = {};

    for (var song in _allSongs) {
      if (!artistMap.containsKey(song.artist)) {
        artistMap[song.artist] = [];
      }
      artistMap[song.artist]!.add(song);
    }

    // Sort by song count
    final sortedKeys = artistMap.keys.toList()..sort((a, b) => artistMap[b]!.length.compareTo(artistMap[a]!.length));

    _topArtists = {};
    for (var artist in sortedKeys) {
      // Try to find an artwork from one of the songs
      String? imageUrl;

      // 1. Check cached artist image first (High Quality)
      final cachedArtist = _artistService.getCachedArtist(artist);
      if (cachedArtist?.imageUrl != null) {
        imageUrl = cachedArtist!.imageUrl;
      }

      // 2. Fallback to song artwork if no cached artist image
      if (imageUrl == null) {
        for (var song in artistMap[artist]!) {
          if (song.artworkUri != null) {
            imageUrl = song.artworkUri;
            break;
          }
        }
      }

      _topArtists[artist] = ArtistStats(
        name: artist,
        songCount: artistMap[artist]!.length,
        songs: artistMap[artist]!,
        imageUrl: imageUrl,
      );
    }
  }

  void _processGenres() {
    // Since our Song model doesn't have genre, we'll mock this or group by something else?
    // Or we can just create some "Moods" based on random subsets for the UI demo.
    // Let's create "Pop", "Rock", "Jazz" buckets randomly for now to satisfy the UI requirement
    // until we parse metadata properly.

    _genreSongs = {
      'Pop Hits': _allSongs.take(10).toList(),
      'Rock Classics': _allSongs.skip(10).take(10).toList(),
      'Chill Vibes': _allSongs.skip(20).take(10).toList(),
    };

    // Remove empty genres
    _genreSongs.removeWhere((key, value) => value.isEmpty);
  }

  Future<void> updateUserName(String name) async {
    await _authService.updateUserName(name);
    notifyListeners();
  }
}
