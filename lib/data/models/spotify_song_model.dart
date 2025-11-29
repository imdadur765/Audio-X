class SpotifySongModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? artworkUrl;
  final int duration;
  final String? previewUrl;
  final String? uri;

  SpotifySongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.artworkUrl,
    required this.duration,
    this.previewUrl,
    this.uri,
  });

  factory SpotifySongModel.fromJson(Map<String, dynamic> json) {
    // Handle nested structure if necessary (Spotify API often has nested artists/album)
    // Assuming simplified JSON from our backend proxy
    return SpotifySongModel(
      id: json['id'] ?? '',
      title: json['name'] ?? json['title'] ?? 'Unknown',
      artist: _parseArtist(json),
      album: json['album'] is Map ? (json['album']['name'] ?? '') : (json['album'] ?? ''),
      artworkUrl: _parseArtwork(json),
      duration: json['duration_ms'] ?? json['duration'] ?? 0,
      previewUrl: json['preview_url'],
      uri: json['uri'],
    );
  }

  static String _parseArtist(Map<String, dynamic> json) {
    if (json['artists'] is List && (json['artists'] as List).isNotEmpty) {
      return json['artists'][0]['name'] ?? 'Unknown';
    }
    return json['artist'] ?? 'Unknown';
  }

  static String? _parseArtwork(Map<String, dynamic> json) {
    if (json['album'] is Map && json['album']['images'] is List) {
      final images = json['album']['images'] as List;
      if (images.isNotEmpty) {
        return images[0]['url'];
      }
    }
    return json['artworkUrl'] ?? json['imageUrl'];
  }
}
