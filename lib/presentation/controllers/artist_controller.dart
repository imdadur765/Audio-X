import 'package:flutter/material.dart';
import 'package:audio_x/data/models/artist_model.dart';
import 'package:audio_x/data/models/song_model.dart';
import 'package:audio_x/data/services/spotify_api_service.dart';

class ArtistController extends ChangeNotifier {
  final SpotifyApiService _spotifyService = SpotifyApiService();

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

  /// Load artist with Spotify metadata
  Future<void> loadArtist({required String artistName, required List<Song> localSongs}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Create initial artist with local data only
      _currentArtist = ArtistModel.localOnly(name: artistName, localSongs: localSongs);
      notifyListeners(); // Show local data immediately

      // Try to fetch Spotify metadata
      final spotifyData = await _spotifyService.getBestMatchingArtist(artistName);

      if (spotifyData != null) {
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

  /// Refresh Spotify data
  Future<void> refreshSpotifyData() async {
    if (_currentArtist == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final spotifyData = await _spotifyService.getBestMatchingArtist(_currentArtist!.name);

      if (spotifyData != null) {
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
