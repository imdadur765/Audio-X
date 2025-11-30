import 'package:hive/hive.dart';

part 'artist_model.g.dart';

@HiveType(typeId: 2) // Ensure typeId is unique. Song is likely 0 or 1.
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

  Artist({required this.name, this.biography, this.imageUrl, this.tags = const [], required this.lastUpdated});
}
