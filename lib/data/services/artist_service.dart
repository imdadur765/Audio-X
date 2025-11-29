// ignore_for_file: avoid_print

import 'package:audio_x/data/models/artist_model.dart';
import 'package:audio_x/data/models/song_model.dart';
import 'package:audio_x/data/services/spotify_api_service.dart';

class ArtistService {
  final bool _useSpotify = true;
  final SpotifyApiService _spotifyService = SpotifyApiService();

  Future<List<Artist>> getArtists({String searchQuery = ''}) async {
    try {
      if (!_useSpotify) {
        return _getDemoArtists(searchQuery);
      }

      if (searchQuery.isNotEmpty) {
        final artists = await _spotifyService.searchArtist(searchQuery);
        if (artists.isNotEmpty) {
          // Convert SpotifyArtistModel to Artist
          return artists
              .map(
                (a) => Artist(
                  id: a.id,
                  name: a.name,
                  imageUrl: a.imageUrl,
                  songsCount: 0,
                  followers: a.getFormattedFollowers(),
                  popularSongs: [],
                  popularity: a.popularity,
                  genres: a.genres,
                ),
              )
              .toList();
        }
      } else {
        return await _getPopularArtists();
      }

      return _getDemoArtists(searchQuery);
    } catch (e) {
      print('Error getting artists: $e');
      return _getDemoArtists(searchQuery);
    }
  }

  Future<List<Artist>> _getPopularArtists() async {
    try {
      // Search for 'a' to get popular artists (common Spotify trick)
      final popularArtists = await _spotifyService.searchArtist('a');

      if (popularArtists.isNotEmpty) {
        popularArtists.sort((a, b) => b.popularity.compareTo(a.popularity));
        return popularArtists
            .take(20)
            .map(
              (a) => Artist(
                id: a.id,
                name: a.name,
                imageUrl: a.imageUrl,
                songsCount: 0,
                followers: a.getFormattedFollowers(),
                popularSongs: [],
                popularity: a.popularity,
                genres: a.genres,
              ),
            )
            .toList();
      }

      return _getDemoArtists('');
    } catch (e) {
      return _getDemoArtists('');
    }
  }

  Future<Artist> getArtistDetails(String artistId) async {
    try {
      if (_useSpotify) {
        final artist = await _spotifyService.getArtistById(artistId);
        final topTracks = await _spotifyService.getArtistTopTracks(artistId);

        if (artist == null) return _getDemoArtists('').first;

        // Convert SpotifySongModel to Song
        // Note: Song model in this project expects int duration (ms) and uri
        final List<Song> convertedSongs = topTracks.map((spotifySong) {
          return Song(
            id: spotifySong.id,
            title: spotifySong.title,
            artist: spotifySong.artist,
            album: spotifySong.album,
            uri: spotifySong.previewUrl ?? '', // Use preview URL or empty
            duration: spotifySong.duration,
            artworkUri: spotifySong.artworkUrl,
          );
        }).toList();

        return Artist(
          id: artist.id,
          name: artist.name,
          imageUrl: artist.imageUrl,
          songsCount: convertedSongs.length,
          followers: artist.getFormattedFollowers(),
          popularSongs: convertedSongs,
          popularity: artist.popularity,
          genres: artist.genres,
        );
      } else {
        return _getDemoArtists('').first;
      }
    } catch (e) {
      return _getDemoArtists('').first;
    }
  }

  Future<List<Song>> getArtistSongs(String artistId, String artistName) async {
    try {
      if (_useSpotify) {
        final topTracks = await _spotifyService.getArtistTopTracks(artistId);

        return topTracks.map((spotifySong) {
          return Song(
            id: spotifySong.id,
            title: spotifySong.title,
            artist: spotifySong.artist,
            album: spotifySong.album,
            uri: spotifySong.previewUrl ?? '',
            duration: spotifySong.duration,
            artworkUri: spotifySong.artworkUrl,
          );
        }).toList();
      } else {
        return _getDemoSongs(artistName);
      }
    } catch (e) {
      return _getDemoSongs(artistName);
    }
  }

  // Demo data as fallback
  List<Artist> _getDemoArtists(String searchQuery) {
    final demoArtists = [
      Artist(
        id: '1',
        name: 'Arijit Singh',
        imageUrl: 'https://c.saavncdn.com/artists/Arijit_Singh_00220221018091134_500x500.jpg',
        songsCount: 150,
        followers: '35.2M',
        popularSongs: _getDemoSongs('Arijit Singh'),
        popularity: 95,
        genres: ['Bollywood', 'Romantic'],
      ),
      // ... (other demo artists can be added here)
    ];

    if (searchQuery.isNotEmpty) {
      return demoArtists.where((artist) => artist.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
    }

    return demoArtists;
  }

  List<Song> _getDemoSongs(String artistName) {
    return [
      Song(
        id: '1',
        title: 'Popular Song 1',
        artist: artistName,
        album: 'Demo Album',
        uri: '',
        duration: 225000, // 3:45
        artworkUri: '',
      ),
    ];
  }
}
