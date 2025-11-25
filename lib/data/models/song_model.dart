import 'package:hive/hive.dart';

part 'song_model.g.dart';

@HiveType(typeId: 0)
class Song extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String artist;

  @HiveField(3)
  final String album;

  @HiveField(4)
  final String uri;

  @HiveField(5)
  final String? artworkUri;

  @HiveField(6)
  final int duration;

  @HiveField(7)
  String? localArtworkPath;

  @HiveField(8)
  String? lyricsPath; // Path to manual .lrc file

  @HiveField(9)
  String? lyricsSource; // 'lrclib', 'manual', 'cached', null

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.uri,
    this.artworkUri,
    required this.duration,
    this.localArtworkPath,
    this.lyricsPath,
    this.lyricsSource,
  });
}
