import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audio_x/data/models/spotify_artist_model.dart';
import 'package:audio_x/data/models/spotify_song_model.dart';

class SpotifyApiService {
  // TODO: Update this after Render deployment!
  // Use 10.0.2.2 for Android Emulator to access host localhost
  static const String _baseUrl = 'https://audio-x.onrender.com';
  static const Duration _timeout = Duration(seconds: 20);

  /// Search for artists by name
  Future<List<SpotifyArtistModel>> searchArtist(String name) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/artist/search?name=${Uri.encodeComponent(name)}'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final dynamic decodedResponse = json.decode(response.body);
        List<dynamic> data;

        if (decodedResponse is List) {
          data = decodedResponse;
        } else if (decodedResponse is Map<String, dynamic>) {
          // Handle wrapped response (e.g. { "data": [...] } or { "artists": [...] })
          if (decodedResponse.containsKey('data') && decodedResponse['data'] is List) {
            data = decodedResponse['data'];
          } else if (decodedResponse.containsKey('artists') && decodedResponse['artists'] is List) {
            data = decodedResponse['artists'];
          } else {
            // Fallback: treat as single result or empty
            print('Unexpected JSON format: $decodedResponse');
            return [];
          }
        } else {
          return [];
        }

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

  /// Get batch artists data - NEW METHOD
  Future<List<Map<String, dynamic>>> getBatchArtistsData(List<String> artistNames) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/artists/batch'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'artistNames': artistNames}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['artists'] is List) {
          return List<Map<String, dynamic>>.from(data['artists']);
        } else {
          throw Exception('Invalid batch response format');
        }
      } else if (response.statusCode == 429) {
        // Rate limited
        print('⚠️ Rate limited - retry after ${response.headers['retry-after']} seconds');
        return artistNames.map((name) => {'localName': name, 'spotifyArtist': null}).toList();
      } else {
        throw Exception('Batch request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Batch artists error: $e');
      // Return empty results for all artists on error
      return artistNames.map((name) => {'localName': name, 'spotifyArtist': null}).toList();
    }
  }

  /// Health check
  Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/health')).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Search songs
  Future<List<SpotifySongModel>> searchSongs(String query, {int limit = 20}) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/search/songs?q=${Uri.encodeComponent(query)}&limit=$limit'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> tracksData = data['tracks'];
          return tracksData.map((trackData) => SpotifySongModel.fromJson(trackData)).toList();
        } else {
          throw Exception('Backend error: ${data['error']}');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching songs: $e');
      return [];
    }
  }

  /// Get artist's top tracks
  Future<List<SpotifySongModel>> getArtistTopTracks(String artistId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/artist/$artistId/top-tracks?market=IN'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> tracksData = data['tracks'];
          return tracksData.map((trackData) => SpotifySongModel.fromJson(trackData)).toList();
        } else {
          throw Exception('Backend error: ${data['error']}');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting top tracks: $e');
      return [];
    }
  }

  /// Get track details
  Future<SpotifySongModel?> getTrack(String trackId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/track/$trackId')).timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return SpotifySongModel.fromJson(data['track']);
        }
      }
      return null;
    } catch (e) {
      print('Error getting track: $e');
      return null;
    }
  }

  /// Get recommendations
  Future<List<SpotifySongModel>> getRecommendations({String? seedTracks, String? seedArtists, int limit = 10}) async {
    try {
      final params = <String, String>{'limit': limit.toString()};
      if (seedTracks != null) params['seed_tracks'] = seedTracks;
      if (seedArtists != null) params['seed_artists'] = seedArtists;

      final uri = Uri.parse('$_baseUrl/api/recommendations').replace(queryParameters: params);
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> tracksData = data['tracks'];
          return tracksData.map((trackData) => SpotifySongModel.fromJson(trackData)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getting recommendations: $e');
      return [];
    }
  }

  /// Enhance local songs with Spotify metadata
  Future<List<Map<String, dynamic>>> enhanceLocalSongsMetadata(List<Map<String, dynamic>> localSongs) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/songs/enhance'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'songs': localSongs}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['enhancedSongs']);
        }
      }
      return [];
    } catch (e) {
      print('Error enhancing metadata: $e');
      return [];
    }
  }

  /// Get artists data from local artist names
  Future<List<Map<String, dynamic>>> getArtistsDataFromLocal(List<String> artistNames) async {
    try {
      final namesParam = artistNames.join(',');
      final response = await http
          .get(Uri.parse('$_baseUrl/api/artists/from-local?artistNames=${Uri.encodeComponent(namesParam)}'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['artists']);
        }
      }
      return [];
    } catch (e) {
      print('Error getting artists from local: $e');
      return [];
    }
  }
}
