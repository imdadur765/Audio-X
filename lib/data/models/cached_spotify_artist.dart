import 'package:hive/hive.dart';

part 'cached_spotify_artist.g.dart';

@HiveType(typeId: 1)
class CachedSpotifyArtist extends HiveObject {
  @HiveField(0)
  final String artistName;

  @HiveField(1)
  final String? spotifyId;

  @HiveField(2)
  final String? imageUrl;

  @HiveField(3)
  final int? followers;

  @HiveField(4)
  final List<String> genres;

  @HiveField(5)
  final int? popularity;

  @HiveField(6)
  final DateTime cachedAt;

  CachedSpotifyArtist({
    required this.artistName,
    this.spotifyId,
    this.imageUrl,
    this.followers,
    required this.genres,
    this.popularity,
    required this.cachedAt,
  });

  /// Check if cache is still valid (7 days)
  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(cachedAt);
    return difference.inDays > 7;
  }

  /// Create from Spotify API response
  factory CachedSpotifyArtist.fromSpotifyData({
    required String artistName,
    required String spotifyId,
    String? imageUrl,
    int? followers,
    required List<String> genres,
    int? popularity,
  }) {
    return CachedSpotifyArtist(
      artistName: artistName,
      spotifyId: spotifyId,
      imageUrl: imageUrl,
      followers: followers,
      genres: genres,
      popularity: popularity,
      cachedAt: DateTime.now(),
    );
  }
}
