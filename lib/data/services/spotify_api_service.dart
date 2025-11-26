import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:audio_x/data/models/spotify_artist_model.dart';

class SpotifyApiService {
  // TODO: Replace with your actual Render backend URL after deployment
  static const String _baseUrl = 'YOUR_RENDER_BACKEND_URL_HERE';

  // Example: 'https://audio-x-spotify-api.onrender.com'

  static const Duration _timeout = Duration(seconds: 10);

  /// Search for artist by name
  /// Returns list of matching artists from Spotify
  Future<List<SpotifyArtistModel>> searchArtist(String artistName) async {
    try {
      if (artistName.trim().isEmpty) {
        throw Exception('Artist name cannot be empty');
      }

      // Check internet connectivity
      if (!await _hasInternetConnection()) {
        throw Exception('No internet connection');
      }

      final uri = Uri.parse('$_baseUrl/api/artist/search').replace(queryParameters: {'name': artistName.trim()});

      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final artistsData = data['artists'] as List<dynamic>;

        return artistsData.map((json) => SpotifyArtistModel.fromJson(json as Map<String, dynamic>)).toList();
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again later.');
      } else if (response.statusCode == 404) {
        return []; // No artists found
      } else {
        throw Exception('Failed to search artist: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Check your internet connection.');
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      rethrow;
    }
  }

  /// Get best matching artist for local artist name
  /// Uses fuzzy matching to find the most relevant result
  Future<SpotifyArtistModel?> getBestMatchingArtist(String artistName) async {
    try {
      final results = await searchArtist(artistName);

      if (results.isEmpty) {
        return null;
      }

      // Return exact match if found
      final exactMatch = results.firstWhere(
        (artist) => artist.name.toLowerCase() == artistName.toLowerCase(),
        orElse: () => results.first, // Return most popular if no exact match
      );

      return exactMatch;
    } catch (e) {
      return null; // Return null on error (offline fallback will handle this)
    }
  }

  /// Get artist details by Spotify ID
  Future<SpotifyArtistModel> getArtistById(String artistId) async {
    try {
      if (artistId.trim().isEmpty) {
        throw Exception('Artist ID cannot be empty');
      }

      if (!await _hasInternetConnection()) {
        throw Exception('No internet connection');
      }

      final uri = Uri.parse('$_baseUrl/api/artist/$artistId');

      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SpotifyArtistModel.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('Artist not found');
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again later.');
      } else {
        throw Exception('Failed to get artist: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Check your internet connection.');
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      rethrow;
    }
  }

  /// Check if device has internet connection
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Check if backend is reachable
  Future<bool> isBackendReachable() async {
    try {
      final uri = Uri.parse('$_baseUrl/');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
