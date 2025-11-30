import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import '../models/artist_model.dart';

class ArtistService {
  static const String _baseUrl = 'https://audio-x.onrender.com/api/artist';
  static const String _boxName = 'artists';

  Future<Box<Artist>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<Artist>(_boxName);
    }
    return Hive.box<Artist>(_boxName);
  }

  // Clean artist name for better search
  String _cleanArtistName(String name) {
    String cleaned = name;

    // Remove emojis
    cleaned = cleaned.replaceAll(RegExp(r'[🎧🎶🎵💿🔥✨⚡🌟💫🎤🎹🎸🎼🎙️]'), '');

    // Extract first artist if multiple
    if (cleaned.contains(',')) {
      cleaned = cleaned.split(',').first.trim();
    } else if (cleaned.contains('&')) {
      cleaned = cleaned.split('&').first.trim();
    } else if (cleaned.contains(' ft.') || cleaned.contains(' feat.')) {
      cleaned = cleaned.split(RegExp(r'\s+(ft\.|feat\.)', caseSensitive: false)).first.trim();
    }

    // Remove common suffixes
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+(Official|Music|Records|Entertainment|Studio|Server)$', caseSensitive: false),
      '',
    );

    // Clean whitespace
    cleaned = cleaned.trim().replaceAll(RegExp(r'\s+'), ' ');

    return cleaned;
  }

  Future<Artist?> getArtistInfo(String artistName, {bool fetchBio = false}) async {
    final box = await _getBox();
    final normalizedName = artistName.toLowerCase().trim();

    // Clean name for search
    String searchName = _cleanArtistName(artistName);
    if (searchName != artistName) {
      print('🧹 Cleaned: "$artistName" → "$searchName"');
    }

    // 1. Check Cache
    if (box.containsKey(normalizedName)) {
      final cachedArtist = box.get(normalizedName);
      if (cachedArtist != null && DateTime.now().difference(cachedArtist.lastUpdated).inDays < 7) {
        // If bio needed but not cached, fetch it
        if (fetchBio && (cachedArtist.biography == null || cachedArtist.biography!.isEmpty)) {
          print('📖 Cache exists but bio needed, fetching...');
          // Continue to fetch
        } else {
          print('📦 Using cache: $artistName');
          return cachedArtist;
        }
      }
    }

    // 2. Fetch from Backend
    try {
      print('🔍 Fetching: $searchName${fetchBio ? " (with bio)" : ""}');
      final response = await http.get(Uri.parse('$_baseUrl/$searchName'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['artist'] != null) {
          final artistData = data['artist'];

          String? imageUrl = artistData['image'];
          if (imageUrl != null && imageUrl.isNotEmpty) {
            print('✅ Spotify image');
          }

          List<String> tags = [];
          if (artistData['tags'] != null && artistData['tags'] is List) {
            tags = (artistData['tags'] as List).map<String>((t) => t.toString()).toList();
          }

          String? bio = artistData['biography'];
          if (bio != null && bio.isNotEmpty) {
            print('📖 Got biography');
          }

          // Parse stats
          int followers = artistData['followers'] ?? 0;
          int popularity = artistData['popularity'] ?? 0;
          if (followers > 0) {
            print('👥 Followers: ${_formatNumber(followers)}');
          }

          final artist = Artist(
            name: artistData['name'] ?? artistName,
            biography: bio,
            imageUrl: imageUrl,
            tags: tags,
            lastUpdated: DateTime.now(),
            followers: followers,
            popularity: popularity,
          );

          await box.put(normalizedName, artist);
          print('💾 Saved: $artistName');
          return artist;
        }
      }
    } catch (e) {
      print('❌ Error: $e');
    }

    // 3. Fallback
    return box.get(normalizedName);
  }

  Future<void> clearCache() async {
    final box = await _getBox();
    await box.clear();
    print('🗑️ Cache cleared');
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
