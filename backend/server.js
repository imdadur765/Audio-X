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

// Track credits cache to prevent 429 rate limits
const trackCreditsCache = new Map();
const CACHE_DURATION = 24 * 60 * 60 * 1000; // 24 hours

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
              let similarArtists = similarList.slice(0, 5).map(a => ({
                name: a.name,
                image: a.image && a.image.length > 0 ? a.image[a.image.length - 1]['#text'] : null
              }));

              // Enrich with Spotify Images
              try {
                // Ensure we have a valid token (reuse the one from earlier if possible, or get new)
                const token = await getSpotifyToken();

                const imagePromises = similarArtists.map(async (artist) => {
                  try {
                    const searchRes = await axios.get(`${SPOTIFY_API_URL}/search`, {
                      params: { q: artist.name, type: 'artist', limit: 1 },
                      headers: { 'Authorization': `Bearer ${token}` }
                    });
                    if (searchRes.data.artists.items.length > 0) {
                      const spotArtist = searchRes.data.artists.items[0];
                      if (spotArtist.images && spotArtist.images.length > 0) {
                        return { ...artist, image: spotArtist.images[0].url };
                      }
                    }
                  } catch (e) {
                    // Ignore error, keep Last.fm image
                  }
                  return artist;
                });

                result.similarArtists = await Promise.all(imagePromises);
              } catch (e) {
                console.error("Error enriching similar artists:", e.message);
                result.similarArtists = similarArtists;
              }
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


// Get Track Info (Credits, Wiki)
app.get('/api/track', async (req, res) => {
  try {
    const { artist, track } = req.query;

    if (!artist || !track) {
      return res.status(400).json({ error: 'Artist and track parameters are required' });
    }

    if (!LASTFM_API_KEY) {
      return res.status(503).json({ error: 'Last.fm API key not configured' });
    }

    const response = await axios.get(LASTFM_BASE_URL, {
      params: {
        method: 'track.getInfo',
        artist: artist,
        track: track,
        api_key: LASTFM_API_KEY,
        format: 'json'
      }
    });

    if (response.data.track) {
      res.json(response.data.track);
    } else {
      res.status(404).json({ error: 'Track not found' });
    }

  } catch (error) {
    console.error('Error fetching track info:', error.message);
    res.status(500).json({ error: 'Failed to fetch track info' });
  }
});

// Get Spotify Track Credits (with aggressive caching to avoid 429)
app.get('/api/spotify/trackinfo', async (req, res) => {
  try {
    const { artist, track } = req.query;

    if (!artist || !track) {
      return res.status(400).json({ error: 'Artist and track parameters are required' });
    }

    // Check cache first
    const cacheKey = `${artist.toLowerCase()}_${track.toLowerCase()}`;
    const cached = trackCreditsCache.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp < CACHE_DURATION)) {
      return res.json(cached.data);
    }

    const token = await getSpotifyToken();

    // Search for track
    const searchResponse = await axios.get(`${SPOTIFY_API_URL}/search`, {
      params: {
        q: `artist:${artist} track:${track}`,
        type: 'track',
        limit: 1
      },
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (!searchResponse.data.tracks.items.length) {
      return res.status(404).json({ error: 'Track not found' });
    }

    const trackData = searchResponse.data.tracks.items[0];
    const albumId = trackData.album.id;

    // Get album details for additional info
    const albumResponse = await axios.get(`${SPOTIFY_API_URL}/albums/${albumId}`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    // Extract credits
    const credits = {
      title: trackData.name,
      artist: trackData.artists.map(a => a.name).join(', '),
      album: trackData.album.name,
      releaseDate: trackData.album.release_date,
      popularity: trackData.popularity,
      label: albumResponse.data.label || 'Unknown',
      copyrights: albumResponse.data.copyrights || [],
      performers: trackData.artists.map(a => a.name),
      writer: trackData.artists[0]?.name || artist,
      producer: albumResponse.data.label || 'Unknown'
    };

    // Cache the result
    trackCreditsCache.set(cacheKey, {
      data: credits,
      timestamp: Date.now()
    });

    res.json(credits);

  } catch (error) {
    console.error('Error fetching Spotify track info:', error.message);
    if (error.response?.status === 429) {
      res.status(429).json({ error: 'Rate limit exceeded, please try again later' });
    } else {
      res.status(500).json({ error: 'Failed to fetch track info from Spotify' });
    }
  }
});


app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
