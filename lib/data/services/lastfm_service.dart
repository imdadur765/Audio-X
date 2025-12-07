import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LastFmService {
  final String _baseUrl = 'https://audio-x.onrender.com/api/spotify/trackinfo';

  Future<Map<String, dynamic>?> getTrackInfo(String artist, String track) async {
    final cacheKey = 'track_credits_${artist.toLowerCase()}_${track.toLowerCase()}';

    // Check Cache
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(cacheKey)) {
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        return json.decode(cached);
      }
    }

    try {
      final url = Uri.parse('$_baseUrl?artist=${Uri.encodeComponent(artist)}&track=${Uri.encodeComponent(track)}');
      print('Fetching credits from: $url');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Credits response: $data');

        // Cache the result
        await prefs.setString(cacheKey, response.body);

        // Wrap in 'track' structure for compatibility
        return {'track': data};
      } else if (response.statusCode == 429) {
        print('Rate limit hit, using cache if available');
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching track credits: $e');
    }
    return null;
  }
}
