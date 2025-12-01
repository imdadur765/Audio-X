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

  Future<void> openBox() async {
    await _getBox();
  }

  Artist? getCachedArtist(String artistName) {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final box = Hive.box<Artist>(_boxName);
    final normalizedName = artistName.toLowerCase().trim();
    return box.get(normalizedName);
  }

  Future<Artist?> getArtistInfo(String artistName, {bool fetchBio = false}) async {
    final box = await _getBox();
    final normalizedName = artistName.toLowerCase().trim();

    // Clean name for search
    String searchName = _cleanArtistName(artistName);

    // 1. Check Cache
    if (box.containsKey(normalizedName)) {
      final cachedArtist = box.get(normalizedName);
      if (cachedArtist != null && DateTime.now().difference(cachedArtist.lastUpdated).inDays < 7) {
        // If bio needed but not cached, fetch it
        if (fetchBio && (cachedArtist.biography == null || cachedArtist.biography!.isEmpty)) {
          // Continue to fetch
        } else {
          return cachedArtist;
        }
      }
    }

    // 2. Fetch from Backend
    try {
      final response = await http.get(Uri.parse('$_baseUrl/$searchName'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['artist'] != null) {
          final artistData = data['artist'];

          String? imageUrl = artistData['image'];
          List<String> tags = [];
          if (artistData['tags'] != null && artistData['tags'] is List) {
            tags = (artistData['tags'] as List).map<String>((t) => t.toString()).toList();
          }

          String? bio = artistData['biography'];
          int followers = artistData['followers'] ?? 0;
          int popularity = artistData['popularity'] ?? 0;

          List<Map<String, String>> similarArtists = [];
          if (artistData['similarArtists'] != null) {
            similarArtists = (artistData['similarArtists'] as List).map<Map<String, String>>((item) {
              return {'name': item['name']?.toString() ?? '', 'image': item['image']?.toString() ?? ''};
            }).toList();
          }

          List<Map<String, String>> topAlbums = [];
          if (artistData['topAlbums'] != null) {
            topAlbums = (artistData['topAlbums'] as List).map<Map<String, String>>((item) {
              return {'name': item['name']?.toString() ?? '', 'image': item['image']?.toString() ?? ''};
            }).toList();
          }

          final artist = Artist(
            name: artistData['name'] ?? artistName,
            biography: bio,
            imageUrl: imageUrl,
            tags: tags,
            lastUpdated: DateTime.now(),
            followers: followers,
            popularity: popularity,
            similarArtists: similarArtists,
            topAlbums: topAlbums,
          );

          await box.put(normalizedName, artist);
          return artist;
        }
      }
    } catch (e) {
      // Error handling
    }

    // 3. Fallback
    return box.get(normalizedName);
  }

  Future<void> clearCache() async {
    final box = await _getBox();
    await box.clear();
  }
}
