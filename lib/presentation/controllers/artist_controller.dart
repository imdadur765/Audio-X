import 'package:flutter/material.dart';
import 'package:audio_x/data/models/artist_model.dart';
import 'package:audio_x/data/models/song_model.dart';
import 'package:audio_x/data/services/spotify_cache_service.dart';
import 'package:audio_x/data/models/spotify_artist_model.dart';

class ArtistController extends ChangeNotifier {
  final SpotifyCacheService _cacheService = SpotifyCacheService();

  ArtistModel? _currentArtist;
  bool _isLoading = false;
  String? _errorMessage;

  ArtistModel? get currentArtist => _currentArtist;
  set currentArtist(ArtistModel? value) {
    _currentArtist = value;
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasSpotifyData => _currentArtist?.hasSpotifyData ?? false;

  /// Load artist with Spotify metadata (Cached)
  Future<void> loadArtist({required String artistName, required List<Song> localSongs}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Create initial artist with local data only
      _currentArtist = ArtistModel.localOnly(name: artistName, localSongs: localSongs);
      notifyListeners(); // Show local data immediately

      // Try to fetch Spotify metadata (from Cache or API)
      final cachedData = await _cacheService.getOrFetchArtist(artistName);

      if (cachedData != null) {
        // Convert CachedSpotifyArtist to SpotifyArtistModel
        final spotifyData = SpotifyArtistModel(
          id: cachedData.spotifyId ?? '',
          name: cachedData.artistName,
          imageUrl: cachedData.imageUrl,
          images: [], // Not stored in cache model currently
          followers: cachedData.followers ?? 0,
          genres: cachedData.genres,
          popularity: cachedData.popularity ?? 0,
        );

        // Update with Spotify data
        _currentArtist = _currentArtist!.copyWith(spotifyData: spotifyData, spotifyDataFetched: true);
      } else {
        // Mark as fetched but no data found
        _currentArtist = _currentArtist!.copyWith(
          spotifyDataFetched: true,
          spotifyError: 'Artist not found on Spotify',
        );
      }
    } catch (e) {
      _errorMessage = e.toString();
      // Keep local artist data even if Spotify fetch fails
      _currentArtist ??= ArtistModel.localOnly(name: artistName, localSongs: localSongs);
      _currentArtist = _currentArtist!.copyWith(spotifyDataFetched: true, spotifyError: e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh Spotify data (Force fetch)
  Future<void> refreshSpotifyData() async {
    if (_currentArtist == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // For refresh, we might want to force API, but for now let's stick to cache service
      // which handles expiration. If we really want force refresh, we'd need a method in service.
      // For now, getOrFetchArtist is sufficient as it handles expiration.
      final cachedData = await _cacheService.getOrFetchArtist(_currentArtist!.name);

      if (cachedData != null) {
        final spotifyData = SpotifyArtistModel(
          id: cachedData.spotifyId ?? '',
          name: cachedData.artistName,
          imageUrl: cachedData.imageUrl,
          images: [],
          followers: cachedData.followers ?? 0,
          genres: cachedData.genres,
          popularity: cachedData.popularity ?? 0,
        );

        _currentArtist = _currentArtist!.copyWith(
          spotifyData: spotifyData,
          spotifyDataFetched: true,
          spotifyError: null,
        );
      } else {
        _currentArtist = _currentArtist!.copyWith(
          spotifyDataFetched: true,
          spotifyError: 'Artist not found on Spotify',
        );
      }
    } catch (e) {
      _errorMessage = e.toString();
      _currentArtist = _currentArtist!.copyWith(spotifyError: e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear current artist
  void clearArtist() {
    _currentArtist = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
