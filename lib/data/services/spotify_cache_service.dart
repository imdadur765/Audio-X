import 'dart:async';
import 'package:hive/hive.dart';
import 'package:audio_x/data/models/cached_spotify_artist.dart';
import 'package:audio_x/data/services/spotify_api_service.dart';

class SpotifyCacheService {
  static const String _boxName = 'spotifyCache';
  final SpotifyApiService _apiService = SpotifyApiService();

  // Keep box open to avoid ANR from repeated I/O
  Box<CachedSpotifyArtist>? _box;

  // Request queue (LIFO for priority to recent requests)
  final List<_Request> _queue = [];
  bool _isProcessing = false;

  // Rate limiting: Track API calls in 30-second window
  final List<DateTime> _apiCallTimestamps = [];
  static const int _maxCallsPer30Seconds = 8; // Conservative limit (Spotify allows ~10-20)
  static const Duration _windowDuration = Duration(seconds: 30);

  DateTime? _retryAfter; // For 429 error handling

  /// Get the Hive box, opening it if necessary
  Future<Box<CachedSpotifyArtist>> _getBox() async {
    if (_box != null && _box!.isOpen) {
      return _box!;
    }
    _box = await Hive.openBox<CachedSpotifyArtist>(_boxName);
    return _box!;
  }

  /// Check if we can make an API call within rate limit
  bool _canMakeApiCall() {
    final now = DateTime.now();

    // Check if we're in a retry-after period
    if (_retryAfter != null && now.isBefore(_retryAfter!)) {
      return false;
    }

    // Remove timestamps older than 30 seconds
    _apiCallTimestamps.removeWhere((timestamp) => now.difference(timestamp) > _windowDuration);

    // Check if we're under the limit
    return _apiCallTimestamps.length < _maxCallsPer30Seconds;
  }

  /// Record an API call timestamp
  void _recordApiCall() {
    _apiCallTimestamps.add(DateTime.now());
  }

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
      // LIFO: Add to end, we'll process from end for priority
      _queue.add(_Request(artistName, completer));
      _processQueue(); // Fire and forget

      return completer.future;
    } catch (e) {
      print('Error in getOrFetchArtist: $e');
      return null;
    }
  }

  /// Process the request queue with smart rate limiting
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      // LIFO: Process from end (most recent = what user is viewing now)
      final request = _queue.removeLast();

      try {
        // Double check cache in case it was filled while waiting
        final cached = await getCachedOnly(request.artistName);
        if (cached != null && !cached.isExpired) {
          request.completer.complete(cached);
          continue; // Skip delay if we used cache
        }

        // Wait if we can't make API call yet (rate limit)
        while (!_canMakeApiCall()) {
          print('Rate limit reached, waiting...');
          await Future.delayed(const Duration(seconds: 2));
        }

        // Fetch from API
        final result = await _fetchAndCache(request.artistName);
        request.completer.complete(result);

        // Record this API call
        _recordApiCall();

        // Delay between calls (conservative)
        await Future.delayed(const Duration(seconds: 4));
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

      final box = await _getBox();
      await box.put(artistName.toLowerCase(), cachedArtist);
      return cachedArtist;
    } catch (e) {
      print('Error fetching/caching $artistName: $e');

      // Check if it's a 429 error (rate limit)
      if (e.toString().contains('429')) {
        // Set retry-after to 60 seconds (conservative)
        _retryAfter = DateTime.now().add(const Duration(seconds: 60));
        print('429 Rate limit error. Waiting 60 seconds before retry.');
      }

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
      final box = await _getBox();
      return box.get(artistName.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  /// Clear all cache
  Future<void> clearCache() async {
    final box = await _getBox();
    await box.clear();
  }

  /// Clear expired cache only
  Future<void> clearExpiredCache() async {
    final box = await _getBox();
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
