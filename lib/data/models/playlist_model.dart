import '../models/song_model.dart';

class Playlist {
  final String id;
  final String name;
  final List<String> songIds;
  final DateTime created;
  final bool isAuto; // Auto-generated (Favorites, Recent, etc.) vs Manual
  final String iconEmoji; // Emoji for playlist card

  Playlist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.created,
    this.isAuto = false,
    this.iconEmoji = '🎵',
  });

  // Get actual songs from song IDs, preserving order
  List<Song> getSongs(List<Song> allSongs) {
    final songMap = {for (var s in allSongs) s.id: s};
    return songIds
        .map((id) => songMap[id])
        .whereType<Song>() // Filter out nulls if song not found
        .toList();
  }

  // Get total duration of all songs in playlist
  Duration getTotalDuration(List<Song> allSongs) {
    final songs = getSongs(allSongs);
    return Duration(milliseconds: songs.fold(0, (sum, song) => sum + song.duration));
  }

  // Get song count
  int get songCount => songIds.length;

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'songIds': songIds,
      'created': created.toIso8601String(),
      'isAuto': isAuto,
      'iconEmoji': iconEmoji,
    };
  }

  // Create from JSON
  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      songIds: List<String>.from(json['songIds'] as List),
      created: DateTime.parse(json['created'] as String),
      isAuto: json['isAuto'] as bool? ?? false,
      iconEmoji: json['iconEmoji'] as String? ?? '🎵',
    );
  }

  // Copy with method for updates
  Playlist copyWith({
    String? id,
    String? name,
    List<String>? songIds,
    DateTime? created,
    bool? isAuto,
    String? iconEmoji,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
      created: created ?? this.created,
      isAuto: isAuto ?? this.isAuto,
      iconEmoji: iconEmoji ?? this.iconEmoji,
    );
  }
}
