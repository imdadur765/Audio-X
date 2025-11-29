// ignore_for_file: prefer_const_constructors

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:audio_x/data/models/artist_model.dart' as artist_model;
import 'package:audio_x/data/models/local_song_model.dart' as local_song_model;
import 'package:audio_x/data/services/spotify_api_service.dart';
import 'package:audio_x/data/services/local_songs_service.dart';

class CombinedArtistService {
  final LocalSongsService _localSongsService = LocalSongsService();
  final SpotifyApiService _spotifyService = SpotifyApiService();
  final Connectivity _connectivity = Connectivity();

  // Enhanced cache with timestamps
  final Map<String, artist_model.Artist> _artistCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(hours: 24);

  bool _isOnline = true;
  bool _isInitialized = false;

  // Initialize with preloading
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    _checkConnectivity();
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);

    // Preload local songs in background
    Future.microtask(() => _localSongsService.preloadData());
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = result != ConnectivityResult.none;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Connectivity check failed: $e');
      }
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    _isOnline = result != ConnectivityResult.none;
  }

  Future<List<artist_model.Artist>> getCombinedArtists() async {
    try {
      final stopwatch = Stopwatch()..start();

      // Step 1: Get artists with song counts (FAST - uses cache)
      final artistCounts = await _localSongsService.getArtistsWithSongCounts();
      final artistNames = artistCounts.keys.toList();

      if (artistNames.isEmpty) return [];

      // Step 2: Get all local songs in one batch (FAST - uses cache)
      final allLocalSongs = await _localSongsService.getAllSongs();

      // Step 3: Group songs by artist (VERY FAST - in memory)
      final songsByArtist = _groupSongsByArtist(allLocalSongs, artistNames);

      // Step 4: Parallel processing for Spotify data
      final combinedArtists = await _processArtistsInParallel(artistNames, songsByArtist, artistCounts);

      // Sort by number of local songs (descending)
      combinedArtists.sort((a, b) => b.localSongsCount.compareTo(a.localSongsCount));

      stopwatch.stop();
      if (kDebugMode) {
        print('⏱️ Combined artists loaded in ${stopwatch.elapsedMilliseconds}ms');
      }

      return combinedArtists;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Combined service error: $e');
      }
      return _getDemoArtists();
    }
  }

  // FAST: Group songs by artist in memory
  Map<String, List<local_song_model.LocalSong>> _groupSongsByArtist(
    List<local_song_model.LocalSong> allSongs,
    List<String> artistNames,
  ) {
    final Map<String, List<local_song_model.LocalSong>> result = {};

    // Initialize with empty lists
    for (final artist in artistNames) {
      result[artist] = [];
    }

    // Group songs by artist
    for (final song in allSongs) {
      if (result.containsKey(song.artist)) {
        result[song.artist]!.add(song);
      }
    }

    return result;
  }

  // FAST: Process artists in parallel
  Future<List<artist_model.Artist>> _processArtistsInParallel(
    List<String> artistNames,
    Map<String, List<local_song_model.LocalSong>> songsByArtist,
    Map<String, int> artistCounts,
  ) async {
    final List<artist_model.Artist> results = [];

    // Divide artists into batches for parallel processing
    const batchSize = 8; // Reduced for better performance
    final batches = _createBatches(artistNames, batchSize);

    // Process batches in parallel
    final batchFutures = batches.map((batch) => _processArtistBatch(batch, songsByArtist, artistCounts)).toList();

    final batchResults = await Future.wait(batchFutures);

    // Combine all results
    for (final batch in batchResults) {
      results.addAll(batch);
    }

    return results;
  }

  List<List<String>> _createBatches(List<String> items, int batchSize) {
    final batches = <List<String>>[];
    for (var i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      batches.add(items.sublist(i, end));
    }
    return batches;
  }

  Future<List<artist_model.Artist>> _processArtistBatch(
    List<String> artistBatch,
    Map<String, List<local_song_model.LocalSong>> songsByArtist,
    Map<String, int> artistCounts,
  ) async {
    final List<artist_model.Artist> batchResults = [];

    // Get valid cache entries first (VERY FAST)
    final cachedArtists = _getValidCachedArtists(artistBatch);

    // Artists that need Spotify data
    final artistsNeedingData = artistBatch.where((artist) => !cachedArtists.containsKey(artist)).toList();

    // Fetch Spotify data in one batch if online
    Map<String, dynamic> spotifyBatchData = {};
    if (_isOnline && artistsNeedingData.isNotEmpty) {
      spotifyBatchData = await _fetchSpotifyBatchData(artistsNeedingData);
    }

    // Process each artist in the batch
    for (final artistName in artistBatch) {
      try {
        final localSongs = songsByArtist[artistName] ?? [];

        artist_model.Artist artist;

        // Check cache first
        if (cachedArtists.containsKey(artistName)) {
          artist = artist_model.Artist.fromCombinedData(
            spotifyArtist: cachedArtists[artistName]!,
            localSongs: localSongs,
          );
        }
        // Check new Spotify data
        else if (spotifyBatchData.containsKey(artistName)) {
          final spotifyArtist = artist_model.Artist.fromSpotifyJson(spotifyBatchData[artistName]!);
          _cacheArtist(artistName, spotifyArtist);
          artist = artist_model.Artist.fromCombinedData(spotifyArtist: spotifyArtist, localSongs: localSongs);
        }
        // Fallback to local data
        else {
          artist = artist_model.Artist.fromLocalData(name: artistName, localSongs: localSongs);
        }

        batchResults.add(artist);
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error processing $artistName: $e');
        }
        // Fast fallback
        final localSongs = songsByArtist[artistName] ?? [];

        batchResults.add(artist_model.Artist.fromLocalData(name: artistName, localSongs: localSongs));
      }
    }

    return batchResults;
  }

  // FAST: Get valid cached artists
  Map<String, artist_model.Artist> _getValidCachedArtists(List<String> artistNames) {
    final now = DateTime.now();
    final validCache = <String, artist_model.Artist>{};

    for (final artistName in artistNames) {
      if (_artistCache.containsKey(artistName) && _cacheTimestamps.containsKey(artistName)) {
        final cacheAge = now.difference(_cacheTimestamps[artistName]!);
        if (cacheAge <= _cacheDuration) {
          validCache[artistName] = _artistCache[artistName]!;
        }
      }
    }

    return validCache;
  }

  // FAST: Cache artist with timestamp
  void _cacheArtist(String artistName, artist_model.Artist artist) {
    _artistCache[artistName] = artist;
    _cacheTimestamps[artistName] = DateTime.now();
  }

  // OPTIMIZED: Fetch Spotify data in optimized batch
  Future<Map<String, dynamic>> _fetchSpotifyBatchData(List<String> artistNames) async {
    try {
      final batchResults = await _spotifyService.getBatchArtistsData(artistNames);
      final resultMap = <String, dynamic>{};

      for (final data in batchResults) {
        final artistName = data['localName'] as String?;
        final spotifyData = data['spotifyArtist'];
        if (artistName != null && spotifyData != null) {
          resultMap[artistName] = spotifyData;
        }
      }

      return resultMap;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Spotify batch fetch failed: $e');
      }
      return {};
    }
  }

  // FAST: Optimized search
  Future<List<artist_model.Artist>> searchCombinedArtists(String query) async {
    if (query.isEmpty) return [];

    try {
      // Use cached data first for instant results
      final cachedResults = _searchInCache(query);
      if (cachedResults.isNotEmpty) {
        return cachedResults;
      }

      // If no cache, do fast search
      final allArtists = await getCombinedArtists();
      final searchResults = allArtists
          .where((artist) => artist.name.toLowerCase().contains(query.toLowerCase()))
          .toList();

      return searchResults;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Search error: $e');
      }
      return _searchInCache(query);
    }
  }

  // VERY FAST: Search in cache only
  List<artist_model.Artist> _searchInCache(String query) {
    final results = <artist_model.Artist>[];
    final now = DateTime.now();
    final queryLower = query.toLowerCase();

    for (final entry in _artistCache.entries) {
      final cacheAge = _cacheTimestamps[entry.key] != null
          ? now.difference(_cacheTimestamps[entry.key]!)
          : Duration(days: 365);

      if (cacheAge <= _cacheDuration && entry.key.toLowerCase().contains(queryLower)) {
        results.add(entry.value);
      }
    }

    return results;
  }

  bool get isOnline => _isOnline;

  void clearCache() {
    _artistCache.clear();
    _cacheTimestamps.clear();
    _localSongsService.clearCache();
  }

  Future<void> refreshSpotifyData() async {
    if (_isOnline) {
      clearCache();
    }
  }

  List<artist_model.Artist> _getDemoArtists() {
    return [
      artist_model.Artist.fromLocalData(
        name: 'Arijit Singh',
        localSongs: [
          local_song_model.LocalSong(
            id: '1',
            title: 'Tum Hi Ho',
            album: 'Aashiqui 2',
            artist: 'Arijit Singh',
            path: '',
            duration: 262000,
            size: 5242880,
          ),
        ],
      ),
    ];
  }
}
