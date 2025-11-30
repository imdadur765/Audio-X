import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import '../models/artist_model.dart';

class ArtistService {
  // Use the deployed backend URL
  static const String _baseUrl = 'https://audio-x.onrender.com/api/artist';
  static const String _boxName = 'artists';

  // Last.fm's default placeholder image hash (the star icon)
  static const String _placeholderHash = '2a96cbd8b46e442fc41c2b86b821562f';

  Future<Box<Artist>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<Artist>(_boxName);
    }
    return Hive.box<Artist>(_boxName);
  }

  Future<Artist?> getArtistInfo(String artistName) async {
    final box = await _getBox();
    final normalizedName = artistName.toLowerCase().trim();

    // Extract first artist if multiple artists (separated by comma)
    String searchName = artistName;
    if (artistName.contains(',')) {
      searchName = artistName.split(',').first.trim();
      print('🎯 Multi-artist detected: "$artistName" → Searching for: "$searchName"');
    }

    // 1. Check Cache - but force refresh for now to test backend
    if (box.containsKey(normalizedName)) {
      final cachedArtist = box.get(normalizedName);
      // Reduced cache time to 1 day for testing
      if (cachedArtist != null && DateTime.now().difference(cachedArtist.lastUpdated).inDays < 1) {
        print('📦 Using cached data for: $artistName');
        return cachedArtist;
      } else {
        print('🔄 Cache expired for: $artistName, fetching fresh data');
      }
    }

    // 2. Fetch from Backend Proxy
    try {
      print('🔍 Fetching artist: $searchName from $_baseUrl/$searchName');
      final response = await http.get(Uri.parse('$_baseUrl/$searchName'));
      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 Response data keys: ${data.keys}');
        if (data['artist'] != null) {
          final artistData = data['artist'];
          print('🎨 Artist data found for: ${artistData['name']}');

          // Extract Image (skip Last.fm placeholder)
          String? imageUrl;
          final List<dynamic> images = artistData['image'] ?? [];
          print('🖼️ Found ${images.length} images');

          // Try extralarge first
          for (var img in images) {
            final url = img['#text']?.toString() ?? '';
            if (img['size'] == 'extralarge' && url.isNotEmpty && !url.contains(_placeholderHash)) {
              imageUrl = url;
              print('✅ Selected extralarge image: $imageUrl');
              break;
            }
          }

          // If no extralarge, try large
          if (imageUrl == null) {
            for (var img in images) {
              final url = img['#text']?.toString() ?? '';
              if (img['size'] == 'large' && url.isNotEmpty && !url.contains(_placeholderHash)) {
                imageUrl = url;
                print('✅ Selected large image: $imageUrl');
                break;
              }
            }
          }

          // If still no image, try any non-placeholder image
          if (imageUrl == null) {
            for (var img in images) {
              final url = img['#text']?.toString() ?? '';
              if (url.isNotEmpty && !url.contains(_placeholderHash)) {
                imageUrl = url;
                print('✅ Selected fallback image (${img['size']}): $imageUrl');
                break;
              }
            }
          }

          if (imageUrl == null || imageUrl.contains(_placeholderHash)) {
            print('❌ No real image found (only placeholder available)');
            imageUrl = null; // Set to null so UI shows person icon
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
          print('💾 Saved fresh data for: $artistName');
          return artist;
        } else {
          print('⚠️ No artist key in response for: $artistName');
        }
      } else {
        print('⚠️ Bad response status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching artist info: $e');
    }

    // 4. Fallback: Return cached version even if stale, or null
    final fallback = box.get(normalizedName);
    if (fallback != null) {
      print('📦 Returning stale cache as fallback for: $artistName');
    }
    return fallback;
  }

  // Helper method to clear cache (for testing)
  Future<void> clearCache() async {
    final box = await _getBox();
    await box.clear();
    print('🗑️ Artist cache cleared');
  }
}
