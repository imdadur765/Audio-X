import 'package:hive/hive.dart';
import 'package:audio_x/data/models/cached_spotify_artist.dart';
import 'package:audio_x/data/services/spotify_api_service.dart';

class SpotifyCacheService {
  static const String _boxName = 'spotifyCache';
  final SpotifyApiService _apiService = SpotifyApiService();

  /// Get cached artist data or fetch from API
  Future<CachedSpotifyArtist?> getOrFetchArtist(String artistName) async {
    try {
      final box = await Hive.openBox<CachedSpotifyArtist>(_boxName);
      final cached = box.get(artistName.toLowerCase());

      // Return cached if valid
      if (cached != null && !cached.isExpired) {
        return cached;
      }

      // Fetch from API
      final spotifyData = await _apiService.getBestMatchingArtist(artistName);

      if (spotifyData == null) {
        return null;
      }

      // Cache the result
      final cachedArtist = CachedSpotifyArtist.fromSpotifyData(
        artistName: artistName,
        spotifyId: spotifyData.id,
        imageUrl: spotifyData.getMediumImageUrl(),
        followers: spotifyData.followers,
        genres: spotifyData.genres,
        popularity: spotifyData.popularity,
      );

      await box.put(artistName.toLowerCase(), cachedArtist);
      return cachedArtist;
    } catch (e) {
      // Return cached even if expired on error
      try {
        final box = await Hive.openBox<CachedSpotifyArtist>(_boxName);
        return box.get(artistName.toLowerCase());
      } catch (_) {
        return null;
      }
    }
  }

  /// Preload multiple artists in background
  Future<void> preloadArtists(List<String> artistNames) async {
    for (final artistName in artistNames) {
      // Don't await - fire and forget
      getOrFetchArtist(artistName).catchError((_) => null);

      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 100));
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
