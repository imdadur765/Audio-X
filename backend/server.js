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
  // Return cached token if still valid
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
    tokenExpiry = Date.now() + (response.data.expires_in * 1000) - 60000; // Expire 1 min early
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

// NEW: Get Artist Info (Spotify Image + Last.fm Bio)
app.get('/api/artist/:name', async (req, res) => {
  try {
    const artistName = req.params.name;
    const result = {
      name: artistName,
      image: null,
      biography: null,
      tags: [],
      spotifyId: null
    };

    // 1. Get Image from Spotify
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
        result.name = artist.name; // Use Spotify's corrected name

        // Get largest image
        if (artist.images && artist.images.length > 0) {
          result.image = artist.images[0].url; // First image is usually largest
        }

        // Get genres as tags
        if (artist.genres && artist.genres.length > 0) {
          result.tags = artist.genres;
        }
      }
    } catch (spotifyError) {
      console.error('Spotify error:', spotifyError.message);
      // Continue to Last.fm even if Spotify fails
    }

    // 2. Get Biography from Last.fm (optional, only if needed)
    if (LASTFM_API_KEY) {
      try {
        const lastfmResponse = await axios.get(LASTFM_BASE_URL, {
          params: {
            method: 'artist.getinfo',
            artist: artistName,
            api_key: LASTFM_API_KEY,
            format: 'json'
          }
        });

        if (lastfmResponse.data.artist) {
          const lastfmArtist = lastfmResponse.data.artist;

          // Get biography
          if (lastfmArtist.bio && lastfmArtist.bio.summary) {
            result.biography = lastfmArtist.bio.summary;
          }

          // Add Last.fm tags if no Spotify genres
          if (result.tags.length === 0 && lastfmArtist.tags && lastfmArtist.tags.tag) {
            const tagList = lastfmArtist.tags.tag;
            if (Array.isArray(tagList)) {
              result.tags = tagList.slice(0, 5).map(t => t.name);
            }
          }
        }
      } catch (lastfmError) {
        console.error('Last.fm error:', lastfmError.message);
        // Continue even if Last.fm fails
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
