import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import '../models/artist_model.dart';

class ArtistService {
  // Use the deployed backend URL
  static const String _baseUrl = 'https://audio-x.onrender.com/api/artist';
  static const String _boxName = 'artists';

  Future<Box<Artist>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<Artist>(_boxName);
    }
    return Hive.box<Artist>(_boxName);
  }

  Future<Artist?> getArtistInfo(String artistName) async {
    final box = await _getBox();
    final normalizedName = artistName.toLowerCase().trim();

    // 1. Check Cache
    if (box.containsKey(normalizedName)) {
      final cachedArtist = box.get(normalizedName);
      // Optional: Check if data is stale (e.g., older than 7 days)
      if (cachedArtist != null && DateTime.now().difference(cachedArtist.lastUpdated).inDays < 7) {
        return cachedArtist;
      }
    }

    // 2. Fetch from Backend Proxy
    try {
      final response = await http.get(Uri.parse('$_baseUrl/$artistName'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['artist'] != null) {
          final artistData = data['artist'];

          // Extract Image (usually 'large' or 'extralarge')
          String? imageUrl;
          final List<dynamic> images = artistData['image'] ?? [];
          for (var img in images) {
            if (img['size'] == 'extralarge' || img['size'] == 'large') {
              imageUrl = img['#text'];
            }
          }

          // Extract Tags
          List<String> tags = [];
          if (artistData['tags'] != null && artistData['tags']['tag'] != null) {
            final tagList = artistData['tags']['tag'];
            if (tagList is List) {
              tags = tagList.map<String>((t) => t['name'].toString()).toList();
            }
          }

          // Extract Bio
          String? bio;
          if (artistData['bio'] != null) {
            bio = artistData['bio']['summary']; // 'content' has HTML, 'summary' is safer
          }

          final artist = Artist(
            name: artistData['name'] ?? artistName,
            biography: bio,
            imageUrl: imageUrl,
            tags: tags,
            lastUpdated: DateTime.now(),
          );

          // 3. Save to Cache
          await box.put(normalizedName, artist);
          return artist;
        }
      }
    } catch (e) {
      print('Error fetching artist info: $e');
    }

    // 4. Fallback: Return cached version even if stale, or null
    return box.get(normalizedName);
  }
}
