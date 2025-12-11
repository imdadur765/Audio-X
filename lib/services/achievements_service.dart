import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Achievement definition
class Achievement {
  final String id;
  final String name;
  final String description;
  final String iconPath;
  final int requiredValue;
  final AchievementType type;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconPath,
    required this.requiredValue,
    required this.type,
  });
}

enum AchievementType { totalPlays, favorites, playlists, streak, nightOwl }

/// Service to manage achievements
class AchievementsService {
  static const String _unlockedKey = 'unlocked_achievements';
  static const String _nightOwlKey = 'night_owl_unlocked';

  /// All available achievements
  static const List<Achievement> allAchievements = [
    Achievement(
      id: 'first_steps',
      name: 'First Steps',
      description: 'Play your first song',
      iconPath: 'assets/images/badge.png',
      requiredValue: 1,
      type: AchievementType.totalPlays,
    ),
    Achievement(
      id: 'music_lover',
      name: 'Music Lover',
      description: 'Play 50 songs',
      iconPath: 'assets/images/most_played.png',
      requiredValue: 50,
      type: AchievementType.totalPlays,
    ),
    Achievement(
      id: 'audiophile',
      name: 'Audiophile',
      description: 'Play 500 songs',
      iconPath: 'assets/images/equalizer.png',
      requiredValue: 500,
      type: AchievementType.totalPlays,
    ),
    Achievement(
      id: 'favorite_hunter',
      name: 'Favorite Hunter',
      description: 'Add 10 songs to favorites',
      iconPath: 'assets/images/favorite.png',
      requiredValue: 10,
      type: AchievementType.favorites,
    ),
    Achievement(
      id: 'playlist_creator',
      name: 'Playlist Creator',
      description: 'Create 3 playlists',
      iconPath: 'assets/images/playlist_open.png',
      requiredValue: 3,
      type: AchievementType.playlists,
    ),
    Achievement(
      id: 'night_owl',
      name: 'Night Owl',
      description: 'Listen to music after midnight',
      iconPath: 'assets/images/recently_played.png',
      requiredValue: 1,
      type: AchievementType.nightOwl,
    ),
    Achievement(
      id: 'streak_starter',
      name: 'Streak Starter',
      description: 'Get a 3-day listening streak',
      iconPath: 'assets/images/day_streak.png',
      requiredValue: 3,
      type: AchievementType.streak,
    ),
    Achievement(
      id: 'streak_master',
      name: 'Streak Master',
      description: 'Get a 7-day listening streak',
      iconPath: 'assets/images/best_streak.png',
      requiredValue: 7,
      type: AchievementType.streak,
    ),
  ];

  /// Get list of unlocked achievement IDs
  Future<Set<String>> getUnlockedAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_unlockedKey);
    if (json == null) return {};

    try {
      final List<dynamic> list = jsonDecode(json);
      return list.map((e) => e.toString()).toSet();
    } catch (e) {
      return {};
    }
  }

  /// Unlock an achievement
  Future<void> unlockAchievement(String achievementId) async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = await getUnlockedAchievements();
    unlocked.add(achievementId);
    await prefs.setString(_unlockedKey, jsonEncode(unlocked.toList()));
  }

  /// Check and unlock achievements based on current stats
  Future<List<Achievement>> checkAndUnlockAchievements({
    required int totalPlays,
    required int favoritesCount,
    required int playlistsCount,
    required int currentStreak,
    required int bestStreak,
  }) async {
    final unlocked = await getUnlockedAchievements();
    final newlyUnlocked = <Achievement>[];

    // Check night owl separately (time-based)
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 5) {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_nightOwlKey)) {
        await prefs.setBool(_nightOwlKey, true);
        await unlockAchievement('night_owl');
        newlyUnlocked.add(allAchievements.firstWhere((a) => a.id == 'night_owl'));
      }
    }

    for (final achievement in allAchievements) {
      if (unlocked.contains(achievement.id)) continue;

      bool shouldUnlock = false;

      switch (achievement.type) {
        case AchievementType.totalPlays:
          shouldUnlock = totalPlays >= achievement.requiredValue;
          break;
        case AchievementType.favorites:
          shouldUnlock = favoritesCount >= achievement.requiredValue;
          break;
        case AchievementType.playlists:
          shouldUnlock = playlistsCount >= achievement.requiredValue;
          break;
        case AchievementType.streak:
          // Check both current and best streak
          final maxStreak = currentStreak > bestStreak ? currentStreak : bestStreak;
          shouldUnlock = maxStreak >= achievement.requiredValue;
          break;
        case AchievementType.nightOwl:
          // Handled separately above
          break;
      }

      if (shouldUnlock) {
        await unlockAchievement(achievement.id);
        newlyUnlocked.add(achievement);
      }
    }

    return newlyUnlocked;
  }

  /// Get all achievements with their unlock status
  Future<List<Map<String, dynamic>>> getAchievementsWithStatus({
    required int totalPlays,
    required int favoritesCount,
    required int playlistsCount,
    required int currentStreak,
    required int bestStreak,
  }) async {
    // First check and unlock any new achievements
    await checkAndUnlockAchievements(
      totalPlays: totalPlays,
      favoritesCount: favoritesCount,
      playlistsCount: playlistsCount,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
    );

    final unlocked = await getUnlockedAchievements();

    return allAchievements.map((a) {
      int progress = 0;
      switch (a.type) {
        case AchievementType.totalPlays:
          progress = totalPlays;
          break;
        case AchievementType.favorites:
          progress = favoritesCount;
          break;
        case AchievementType.playlists:
          progress = playlistsCount;
          break;
        case AchievementType.streak:
          progress = currentStreak > bestStreak ? currentStreak : bestStreak;
          break;
        case AchievementType.nightOwl:
          progress = unlocked.contains(a.id) ? 1 : 0;
          break;
      }

      return {'achievement': a, 'isUnlocked': unlocked.contains(a.id), 'progress': progress};
    }).toList();
  }
}
