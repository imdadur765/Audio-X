import 'dart:convert';
import 'package:http/http.dart' as http;

class ITunesService {
  static const String _baseUrl = 'https://itunes.apple.com/search';

  Future<Map<String, dynamic>?> fetchAlbumDetails(String albumName, String artistName) async {
    try {
      final query = '$albumName $artistName';
      final url = Uri.parse('$_baseUrl?term=${Uri.encodeComponent(query)}&entity=album&limit=1');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['resultCount'] > 0) {
          return data['results'][0] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('Error fetching iTunes data: $e');
      return null;
    }
  }

  static Future<String?> fetchArtwork(String query, {int retries = 3}) async {
    try {
      final url = Uri.parse('$_baseUrl?term=${Uri.encodeComponent(query)}&entity=song&limit=1');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['resultCount'] > 0) {
          String artworkUrl = data['results'][0]['artworkUrl100'];
          return artworkUrl.replaceAll('100x100bb', '1000x1000bb');
        }
      }
    } catch (e) {
      print('Error fetching artwork: $e');
    }
    return null;
  }
}
