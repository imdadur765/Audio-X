import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LastFmService {
  // Replace with a valid API Key
  static const String _apiKey = '2c223c6a4618e47087679ad369242d59';
  final String _baseUrl = 'http://ws.audioscrobbler.com/2.0/';

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
      final url = Uri.parse('$_baseUrl?method=track.getInfo&api_key=$_apiKey&artist=$artist&track=$track&format=json');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Cache cacheable data
        if (data['track'] != null) {
          await prefs.setString(cacheKey, response.body);
          return data;
        }
      }
    } catch (e) {
      print('Error fetching Last.fm track info: $e');
    }
    return null;
  }
}
