import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_x/data/models/cached_spotify_artist.dart';
import 'package:audio_x/data/models/artist_model.dart';
import 'package:audio_x/data/models/song_model.dart';
import 'package:audio_x/data/services/spotify_api_service.dart';
import 'package:audio_x/data/models/spotify_artist_model.dart';

/// Simplified in-memory cache service for artists
/// Uses batch API calls and HashMap cache (no Hive = no disk I/O = no ANR)
class CombinedArtistService {
  final SpotifyApiService _apiService = SpotifyApiService();

  // In-memory cache with 24-hour expiry
  final Map<String, CachedSpotifyArtist> _artistCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(hours: 24);

  bool _isInitialized = false;

  /// Initialize service
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    if (kDebugMode) {
      print('✅ CombinedArtistService initialized');
    }
  }

  /// Get Spotify data for multiple artists in ONE batch call
  Future<Map<String, ArtistModel>> getArtistsWithSpotifyData({
    required Map<String, List<Song>> artistsWithSongs,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      final artistNames = artistsWithSongs.keys.toList();

      if (artistNames.isEmpty) return {};

      // Step 1: Get valid cached entries
      final cachedArtists = _getValidCachedArtists(artistNames);

      // Step 2: Artists that need fresh data
      final artistsNeedingData = artistNames.where((name) => !cachedArtists.containsKey(name)).toList();

      // Step 3: Fetch in ONE batch call
      Map<String, CachedSpotifyArtist> spotifyBatchData = {};
      if (artistsNeedingData.isNotEmpty) {
        spotifyBatchData = await _fetchSpotifyBatchData(artistsNeedingData);
      }

      // Step 4: Build final artist models
      final Map<String, ArtistModel> result = {};
      for (final artistName in artistNames) {
        final localSongs = artistsWithSongs[artistName] ?? [];

        // Use cache or fetch result
        final cachedData = cachedArtists[artistName] ?? spotifyBatchData[artistName];

        if (cachedData != null) {
          // Convert CachedSpotifyArtist to SpotifyArtistModel
          final spotifyModel = SpotifyArtistModel(
            id: cachedData.spotifyId ?? '',
            name: cachedData.artistName,
            imageUrl: cachedData.imageUrl,
            images: [],
            followers: cachedData.followers ?? 0,
            genres: cachedData.genres,
            popularity: cachedData.popularity ?? 0,
          );

          result[artistName] = ArtistModel.withSpotify(
            name: artistName,
            localSongs: localSongs,
            spotifyData: spotifyModel,
          );
        } else {
          // Fallback: local only
          result[artistName] = ArtistModel.localOnly(name: artistName, localSongs: localSongs);
        }
      }

      stopwatch.stop();
      if (kDebugMode) {
        print('⏱️ Artists with Spotify data loaded in ${stopwatch.elapsedMilliseconds}ms');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting artists with Spotify data: $e');
      }
      return {};
    }
  }

  /// Get valid cached artists (24-hour expiry)
  Map<String, CachedSpotifyArtist> _getValidCachedArtists(List<String> artistNames) {
    final now = DateTime.now();
    final validCache = <String, CachedSpotifyArtist>{};

    for (final artistName in artistNames) {
      if (_artistCache.containsKey(artistName) && _cacheTimestamps.containsKey(artistName)) {
        final cacheAge = now.difference(_cacheTimestamps[artistName]!);
        if (cacheAge <= _cacheDuration) {
          validCache[artistName] = _artistCache[artistName]!;
        }
      }
    }

    if (kDebugMode && validCache.isNotEmpty) {
      print('💾 Cache hit: ${validCache.length} artists');
    }

    return validCache;
  }

  /// Cache artist with timestamp
  void _cacheArtist(String artistName, CachedSpotifyArtist artist) {
    _artistCache[artistName] = artist;
    _cacheTimestamps[artistName] = DateTime.now();
  }

  /// Fetch Spotify data in ONE batch call (GAME CHANGER!)
  Future<Map<String, CachedSpotifyArtist>> _fetchSpotifyBatchData(List<String> artistNames) async {
    try {
      if (kDebugMode) {
        print('🚀 Batch API call for ${artistNames.length} artists');
      }

      final batchResults = await _apiService.getBatchArtistsData(artistNames);
      final resultMap = <String, CachedSpotifyArtist>{};

      for (final data in batchResults) {
        final artistName = data['localName'] as String?;
        final spotifyData = data['spotifyArtist'];

        if (artistName != null && spotifyData != null) {
          // Convert to CachedSpotifyArtist
          final cachedArtist = CachedSpotifyArtist.fromSpotifyData(
            artistName: artistName,
            spotifyId: (spotifyData['id'] as String?) ?? '',
            imageUrl: (spotifyData['imageUrl'] as String?) ?? '',
            followers: (spotifyData['followers'] as int?) ?? 0,
            genres: (spotifyData['genres'] as List?)?.cast<String>() ?? [],
            popularity: (spotifyData['popularity'] as int?) ?? 0,
          );

          // Cache it
          _cacheArtist(artistName, cachedArtist);
          resultMap[artistName] = cachedArtist;
        }
      }

      if (kDebugMode) {
        print('✅ Batch fetch complete: ${resultMap.length} artists fetched');
      }

      return resultMap;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Batch fetch failed: $e');
      }
      return {};
    }
  }

  /// Clear all cache
  void clearCache() {
    _artistCache.clear();
    _cacheTimestamps.clear();
    if (kDebugMode) {
      print('🗑️ Cache cleared');
    }
  }

  /// Get cache stats
  Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    int validCount = 0;
    int expiredCount = 0;

    for (final entry in _cacheTimestamps.entries) {
      final age = now.difference(entry.value);
      if (age <= _cacheDuration) {
        validCount++;
      } else {
        expiredCount++;
      }
    }

    return {'total': _artistCache.length, 'valid': validCount, 'expired': expiredCount};
  }
}
