import 'package:hive/hive.dart';

part 'search_history_model.g.dart';

@HiveType(typeId: 4) // typeId 4 (0: Song, 1: AudioEffects, 3: Artist)
class SearchHistory extends HiveObject {
  @HiveField(0)
  final String query;

  @HiveField(1)
  final DateTime timestamp;

  SearchHistory({required this.query, required this.timestamp});
}
