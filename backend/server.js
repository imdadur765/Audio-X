const express = require('express');
const SpotifyWebApi = require('spotify-web-api-node');
const cors = require('cors');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Spotify API setup
const spotifyApi = new SpotifyWebApi({
  clientId: process.env.SPOTIFY_CLIENT_ID,
  clientSecret: process.env.SPOTIFY_CLIENT_SECRET
});

// Health check
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'I Music Backend is running! 🎵',
    timestamp: new Date().toISOString(),
    version: '2.0.0'
  });
});

// Get Spotify access token
app.get('/api/token', async (req, res) => {
  try {
    const data = await spotifyApi.clientCredentialsGrant();

    res.json({
      success: true,
      access_token: data.body['access_token'],
      expires_in: data.body['expires_in']
    });
  } catch (error) {
    console.error('Token error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get Spotify token'
    });
  }
});

// Search songs
app.get('/api/search/songs', async (req, res) => {
  try {
    const { q: query, limit = 20 } = req.query;

    if (!query || query.trim() === '') {
      return res.status(400).json({
        success: false,
        error: 'Query parameter is required'
      });
    }

    console.log('Searching songs for:', query);

    // Get access token first
    const tokenData = await spotifyApi.clientCredentialsGrant();
    spotifyApi.setAccessToken(tokenData.body['access_token']);

    // Search tracks
    const searchData = await spotifyApi.searchTracks(query, {
      limit: parseInt(limit)
    });

    // Format response for Flutter app
    const tracks = searchData.body.tracks.items.map(track => ({
      id: track.id,
      name: track.name,
      artists: track.artists.map(artist => ({
        id: artist.id,
        name: artist.name
      })),
      album: {
        id: track.album.id,
        name: track.album.name,
        images: track.album.images
      },
      duration_ms: track.duration_ms,
      preview_url: track.preview_url,
      external_urls: track.external_urls,
      popularity: track.popularity
    }));

    res.json({
      success: true,
      query: query,
      total_results: searchData.body.tracks.total,
      tracks: tracks
    });
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({
      success: false,
      error: 'Search failed',
      message: error.message
    });
  }
});

// Search artists
app.get('/api/search/artists', async (req, res) => {
  try {
    const { q: query, limit = 20 } = req.query;

    if (!query || query.trim() === '') {
      return res.status(400).json({
        success: false,
        error: 'Query parameter is required'
      });
    }

    console.log('Searching artists for:', query);

    const tokenData = await spotifyApi.clientCredentialsGrant();
    spotifyApi.setAccessToken(tokenData.body['access_token']);

    const searchData = await spotifyApi.searchArtists(query, {
      limit: parseInt(limit)
    });

    const artists = searchData.body.artists.items.map(artist => ({
      id: artist.id,
      name: artist.name,
      images: artist.images,
      popularity: artist.popularity,
      followers: artist.followers?.total || 0,
      genres: artist.genres
    }));

    res.json({
      success: true,
      query: query,
      total_results: searchData.body.artists.total,
      artists: artists
    });
  } catch (error) {
    console.error('Artist search error:', error);
    res.status(500).json({
      success: false,
      error: 'Artist search failed'
    });
  }
});

// Get artist details
app.get('/api/artists/:id', async (req, res) => {
  try {
    const { id } = req.params;

    if (!id) {
      return res.status(400).json({
        success: false,
        error: 'Artist ID is required'
      });
    }

    const tokenData = await spotifyApi.clientCredentialsGrant();
    spotifyApi.setAccessToken(tokenData.body['access_token']);

    const artistData = await spotifyApi.getArtist(id);

    res.json({
      success: true,
      artist: {
        id: artistData.body.id,
        name: artistData.body.name,
        images: artistData.body.images,
        popularity: artistData.body.popularity,
        followers: artistData.body.followers?.total || 0,
        genres: artistData.body.genres
      }
    });
  } catch (error) {
    console.error('Get artist error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get artist details'
    });
  }
});

// Get artist's top tracks
app.get('/api/artists/:id/top-tracks', async (req, res) => {
  try {
    const { id } = req.params;
    const { market = 'IN' } = req.query;

    if (!id) {
      return res.status(400).json({
        success: false,
        error: 'Artist ID is required'
      });
    }

    const tokenData = await spotifyApi.clientCredentialsGrant();
    spotifyApi.setAccessToken(tokenData.body['access_token']);

    const tracksData = await spotifyApi.getArtistTopTracks(id, market);

    const tracks = tracksData.body.tracks.map(track => ({
      id: track.id,
      name: track.name,
      artists: track.artists.map(artist => ({
        id: artist.id,
        name: artist.name
      })),
      album: {
        id: track.album.id,
        name: track.album.name,
        images: track.album.images
      },
      duration_ms: track.duration_ms,
      preview_url: track.preview_url,
      popularity: track.popularity
    }));

    res.json({
      success: true,
      tracks: tracks
    });
  } catch (error) {
    console.error('Top tracks error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get top tracks'
    });
  }
});

// Get track details
app.get('/api/tracks/:id', async (req, res) => {
  try {
    const { id } = req.params;

    if (!id) {
      return res.status(400).json({
        success: false,
        error: 'Track ID is required'
      });
    }

    const tokenData = await spotifyApi.clientCredentialsGrant();
    spotifyApi.setAccessToken(tokenData.body['access_token']);

    const trackData = await spotifyApi.getTrack(id);

    res.json({
      success: true,
      track: trackData.body
    });
  } catch (error) {
    console.error('Get track error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get track details'
    });
  }
});

// Get recommendations
app.get('/api/recommendations', async (req, res) => {
  try {
    const { seed_tracks, seed_artists, limit = 10 } = req.query;

    if (!seed_tracks && !seed_artists) {
      return res.status(400).json({
        success: false,
        error: 'Seed tracks or artists are required'
      });
    }

    const tokenData = await spotifyApi.clientCredentialsGrant();
    spotifyApi.setAccessToken(tokenData.body['access_token']);

    const recData = await spotifyApi.getRecommendations({
      seed_tracks: seed_tracks ? seed_tracks.split(',') : [],
      seed_artists: seed_artists ? seed_artists.split(',') : [],
      limit: parseInt(limit)
    });

    const tracks = recData.body.tracks.map(track => ({
      id: track.id,
      name: track.name,
      artists: track.artists.map(artist => ({
        id: artist.id,
        name: artist.name
      })),
      album: {
        id: track.album.id,
        name: track.album.name,
        images: track.album.images
      },
      duration_ms: track.duration_ms,
      preview_url: track.preview_url,
      popularity: track.popularity
    }));

    res.json({
      success: true,
      tracks: tracks
    });
  } catch (error) {
    console.error('Recommendations error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get recommendations'
    });
  }
});

// ================== NEW ENDPOINTS ==================

// Batch process multiple artists at once - FAST
app.post('/api/artists/batch', async (req, res) => {
  try {
    const { artistNames } = req.body;

    if (!artistNames || !Array.isArray(artistNames)) {
      return res.status(400).json({
        success: false,
        error: 'Artist names array is required'
      });
    }

    console.log(`🎯 Batch processing ${artistNames.length} artists`);

    const tokenData = await spotifyApi.clientCredentialsGrant();
    spotifyApi.setAccessToken(tokenData.body['access_token']);

    const batchResults = [];

    // Process in batches of 5 to avoid rate limiting
    for (let i = 0; i < artistNames.length; i += 5) {
      const batch = artistNames.slice(i, i + 5);
      const batchPromises = batch.map(artistName =>
        spotifyApi.searchArtists(artistName, { limit: 1 })
          .then(searchData => ({
            localName: artistName,
            spotifyArtist: searchData.body.artists.items.length > 0 ? {
              id: searchData.body.artists.items[0].id,
              name: searchData.body.artists.items[0].name,
              images: searchData.body.artists.items[0].images,
              popularity: searchData.body.artists.items[0].popularity,
              followers: searchData.body.artists.items[0].followers?.total || 0,
              genres: searchData.body.artists.items[0].genres
            } : null
          }))
          .catch(error => ({
            localName: artistName,
            spotifyArtist: null
          }))
      );

      const batchResult = await Promise.all(batchPromises);
      batchResults.push(...batchResult);

      // Small delay to avoid rate limiting
      if (i + 5 < artistNames.length) {
        await new Promise(resolve => setTimeout(resolve, 200));
      }
    }

    res.json({
      success: true,
      artists: batchResults
    });
  } catch (error) {
    console.error('Batch artists error:', error);
    res.status(500).json({
      success: false,
      error: 'Batch processing failed'
    });
  }
});

// Get artist data for local songs
app.get('/api/artists-from-local', async (req, res) => {
  try {
    const { artistNames } = req.query;

    if (!artistNames) {
      return res.status(400).json({
        success: false,
        error: 'Artist names are required'
      });
    }

    const names = artistNames.split(',');
    const tokenData = await spotifyApi.clientCredentialsGrant();
    spotifyApi.setAccessToken(tokenData.body['access_token']);

    const artistsData = [];

    for (const artistName of names) {
      try {
        const searchData = await spotifyApi.searchArtists(artistName, { limit: 1 });

        if (searchData.body.artists.items.length > 0) {
          const spotifyArtist = searchData.body.artists.items[0];
          artistsData.push({
            localName: artistName,
            spotifyArtist: {
              id: spotifyArtist.id,
              name: spotifyArtist.name,
              images: spotifyArtist.images,
              popularity: spotifyArtist.popularity,
              followers: spotifyArtist.followers?.total || 0,
              genres: spotifyArtist.genres
            }
          });
        } else {
          artistsData.push({
            localName: artistName,
            spotifyArtist: null
          });
        }
      } catch (error) {
        artistsData.push({
          localName: artistName,
          spotifyArtist: null
        });
      }
    }

    res.json({
      success: true,
      artists: artistsData
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Failed to fetch artists data'
    });
  }
});

// ================== SERVER START ==================

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🎵 I Music Backend running on port ${PORT}`);
  console.log(`🚀 Server: http://localhost:${PORT}`);
});
