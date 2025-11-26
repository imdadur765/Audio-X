import 'package:audio_x/data/models/song_model.dart';
import 'package:audio_x/data/models/spotify_artist_model.dart';

/// Hybrid artist model combining local songs with Spotify metadata
class ArtistModel {
  /// Artist name from local songs
  final String name;

  /// List of local songs by this artist
  final List<Song> localSongs;

  /// Spotify metadata (null if not fetched or offline)
  final SpotifyArtistModel? spotifyData;

  /// Whether Spotify data fetch was attempted
  final bool spotifyDataFetched;

  /// Error message if Spotify fetch failed
  final String? spotifyError;

  ArtistModel({
    required this.name,
    required this.localSongs,
    this.spotifyData,
    this.spotifyDataFetched = false,
    this.spotifyError,
  });

  /// Get total number of local songs
  int get songCount => localSongs.length;

  /// Get total duration of all songs in milliseconds
  int get totalDuration => localSongs.fold(0, (sum, song) => sum + song.duration);

  /// Get formatted total duration (e.g., "2h 34m")
  String getFormattedTotalDuration() {
    final hours = totalDuration ~/ (1000 * 60 * 60);
    final minutes = (totalDuration % (1000 * 60 * 60)) ~/ (1000 * 60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Check if Spotify data is available
  bool get hasSpotifyData => spotifyData != null;

  /// Get display image (Spotify or placeholder)
  String? get imageUrl => spotifyData?.imageUrl;

  /// Get follower count from Spotify
  int? get followers => spotifyData?.followers;

  /// Get genres from Spotify
  List<String> get genres => spotifyData?.genres ?? [];

  /// Get popularity from Spotify
  int? get popularity => spotifyData?.popularity;

  /// Create a copy with updated Spotify data
  ArtistModel copyWith({
    String? name,
    List<Song>? localSongs,
    SpotifyArtistModel? spotifyData,
    bool? spotifyDataFetched,
    String? spotifyError,
  }) {
    return ArtistModel(
      name: name ?? this.name,
      localSongs: localSongs ?? this.localSongs,
      spotifyData: spotifyData ?? this.spotifyData,
      spotifyDataFetched: spotifyDataFetched ?? this.spotifyDataFetched,
      spotifyError: spotifyError ?? this.spotifyError,
    );
  }

  /// Create offline-only artist (no Spotify data)
  factory ArtistModel.localOnly({required String name, required List<Song> localSongs}) {
    return ArtistModel(name: name, localSongs: localSongs, spotifyData: null, spotifyDataFetched: false);
  }

  /// Create with Spotify data
  factory ArtistModel.withSpotify({
    required String name,
    required List<Song> localSongs,
    required SpotifyArtistModel spotifyData,
  }) {
    return ArtistModel(name: name, localSongs: localSongs, spotifyData: spotifyData, spotifyDataFetched: true);
  }

  @override
  String toString() {
    return 'ArtistModel(name: $name, songs: ${localSongs.length}, hasSpotify: $hasSpotifyData)';
  }
}
