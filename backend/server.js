const express = require('express');
const cors = require('cors');
const axios = require('axios');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// API Keys
const LASTFM_API_KEY = process.env.LASTFM_API_KEY;
const SPOTIFY_CLIENT_ID = process.env.SPOTIFY_CLIENT_ID;
const SPOTIFY_CLIENT_SECRET = process.env.SPOTIFY_CLIENT_SECRET;

// API Base URLs
const LASTFM_BASE_URL = 'http://ws.audioscrobbler.com/2.0/';
const SPOTIFY_TOKEN_URL = 'https://accounts.spotify.com/api/token';
const SPOTIFY_API_URL = 'https://api.spotify.com/v1';

app.use(cors());
app.use(express.json());

// Spotify Token Cache
let spotifyToken = null;
let tokenExpiry = 0;

// Get Spotify Access Token
async function getSpotifyToken() {
  if (spotifyToken && Date.now() < tokenExpiry) {
    return spotifyToken;
  }

  try {
    const response = await axios.post(
      SPOTIFY_TOKEN_URL,
      'grant_type=client_credentials',
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic ' + Buffer.from(SPOTIFY_CLIENT_ID + ':' + SPOTIFY_CLIENT_SECRET).toString('base64')
        }
      }
    );

    spotifyToken = response.data.access_token;
    tokenExpiry = Date.now() + (response.data.expires_in * 1000) - 60000;
    return spotifyToken;
  } catch (error) {
    console.error('Error getting Spotify token:', error.message);
    throw error;
  }
}

// Health Check
app.get('/', (req, res) => {
  res.send('Audio X Backend is running');
});

// Get Artist Info with Stats
app.get('/api/artist/:name', async (req, res) => {
  try {
    const artistName = req.params.name;
    const result = {
      name: artistName,
      image: null,
      biography: null,
      tags: [],
      spotifyId: null,
      followers: 0,
      popularity: 0,
      similarArtists: [],
      topAlbums: []
    };

    // 1. Get data from Spotify
    try {
      const token = await getSpotifyToken();
      const spotifyResponse = await axios.get(`${SPOTIFY_API_URL}/search`, {
        params: {
          q: artistName,
          type: 'artist',
          limit: 1
        },
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });

      if (spotifyResponse.data.artists.items.length > 0) {
        const artist = spotifyResponse.data.artists.items[0];
        result.spotifyId = artist.id;
        result.name = artist.name;

        // Image
        if (artist.images && artist.images.length > 0) {
          result.image = artist.images[0].url;
        }

        // Genres/Tags
        if (artist.genres && artist.genres.length > 0) {
          result.tags = artist.genres;
        }

        // Stats
        result.followers = artist.followers?.total || 0;
        result.popularity = artist.popularity || 0;
      }
    } catch (spotifyError) {
      console.error('Spotify error:', spotifyError.message);
    }

    // 2. Get Biography, Similar Artists, and Top Albums from Last.fm
    if (LASTFM_API_KEY) {
      try {
        // Fetch Artist Info (Bio, Tags, Similar)
        const lastfmInfoResponse = await axios.get(LASTFM_BASE_URL, {
          params: {
            method: 'artist.getinfo',
            artist: artistName,
            api_key: LASTFM_API_KEY,
            format: 'json'
          }
        });

        if (lastfmInfoResponse.data.artist) {
          const lastfmArtist = lastfmInfoResponse.data.artist;

          // Bio
          if (lastfmArtist.bio && lastfmArtist.bio.summary) {
            result.biography = lastfmArtist.bio.summary;
          }

          // Tags (Fallback or Enrichment)
          if (result.tags.length === 0 && lastfmArtist.tags && lastfmArtist.tags.tag) {
            const tagList = lastfmArtist.tags.tag;
            if (Array.isArray(tagList)) {
              result.tags = tagList.slice(0, 5).map(t => t.name);
            }
          }

          // Similar Artists
          if (lastfmArtist.similar && lastfmArtist.similar.artist) {
            const similarList = lastfmArtist.similar.artist;
            if (Array.isArray(similarList)) {
              result.similarArtists = similarList.slice(0, 5).map(a => ({
                name: a.name,
                image: a.image && a.image.length > 0 ? a.image[a.image.length - 1]['#text'] : null
              }));
            }
          }
        }

        // Fetch Top Albums
        const lastfmAlbumsResponse = await axios.get(LASTFM_BASE_URL, {
          params: {
            method: 'artist.gettopalbums',
            artist: artistName,
            api_key: LASTFM_API_KEY,
            format: 'json',
            limit: 5
          }
        });

        if (lastfmAlbumsResponse.data.topalbums && lastfmAlbumsResponse.data.topalbums.album) {
          const albumList = lastfmAlbumsResponse.data.topalbums.album;
          if (Array.isArray(albumList)) {
            result.topAlbums = albumList.map(a => ({
              name: a.name,
              image: a.image && a.image.length > 0 ? a.image[a.image.length - 1]['#text'] : null
            }));
          }
        }

      } catch (lastfmError) {
        console.error('Last.fm error:', lastfmError.message);
      }
    }

    res.json({ artist: result });
  } catch (error) {
    console.error('Error fetching artist info:', error.message);
    res.status(500).json({ error: 'Failed to fetch artist info', message: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
