import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../data/models/song_model.dart';
import '../../data/models/cached_spotify_artist.dart';
import 'audio_controller.dart';

class HomeController extends ChangeNotifier {
  List<Song> _recentlyPlayed = [];
  final Map<String, ArtistStats> _topArtists = {};
  List<Song> _mostPlayed = [];
  List<Song> _recentlyAdded = [];
  Map<String, List<Song>> _genreSongs = {};
  bool _isLoading = false;

  List<Song> get recentlyPlayed => _recentlyPlayed;
  Map<String, ArtistStats> get topArtists => _topArtists;
  List<Song> get mostPlayed => _mostPlayed;
  List<Song> get recentlyAdded => _recentlyAdded;
  Map<String, List<Song>> get genreSongs => _genreSongs;
  bool get isLoading => _isLoading;

  Future<void> loadHomeData(AudioController audioController) async {
    _isLoading = true;
    notifyListeners();

    try {
      final songs = audioController.songs;
      if (songs.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Load recently played from Hive
      await _loadRecentlyPlayed();

      // Calculate top artists by song count
      await _calculateTopArtists(songs);

      // Most played songs (by lastPlayedAt and playCount if we track it)
      _mostPlayed = _recentlyPlayed.take(10).toList();

      // Recently added (sort by id/timestamp if available, for now just last 10)
      _recentlyAdded = songs.reversed.take(10).toList();

      // Group by genre (extract from album or use artist as fallback)
      _groupByGenres(songs);
    } catch (e) {
      print('Error loading home data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadRecentlyPlayed() async {
    try {
      final box = Hive.box<Song>('songs');
      final settingsBox = Hive.box('settings');

      // Get recently played song IDs (we'll need to track this)
      final recentIds = settingsBox.get('recentlyPlayedIds', defaultValue: <String>[]) as List;

      _recentlyPlayed = recentIds
          .map((id) => box.values.firstWhere((song) => song.id == id.toString(), orElse: () => box.values.first))
          .take(20)
          .toList();

      // If empty, just use first 20 songs
      if (_recentlyPlayed.isEmpty && box.values.isNotEmpty) {
        _recentlyPlayed = box.values.take(20).toList();
      }
    } catch (e) {
      print('Error loading recently played: $e');
      _recentlyPlayed = [];
    }
  }

  Future<void> _calculateTopArtists(List<Song> songs) async {
    final artistMap = <String, List<Song>>{};

    for (var song in songs) {
      final artist = song.artist;
      if (!artistMap.containsKey(artist)) {
        artistMap[artist] = [];
      }
      artistMap[artist]!.add(song);
    }

    // Sort by song count and take top 10
    final sortedArtists = artistMap.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));

    _topArtists.clear();
    for (var entry in sortedArtists.take(10)) {
      // Try to get cached Spotify data
      CachedSpotifyArtist? cachedData;
      try {
        final cacheBox = await Hive.openBox<CachedSpotifyArtist>('spotifyCache');
        cachedData = cacheBox.values.firstWhere(
          (cached) => cached.artistName.toLowerCase() == entry.key.toLowerCase(),
          orElse: () => CachedSpotifyArtist(artistName: entry.key, genres: const [], cachedAt: DateTime.now()),
        );
      } catch (e) {
        print('Error loading cached Spotify data for ${entry.key}: $e');
      }

      _topArtists[entry.key] = ArtistStats(
        name: entry.key,
        songCount: entry.value.length,
        imageUrl: cachedData?.imageUrl,
        songs: entry.value,
        cachedData: cachedData,
      );
    }
  }

  void _groupByGenres(List<Song> songs) {
    // For now, use artist as genre grouping (can be enhanced later)
    // In real app, you'd extract genre from metadata or use Spotify genres
    final genreMap = <String, List<Song>>{};

    for (var song in songs) {
      // Simple heuristic: use first artist as genre category
      final genre = song.artist;
      if (!genreMap.containsKey(genre)) {
        genreMap[genre] = [];
      }
      genreMap[genre]!.add(song);
    }

    // Only keep genres with 3+ songs
    _genreSongs = Map.fromEntries(genreMap.entries.where((entry) => entry.value.length >= 3).take(5));
  }

  Future<void> trackRecentlyPlayed(String songId) async {
    try {
      final settingsBox = Hive.box('settings');
      final recentIds = List<String>.from(settingsBox.get('recentlyPlayedIds', defaultValue: <String>[]));

      // Remove if already exists
      recentIds.remove(songId);

      // Add to front
      recentIds.insert(0, songId);

      // Keep only last 50
      if (recentIds.length > 50) {
        recentIds.removeRange(50, recentIds.length);
      }

      await settingsBox.put('recentlyPlayedIds', recentIds);
    } catch (e) {
      print('Error tracking recently played: $e');
    }
  }
}

class ArtistStats {
  final String name;
  final int songCount;
  final String? imageUrl;
  final List<Song> songs;
  final CachedSpotifyArtist? cachedData;

  ArtistStats({required this.name, required this.songCount, this.imageUrl, required this.songs, this.cachedData});
}
