import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LastFmService {
  // Replace with a valid API Key
  final String _baseUrl = 'http://10.0.2.2:3000/api/track'; // Android emulator localhost

  Future<Map<String, dynamic>?> getTrackInfo(String artist, String track) async {
    final cacheKey = 'lastfm_track_${artist.toLowerCase()}_${track.toLowerCase()}';

    // Check Cache
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(cacheKey)) {
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        return json.decode(cached);
      }
    }

    try {
      final url = Uri.parse('$_baseUrl?artist=$artist&track=$track');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Cache cacheable data
        if (data['wiki'] != null || data['writer'] != null || data['album'] != null) {
          await prefs.setString(cacheKey, response.body);
          // Backend returns the 'track' object directly, so wrap it to match expectations if needed
          // But our backend returns res.json(response.data.track) which IS the track object.
          // The UI expects nested data potentially? Let's check.
          // Client code: trackInfo['track']['wiki'] -> implies it expects { track: { ... } } structure.
          // BUT my backend returns `response.data.track` directly.
          // So the structure will be { name: ..., wiki: ..., ... }
          // I should probably wrap it here to minimize client changes or update client.
          // Let's wrap it to maintain { track: ... } structure for now to break less code.
          return {'track': data};
        }
      }
    } catch (e) {
      print('Error fetching Last.fm track info: $e');
    }
    return null;
  }
}
