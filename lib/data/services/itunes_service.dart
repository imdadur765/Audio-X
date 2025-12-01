import 'dart:convert';
import 'package:http/http.dart' as http;

class ITunesService {
  static const String _baseUrl = 'https://itunes.apple.com/search';
  static const Duration _timeout = Duration(seconds: 5);

  Future<String?> fetchArtwork(String query, {int retries = 1}) async {
    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        final response = await http
            .get(Uri.parse('$_baseUrl?term=${Uri.encodeComponent(query)}&entity=album&limit=1'))
            .timeout(_timeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['resultCount'] > 0) {
            String artworkUrl = data['results'][0]['artworkUrl100'];
            // Get high resolution image
            return artworkUrl.replaceAll('100x100', '1000x1000');
          }
        }
        // If we got a valid response but no results, don't retry
        return null;
      } catch (e) {
        if (attempt == retries) {
          // Only log on final failure
          print('Error fetching iTunes artwork after $retries retries: $e');
          return null;
        }
        // Small delay before retry
        await Future.delayed(Duration(milliseconds: 200));
      }
    }
    return null;
  }
}
