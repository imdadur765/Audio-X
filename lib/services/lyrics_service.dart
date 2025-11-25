import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../data/models/lyrics_model.dart';

class LyricsService {
  static const String _baseUrl = 'https://lrclib.net/api';
  static const Duration _timeout = Duration(seconds: 10);

  // Fetch lyrics from LRCLIB API
  Future<Lyrics?> fetchFromLRCLIB({
    required String title,
    required String artist,
    String? album,
    int? durationSeconds,
  }) async {
    try {
      // Build query parameters
      final queryParams = {
        'track_name': title,
        'artist_name': artist,
        if (album != null && album.isNotEmpty) 'album_name': album,
        if (durationSeconds != null) 'duration': durationSeconds.toString(),
      };

      final uri = Uri.parse('$_baseUrl/get').replace(queryParameters: queryParams);

      print('🎵 Fetching lyrics from LRCLIB: $title - $artist');

      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final lyrics = Lyrics.fromLRCLIB(json);

        if (lyrics.isNotEmpty) {
          print('✅ Lyrics found: ${lyrics.lines.length} lines');
          return lyrics;
        } else {
          print('⚠️ Lyrics response empty');
          return null;
        }
      } else if (response.statusCode == 404) {
        print('❌ Lyrics not found on LRCLIB');
        return null;
      } else {
        print('❌ LRCLIB API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching lyrics: $e');
      return null;
    }
  }

  // Save lyrics to local cache
  Future<String?> saveLRCFile(String songId, String lrcContent) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final lyricsDir = Directory('${directory.path}/lyrics');

      if (!await lyricsDir.exists()) {
        await lyricsDir.create(recursive: true);
      }

      final file = File('${lyricsDir.path}/$songId.lrc');
      await file.writeAsString(lrcContent);

      print('💾 Lyrics saved: ${file.path}');
      return file.path;
    } catch (e) {
      print('❌ Error saving lyrics: $e');
      return null;
    }
  }

  // Load lyrics from local cache
  Future<Lyrics?> loadLocalLRC(String songId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/lyrics/$songId.lrc');

      if (await file.exists()) {
        final content = await file.readAsString();
        print('📖 Loaded cached lyrics for: $songId');
        return Lyrics.fromLRCString(content, source: 'cached');
      }
      return null;
    } catch (e) {
      print('❌ Error loading cached lyrics: $e');
      return null;
    }
  }

  // Load lyrics from user-provided file path
  Future<Lyrics?> loadFromPath(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        return Lyrics.fromLRCString(content, source: 'manual');
      }
      return null;
    } catch (e) {
      print('❌ Error loading lyrics from path: $e');
      return null;
    }
  }

  // Pick .lrc file from device
  Future<String?> pickLRCFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['lrc', 'txt'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        print('📁 User selected lyrics file: $path');
        return path;
      }
      return null;
    } catch (e) {
      print('❌ Error picking file: $e');
      return null;
    }
  }

  // Get lyrics with priority: manual > cached > online
  Future<Lyrics?> getLyrics({
    required String songId,
    required String title,
    required String artist,
    String? album,
    int? durationSeconds,
    String? manualLyricsPath,
  }) async {
    // Priority 1: Manual lyrics
    if (manualLyricsPath != null) {
      final lyrics = await loadFromPath(manualLyricsPath);
      if (lyrics != null) {
        print('✅ Using manual lyrics');
        return lyrics;
      }
    }

    // Priority 2: Cached lyrics
    final cachedLyrics = await loadLocalLRC(songId);
    if (cachedLyrics != null) {
      print('✅ Using cached lyrics');
      return cachedLyrics;
    }

    // Priority 3: Fetch from LRCLIB
    final onlineLyrics = await fetchFromLRCLIB(
      title: title,
      artist: artist,
      album: album,
      durationSeconds: durationSeconds,
    );

    if (onlineLyrics != null) {
      // Cache it for offline use
      final lrcString = onlineLyrics.lines.map((line) => line.toString()).join('\n');
      await saveLRCFile(songId, lrcString);
      print('✅ Using online lyrics (cached for offline)');
      return onlineLyrics;
    }

    print('❌ No lyrics available');
    return null;
  }

  // Delete cached lyrics
  Future<void> deleteCachedLyrics(String songId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/lyrics/$songId.lrc');

      if (await file.exists()) {
        await file.delete();
        print('🗑️ Deleted cached lyrics for: $songId');
      }
    } catch (e) {
      print('❌ Error deleting lyrics: $e');
    }
  }
}
