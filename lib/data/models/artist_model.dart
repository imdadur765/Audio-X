import 'package:audio_x/data/models/song_model.dart';
import 'package:audio_x/data/models/local_song_model.dart';

class Artist {
  final String id;
  final String name;
  final String? imageUrl;
  final int songsCount;
  final int localSongsCount;
  final String followers;
  final List<Song> popularSongs;
  final List<LocalSong> localSongs;
  final int popularity;
  final List<String> genres;

  Artist({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.songsCount,
    this.localSongsCount = 0,
    required this.followers,
    required this.popularSongs,
    this.localSongs = const [],
    required this.popularity,
    required this.genres,
  });

  factory Artist.fromSpotifyJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      imageUrl: _parseImage(json),
      songsCount: 0,
      localSongsCount: 0,
      followers: _formatFollowers(json['followers']?['total'] ?? 0),
      popularSongs: [],
      localSongs: [],
      popularity: json['popularity'] ?? 0,
      genres: (json['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  factory Artist.fromLocalData({required String name, required List<LocalSong> localSongs}) {
    return Artist(
      id: 'local_$name',
      name: name,
      imageUrl: null,
      songsCount: localSongs.length,
      localSongsCount: localSongs.length,
      followers: 'Local Artist',
      popularSongs: [],
      localSongs: localSongs,
      popularity: 0,
      genres: [],
    );
  }

  factory Artist.fromCombinedData({required Artist spotifyArtist, required List<LocalSong> localSongs}) {
    return Artist(
      id: spotifyArtist.id,
      name: spotifyArtist.name,
      imageUrl: spotifyArtist.imageUrl,
      songsCount: localSongs.length,
      localSongsCount: localSongs.length,
      followers: spotifyArtist.followers,
      popularSongs: spotifyArtist.popularSongs,
      localSongs: localSongs,
      popularity: spotifyArtist.popularity,
      genres: spotifyArtist.genres,
    );
  }

  static String? _parseImage(Map<String, dynamic> json) {
    if (json['images'] is List && (json['images'] as List).isNotEmpty) {
      return json['images'][0]['url'];
    }
    return null;
  }

  static String _formatFollowers(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
