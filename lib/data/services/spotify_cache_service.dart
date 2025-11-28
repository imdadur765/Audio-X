import 'dart:async';
import 'package:hive/hive.dart';
import 'package:audio_x/data/models/cached_spotify_artist.dart';
import 'package:audio_x/data/services/spotify_api_service.dart';

class SpotifyCacheService {
  static const String _boxName = 'spotifyCache';
  final SpotifyApiService _apiService = SpotifyApiService();

  // Request queue to prevent API flooding
  final List<_Request> _queue = [];
  bool _isProcessing = false;

  /// Get cached artist data or fetch from API (queued)
  Future<CachedSpotifyArtist?> getOrFetchArtist(String artistName) async {
    try {
      // 1. Try cache first (fast)
      final cached = await getCachedOnly(artistName);
      if (cached != null && !cached.isExpired) {
        return cached;
      }

      // 2. If not in cache, add to queue
      // Check if already in queue to avoid duplicates
      final existingRequest = _queue.firstWhere(
        (r) => r.artistName == artistName,
        orElse: () => _Request('', Completer()),
      );

      if (existingRequest.artistName.isNotEmpty) {
        return existingRequest.completer.future;
      }

      final completer = Completer<CachedSpotifyArtist?>();
      _queue.add(_Request(artistName, completer));
      _processQueue(); // Fire and forget

      return completer.future;
    } catch (e) {
      print('Error in getOrFetchArtist: $e');
      return null;
    }
  }

  /// Process the request queue sequentially with rate limiting
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final request = _queue.removeAt(0);

      try {
        // Double check cache in case it was filled while waiting
        final cached = await getCachedOnly(request.artistName);
        if (cached != null && !cached.isExpired) {
          request.completer.complete(cached);
        } else {
          // Fetch from API
          final result = await _fetchAndCache(request.artistName);
          request.completer.complete(result);

          // Rate limiting delay after API call
          await Future.delayed(const Duration(milliseconds: 800));
        }
      } catch (e) {
        print('Error processing queue item for ${request.artistName}: $e');
        request.completer.complete(null);
      }
    }

    _isProcessing = false;
  }

  Future<CachedSpotifyArtist?> _fetchAndCache(String artistName) async {
    try {
      final spotifyData = await _apiService.getBestMatchingArtist(artistName);

      if (spotifyData == null) {
        return null;
      }

      final cachedArtist = CachedSpotifyArtist.fromSpotifyData(
        artistName: artistName,
        spotifyId: spotifyData.id,
        imageUrl: spotifyData.getMediumImageUrl(),
        followers: spotifyData.followers,
        genres: spotifyData.genres,
        popularity: spotifyData.popularity,
      );

      final box = await Hive.openBox<CachedSpotifyArtist>(_boxName);
      await box.put(artistName.toLowerCase(), cachedArtist);
      return cachedArtist;
    } catch (e) {
      print('Error fetching/caching $artistName: $e');
      return null;
    }
  }

  /// Preload multiple artists (just adds to queue)
  Future<void> preloadArtists(List<String> artistNames) async {
    for (final artistName in artistNames) {
      getOrFetchArtist(artistName).catchError((_) => null);
    }
  }

  /// Get cached data only (no API call)
  Future<CachedSpotifyArtist?> getCachedOnly(String artistName) async {
    try {
      final box = await Hive.openBox<CachedSpotifyArtist>(_boxName);
      return box.get(artistName.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  /// Clear all cache
  Future<void> clearCache() async {
    final box = await Hive.openBox<CachedSpotifyArtist>(_boxName);
    await box.clear();
  }

  /// Clear expired cache only
  Future<void> clearExpiredCache() async {
    final box = await Hive.openBox<CachedSpotifyArtist>(_boxName);
    final expiredKeys = <String>[];

    for (final key in box.keys) {
      final cached = box.get(key);
      if (cached != null && cached.isExpired) {
        expiredKeys.add(key.toString());
      }
    }

    for (final key in expiredKeys) {
      await box.delete(key);
    }
  }
}

class _Request {
  final String artistName;
  final Completer<CachedSpotifyArtist?> completer;
  _Request(this.artistName, this.completer);
}
