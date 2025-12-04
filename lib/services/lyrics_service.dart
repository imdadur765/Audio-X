import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../data/models/lyrics_model.dart';

class LyricsService {
  static const String _baseUrl = 'https://lrclib.net/api';
  static const Duration _timeout = Duration(seconds: 10);

  // Fetch lyrics from LRCLIB API with FAST parallel search
  Future<Lyrics?> fetchFromLRCLIB({
    required String title,
    required String artist,
    String? album,
    int? durationSeconds,
  }) async {
    try {
      print('🚀 Starting FAST parallel lyrics search...');

      // Phase 1: Run multiple strategies in parallel
      final List<Future<Lyrics?>> parallelSearches = [];

      if (album != null && album.isNotEmpty) {
        parallelSearches.add(
          _performSearch(
            queryParams: {'track_name': title, 'artist_name': artist, 'album_name': album},
            targetDuration: durationSeconds,
            strategyName: 'Album+Artist+Track',
          ),
        );
      }

      parallelSearches.add(
        _performSearch(
          queryParams: {'track_name': title, 'artist_name': artist},
          targetDuration: durationSeconds,
          strategyName: 'Artist+Track',
        ),
      );

      parallelSearches.add(
        _performSearch(
          queryParams: {'q': '$title $artist'},
          targetDuration: durationSeconds,
          strategyName: 'General Query',
        ),
      );

      parallelSearches.add(
        _performSearch(
          queryParams: {'track_name': title},
          targetDuration: durationSeconds,
          filterArtist: artist,
          strategyName: 'Track Only',
        ),
      );

      // Wait for all parallel searches
      final results = await Future.wait(parallelSearches);

      // Return first successful result
      for (var result in results) {
        if (result != null) return result;
      }

      // Phase 2: If all failed, try cleaned metadata (also in parallel)
      final cleanTitle = _cleanString(title);
      final cleanArtist = _cleanString(artist);

      if (cleanTitle != title || cleanArtist != artist) {
        print('🔄 Trying cleaned metadata...');

        final cleanedResults = await Future.wait([
          _performSearch(
            queryParams: {'track_name': cleanTitle, 'artist_name': cleanArtist},
            targetDuration: durationSeconds,
            strategyName: 'Cleaned',
          ),
          _performSearch(
            queryParams: {'q': '$cleanTitle $cleanArtist'},
            targetDuration: durationSeconds,
            strategyName: 'Cleaned Query',
          ),
        ]);

        for (var result in cleanedResults) {
          if (result != null) return result;
        }
      }

      print('❌ No lyrics found');
      return null;
    } catch (e) {
      print('❌ Error: $e');
      return null;
    }
  }

  Future<Lyrics?> _performSearch({
    required Map<String, String> queryParams,
    int? targetDuration,
    String? filterArtist,
    String? strategyName,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: queryParams);

      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);

        if (results.isEmpty) return null;

        // Filter and Find Best Match
        dynamic bestMatch;
        double bestScore = -1;

        for (var item in results) {
          double score = 0;

          // 1. Artist Match Check (Critical if filterArtist is provided)
          if (filterArtist != null) {
            final itemArtist = item['artistName'] as String? ?? '';
            if (!_isFuzzyMatch(filterArtist, itemArtist)) {
              continue;
            }
            score += 10;
          }

          // 2. Duration Match (High Priority)
          final itemDuration = item['duration'] as double?;
          if (targetDuration != null && itemDuration != null) {
            final diff = (itemDuration - targetDuration).abs();
            if (diff <= 2) {
              score += 20;
            } else if (diff <= 5) {
              score += 10;
            } else {
              if (filterArtist == null) score -= 10;
            }
          }

          // 3. Synced Lyrics Preference
          if (item['syncedLyrics'] != null && (item['syncedLyrics'] as String).isNotEmpty) {
            score += 5;
          }

          if (score > bestScore) {
            bestScore = score;
            bestMatch = item;
          }
        }

        if (bestMatch != null && bestScore >= 0) {
          final strategy = strategyName != null ? '[$strategyName] ' : '';
          print(
            '✅ ${strategy}Match found: ${bestMatch['trackName']} by ${bestMatch['artistName']} (Score: $bestScore)',
          );
          return Lyrics.fromLRCLIB(bestMatch);
        }
      }
      return null;
    } catch (e) {
      print('⚠️ Search attempt failed: $e');
      return null;
    }
  }

  bool _isFuzzyMatch(String s1, String s2) {
    final n1 = _normalize(s1);
    final n2 = _normalize(s2);
    return n1.contains(n2) || n2.contains(n1);
  }

  String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _cleanString(String input) {
    var cleaned = input.replaceAll(RegExp(r'[\(\[].*?[\)\]]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b(feat|ft|live|remastered|mix|edit)\b.*', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\s]'), '');
    return cleaned.trim();
  }

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

  Future<Lyrics?> getLyrics({
    required String songId,
    required String title,
    required String artist,
    String? album,
    int? durationSeconds,
    String? manualLyricsPath,
  }) async {
    if (manualLyricsPath != null) {
      final lyrics = await loadFromPath(manualLyricsPath);
      if (lyrics != null) {
        print('✅ Using manual lyrics');
        return lyrics;
      }
    }

    final cachedLyrics = await loadLocalLRC(songId);
    if (cachedLyrics != null) {
      print('✅ Using cached lyrics');
      return cachedLyrics;
    }

    final onlineLyrics = await fetchFromLRCLIB(
      title: title,
      artist: artist,
      album: album,
      durationSeconds: durationSeconds,
    );

    if (onlineLyrics != null) {
      final lrcString = onlineLyrics.lines.map((line) => line.toString()).join('\n');
      await saveLRCFile(songId, lrcString);
      print('✅ Using online lyrics (cached for offline)');
      return onlineLyrics;
    }

    print('❌ No lyrics available');
    return null;
  }

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
