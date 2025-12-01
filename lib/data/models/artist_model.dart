import 'package:hive/hive.dart';

part 'artist_model.g.dart';

@HiveType(typeId: 3) // Ensure typeId is unique. Song is 0, AudioEffects is 2.
class Artist extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String? biography;

  @HiveField(2)
  final String? imageUrl;

  @HiveField(3)
  final List<String> tags;

  @HiveField(4)
  final DateTime lastUpdated;

  @HiveField(5)
  final int followers;

  @HiveField(6)
  final int popularity;

  @HiveField(7)
  final List<Map<String, String>> similarArtists;

  @HiveField(8)
  final List<Map<String, String>> topAlbums;

  Artist({
    required this.name,
    this.biography,
    this.imageUrl,
    this.tags = const [],
    required this.lastUpdated,
    this.followers = 0,
    this.popularity = 0,
    this.similarArtists = const [],
    this.topAlbums = const [],
  });
}
