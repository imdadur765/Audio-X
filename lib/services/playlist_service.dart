import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../data/models/playlist_model.dart';
import '../data/models/song_model.dart';

class PlaylistService {
  static const String _playlistsKey = 'custom_playlists';
  static const String _playHistoryKey = 'play_history';

  final Uuid _uuid = const Uuid();

  // Get all custom playlists
  Future<List<Playlist>> getCustomPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final playlistsJson = prefs.getString(_playlistsKey);

    if (playlistsJson == null || playlistsJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(playlistsJson);
      return decoded.map((json) => Playlist.fromJson(json)).toList();
    } catch (e) {
      print('Error loading playlists: $e');
      return [];
    }
  }

  // Save custom playlists
  Future<void> _saveCustomPlaylists(List<Playlist> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    final playlistsJson = jsonEncode(playlists.map((p) => p.toJson()).toList());
    await prefs.setString(_playlistsKey, playlistsJson);
  }

  // Create new playlist
  Future<Playlist> createPlaylist(String name, {String iconEmoji = '🎵'}) async {
    final playlists = await getCustomPlaylists();

    final newPlaylist = Playlist(
      id: _uuid.v4(),
      name: name,
      songIds: [],
      created: DateTime.now(),
      isAuto: false,
      iconEmoji: iconEmoji,
    );

    playlists.add(newPlaylist);
    await _saveCustomPlaylists(playlists);

    return newPlaylist;
  }

  // Add song to playlist
  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final playlists = await getCustomPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);

    if (index != -1) {
      if (!playlists[index].songIds.contains(songId)) {
        final updatedSongIds = List<String>.from(playlists[index].songIds)..add(songId);
        playlists[index] = playlists[index].copyWith(songIds: updatedSongIds);
        await _saveCustomPlaylists(playlists);
      }
    }
  }

  // Remove song from playlist
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final playlists = await getCustomPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);

    if (index != -1) {
      final updatedSongIds = List<String>.from(playlists[index].songIds)..remove(songId);
      playlists[index] = playlists[index].copyWith(songIds: updatedSongIds);
      await _saveCustomPlaylists(playlists);
    }
  }

  // Delete playlist
  Future<void> deletePlaylist(String playlistId) async {
    final playlists = await getCustomPlaylists();
    playlists.removeWhere((p) => p.id == playlistId);
    await _saveCustomPlaylists(playlists);
  }

  // Rename playlist
  Future<void> renamePlaylist(String playlistId, String newName) async {
    final playlists = await getCustomPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);

    if (index != -1) {
      playlists[index] = playlists[index].copyWith(name: newName);
      await _saveCustomPlaylists(playlists);
    }
  }

  // === AUTO-GENERATED PLAYLISTS ===

  // Get Favorites playlist
  Playlist getFavoritesPlaylist(List<Song> allSongs) {
    // Filter songs that are marked as favorites
    final favoriteSongs = allSongs.where((song) => song.isFavorite == true).toList();

    return Playlist(
      id: 'auto_favorites',
      name: 'Favorites',
      songIds: favoriteSongs.map((s) => s.id).toList(),
      created: DateTime.now(),
      isAuto: true,
      iconEmoji: '💜',
    );
  }

  // Get Recently Played playlist
  Future<Playlist> getRecentlyPlayedPlaylist(List<Song> allSongs) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_playHistoryKey);

    List<String> recentSongIds = [];

    if (historyJson != null && historyJson.isNotEmpty) {
      try {
        final List<dynamic> history = jsonDecode(historyJson);
        // Get unique song IDs from history, limited to last 30
        final seenIds = <String>{};
        for (var item in history.reversed) {
          final songId = item['songId'] as String;
          if (!seenIds.contains(songId)) {
            seenIds.add(songId);
            recentSongIds.add(songId);
          }
          if (recentSongIds.length >= 30) break;
        }
      } catch (e) {
        print('Error loading play history: $e');
      }
    }

    return Playlist(
      id: 'auto_recent',
      name: 'Recently Played',
      songIds: recentSongIds,
      created: DateTime.now(),
      isAuto: true,
      iconEmoji: '🕐',
    );
  }

  // Get Most Played playlist
  Playlist getMostPlayedPlaylist(List<Song> allSongs) {
    // Filter songs that have been played at least once
    final playedSongs = allSongs.where((s) => s.playCount > 0).toList();

    // Sort songs by play count and take top 25
    final sortedSongs = playedSongs..sort((a, b) => b.playCount.compareTo(a.playCount));

    final topSongs = sortedSongs.take(25).toList();

    return Playlist(
      id: 'auto_most_played',
      name: 'Most Played',
      songIds: topSongs.map((s) => s.id).toList(),
      created: DateTime.now(),
      isAuto: true,
      iconEmoji: '🔥',
    );
  }

  // Get All Songs playlist
  Playlist getAllSongsPlaylist(List<Song> allSongs) {
    return Playlist(
      id: 'auto_all_songs',
      name: 'All Songs',
      songIds: allSongs.map((s) => s.id).toList(),
      created: DateTime.now(),
      isAuto: true,
      iconEmoji: '🎵',
    );
  }

  // Get Recently Added playlist
  Playlist getRecentlyAddedPlaylist(List<Song> allSongs) {
    // Filter out short songs (double check) and sort by dateAdded (descending)
    final validSongs = allSongs.where((s) => s.duration >= 30000).toList();
    final sortedSongs = List<Song>.from(validSongs)..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));

    final topSongs = sortedSongs.take(50).toList();

    return Playlist(
      id: 'auto_recently_added',
      name: 'Recently Added',
      songIds: topSongs.map((s) => s.id).toList(),
      created: DateTime.now(),
      isAuto: true,
      iconEmoji: '🆕',
    );
  }

  // Get all playlists (auto + custom)
  Future<List<Playlist>> getAllPlaylists(List<Song> allSongs) async {
    final autoPlaylists = [
      getFavoritesPlaylist(allSongs),
      await getRecentlyPlayedPlaylist(allSongs),
      getMostPlayedPlaylist(allSongs),
      getRecentlyAddedPlaylist(allSongs),
      getAllSongsPlaylist(allSongs),
    ];

    final customPlaylists = await getCustomPlaylists();

    return [...autoPlaylists, ...customPlaylists];
  }
}
