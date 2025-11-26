import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audio_x/data/models/spotify_artist_model.dart';

class SpotifyApiService {
  // TODO: Update this after Render deployment!
  // Use 10.0.2.2 for Android Emulator to access host localhost
  static const String _baseUrl = 'http://10.0.2.2:3000';
  static const Duration _timeout = Duration(seconds: 5);

  /// Search for artists by name
  Future<List<SpotifyArtistModel>> searchArtist(String name) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/artist/search?name=${Uri.encodeComponent(name)}'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => SpotifyArtistModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load artists: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching artist: $e');
      return [];
    }
  }

  /// Get the best matching artist (exact match preferred)
  Future<SpotifyArtistModel?> getBestMatchingArtist(String name) async {
    try {
      final artists = await searchArtist(name);
      if (artists.isEmpty) return null;

      // Try to find exact match (case-insensitive)
      final exactMatch = artists.firstWhere(
        (artist) => artist.name.toLowerCase() == name.toLowerCase(),
        orElse: () => artists.first, // Fallback to first result (most popular)
      );

      return exactMatch;
    } catch (e) {
      print('Error getting best matching artist: $e');
      return null;
    }
  }

  /// Get detailed artist info by Spotify ID
  Future<SpotifyArtistModel?> getArtistById(String id) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/artist/$id')).timeout(_timeout);

      if (response.statusCode == 200) {
        return SpotifyArtistModel.fromJson(json.decode(response.body));
      } else {
        return null;
      }
    } catch (e) {
      print('Error getting artist by ID: $e');
      return null;
    }
  }

  /// Check if backend is reachable
  Future<bool> isBackendReachable() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/health')).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
