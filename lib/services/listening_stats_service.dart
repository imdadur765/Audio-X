import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to calculate listening statistics like streaks and activity
class ListeningStatsService {
  static const String _bestStreakKey = 'streak_best';
  static const String _playHistoryKey = 'play_history';

  /// Get the current consecutive days streak
  Future<int> getCurrentStreak() async {
    final datesSet = await _getListeningDates();
    if (datesSet.isEmpty) return 0;

    // Convert to list and sort descending (most recent first)
    final dates = datesSet.toList()..sort((a, b) => b.compareTo(a));

    final today = _dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));

    // Check if listened today or yesterday (streak is active)
    if (dates.first != today && dates.first != yesterday) {
      return 0; // Streak broken
    }

    int streak = 0;
    DateTime checkDate = dates.first;

    for (final date in dates) {
      if (date == checkDate) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (date.isBefore(checkDate)) {
        // Gap found, streak ends
        break;
      }
      // Skip duplicates (same date)
    }

    // Update best streak if current is higher
    await _updateBestStreak(streak);

    return streak;
  }

  /// Get the best streak ever achieved
  Future<int> getBestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_bestStreakKey) ?? 0;
  }

  /// Update best streak if current is higher
  Future<void> _updateBestStreak(int currentStreak) async {
    final prefs = await SharedPreferences.getInstance();
    final best = prefs.getInt(_bestStreakKey) ?? 0;
    if (currentStreak > best) {
      await prefs.setInt(_bestStreakKey, currentStreak);
    }
  }

  /// Get listening activity for the last 7 days
  /// Returns a list of 7 booleans [today, yesterday, ..., 6 days ago]
  Future<List<bool>> getWeeklyActivity() async {
    final dates = await _getListeningDates();
    final today = _dateOnly(DateTime.now());

    List<bool> activity = [];
    for (int i = 0; i < 7; i++) {
      final checkDate = today.subtract(Duration(days: i));
      activity.add(dates.contains(checkDate));
    }

    return activity;
  }

  /// Get unique dates when user listened to music
  Future<Set<DateTime>> _getListeningDates() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_playHistoryKey);

    if (historyJson == null) return {};

    try {
      final List<dynamic> history = jsonDecode(historyJson);
      final Set<DateTime> dates = {};

      for (final entry in history) {
        if (entry['timestamp'] != null) {
          final timestamp = DateTime.parse(entry['timestamp']);
          dates.add(_dateOnly(timestamp));
        }
      }

      return dates;
    } catch (e) {
      return {};
    }
  }

  /// Strip time from DateTime, keeping only date
  DateTime _dateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Get top artists by play count
  /// Returns list of maps: [{name, playCount, imageUrl}]
  static List<Map<String, dynamic>> getTopArtists(List<dynamic> songs, {int limit = 5}) {
    final Map<String, int> artistPlays = {};

    for (final song in songs) {
      final artist = song.artist as String;
      final plays = song.playCount as int;
      artistPlays[artist] = (artistPlays[artist] ?? 0) + plays;
    }

    // Sort by plays descending
    final sortedArtists = artistPlays.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Return top N
    return sortedArtists.take(limit).map((e) => {'name': e.key, 'playCount': e.value}).toList();
  }

  /// Get top genres from songs (using album as proxy if genre not available)
  static List<Map<String, dynamic>> getTopGenres(List<dynamic> songs, {int limit = 3}) {
    final Map<String, int> genrePlays = {};

    for (final song in songs) {
      // Use album as genre proxy (or you can add genre field to Song model)
      final genre = _extractGenreFromAlbum(song.album as String);
      final plays = song.playCount as int;
      if (genre.isNotEmpty) {
        genrePlays[genre] = (genrePlays[genre] ?? 0) + plays;
      }
    }

    final sortedGenres = genrePlays.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return sortedGenres.take(limit).map((e) => {'name': e.key, 'playCount': e.value}).toList();
  }

  /// Simple genre extraction from album name (heuristic)
  static String _extractGenreFromAlbum(String album) {
    // Common genre keywords
    final genreKeywords = {
      'romance': 'Romance',
      'love': 'Romance',
      'rock': 'Rock',
      'pop': 'Pop',
      'classical': 'Classical',
      'hip hop': 'Hip Hop',
      'rap': 'Hip Hop',
      'jazz': 'Jazz',
      'edm': 'EDM',
      'electronic': 'Electronic',
      'bollywood': 'Bollywood',
      'punjabi': 'Punjabi',
      'indie': 'Indie',
      'acoustic': 'Acoustic',
    };

    final lowerAlbum = album.toLowerCase();
    for (final entry in genreKeywords.entries) {
      if (lowerAlbum.contains(entry.key)) {
        return entry.value;
      }
    }

    // If no match, use first word of album as category
    final words = album.split(' ');
    if (words.isNotEmpty && words.first.length > 2) {
      return words.first;
    }

    return 'Other';
  }
}
