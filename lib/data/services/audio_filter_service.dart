import '../../data/models/song_model.dart';

/// Service to filter out invalid/junk audio files
/// Prevents processing of recordings, system files, and unknown tracks
class AudioFilterService {
  // Patterns for invalid file names
  static final List<RegExp> _invalidPatterns = [
    // Unknown files with numbers: "Unknown Audio 1552", "<unknown> Audio", "Audio 1234"
    RegExp(r'(unknown|audio)\s*\d+', caseSensitive: false),
    RegExp(r'<unknown>', caseSensitive: false),

    // Call recordings and phone recordings
    RegExp(r'(call\s*recording|phone\s*recording|voice\s*memo|voice\s*recording)', caseSensitive: false),
    RegExp(r'conference\s*call', caseSensitive: false),
    RegExp(r'recorded\s*call', caseSensitive: false),

    // Files with only numbers (like "5224758", "123456")
    RegExp(r'^\d{5,}$'), // 5 or more consecutive digits
    // Standard Android recording patterns
    RegExp(r'recording_\d+', caseSensitive: false),
    RegExp(r'audio_record_\d+', caseSensitive: false),

    // Generic/system audio
    RegExp(r'^audio\s*$', caseSensitive: false),
    RegExp(r'^track\s*\d+$', caseSensitive: false),
  ];

  /// Check if a song is valid (not a recording or junk file)
  bool isValidSong(Song song) {
    return isValidFileName(song.title) && isValidFileName(song.artist);
  }

  /// Check if a file name is valid
  bool isValidFileName(String name) {
    if (name.trim().isEmpty) return false;

    // Check against all invalid patterns
    for (final pattern in _invalidPatterns) {
      if (pattern.hasMatch(name)) {
        return false;
      }
    }

    return true;
  }

  /// Filter a list of songs, removing invalid ones
  List<Song> filterSongs(List<Song> songs) {
    return songs.where((song) => isValidSong(song)).toList();
  }

  /// Get count of filtered songs
  int getFilteredCount(List<Song> originalSongs, List<Song> filteredSongs) {
    return originalSongs.length - filteredSongs.length;
  }

  /// Get detailed filter statistics
  Map<String, dynamic> getFilterStats(List<Song> songs) {
    int totalSongs = songs.length;
    int invalidByTitle = 0;
    int invalidByArtist = 0;

    for (final song in songs) {
      if (!isValidFileName(song.title)) invalidByTitle++;
      if (!isValidFileName(song.artist)) invalidByArtist++;
    }

    return {
      'total': totalSongs,
      'invalidByTitle': invalidByTitle,
      'invalidByArtist': invalidByArtist,
      'valid': totalSongs - invalidByTitle - invalidByArtist,
    };
  }

  /// Check if a song name matches specific pattern (for debugging)
  String? getMatchedPattern(String name) {
    for (final pattern in _invalidPatterns) {
      if (pattern.hasMatch(name)) {
        return pattern.pattern;
      }
    }
    return null;
  }
}
