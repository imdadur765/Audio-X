class LocalSong {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String path;
  final int duration;
  final int size;

  String get uri => path;

  LocalSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    required this.duration,
    required this.size,
  });
}
