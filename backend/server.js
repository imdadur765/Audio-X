const express = require('express');
const axios = require('axios');
const cors = require('cors');
const NodeCache = require('node-cache');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Cache: 5 minutes TTL
const cache = new NodeCache({ stdTTL: 300 });

// Middleware
app.use(cors());
app.use(express.json());

// Rate limiting map (simple in-memory)
const rateLimitMap = new Map();
const RATE_LIMIT_WINDOW = 15 * 60 * 1000; // 15 minutes
const MAX_REQUESTS = 100;

// Rate limiting middleware
const rateLimit = (req, res, next) => {
  const ip = req.ip;
  const now = Date.now();
  
  if (!rateLimitMap.has(ip)) {
    rateLimitMap.set(ip, []);
  }
  
  const requests = rateLimitMap.get(ip).filter(time => now - time < RATE_LIMIT_WINDOW);
  
  if (requests.length >= MAX_REQUESTS) {
    return res.status(429).json({ 
      error: 'Too many requests, please try again later',
      retryAfter: RATE_LIMIT_WINDOW / 1000 
    });
  }
  
  requests.push(now);
  rateLimitMap.set(ip, requests);
  next();
};

// Spotify Access Token Management
let spotifyAccessToken = null;
let tokenExpiresAt = 0;

const getSpotifyAccessToken = async () => {
  // Return cached token if still valid
  if (spotifyAccessToken && Date.now() < tokenExpiresAt) {
    return spotifyAccessToken;
  }

  try {
    const clientId = process.env.SPOTIFY_CLIENT_ID;
    const clientSecret = process.env.SPOTIFY_CLIENT_SECRET;

    if (!clientId || !clientSecret) {
      throw new Error('Spotify credentials not configured');
    }

    const response = await axios.post(
      'https://accounts.spotify.com/api/token',
      'grant_type=client_credentials',
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic ' + Buffer.from(clientId + ':' + clientSecret).toString('base64')
        }
      }
    );

    spotifyAccessToken = response.data.access_token;
    // Set expiry 1 minute before actual expiry for safety
    tokenExpiresAt = Date.now() + (response.data.expires_in - 60) * 1000;
    
    return spotifyAccessToken;
  } catch (error) {
    console.error('Error getting Spotify access token:', error.response?.data || error.message);
    throw new Error('Failed to authenticate with Spotify');
  }
};

// Health check endpoint
app.get('/', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'Spotify Artist API Backend',
    version: '1.0.0'
  });
});

// Search artist by name
app.get('/api/artist/search', rateLimit, async (req, res) => {
  try {
    const { name } = req.query;

    if (!name || name.trim().length === 0) {
      return res.status(400).json({ error: 'Artist name is required' });
    }

    // Check cache
    const cacheKey = `search:${name.toLowerCase()}`;
    const cachedData = cache.get(cacheKey);
    if (cachedData) {
      return res.json({ ...cachedData, cached: true });
    }

    const token = await getSpotifyAccessToken();

    const response = await axios.get('https://api.spotify.com/v1/search', {
      headers: {
        'Authorization': `Bearer ${token}`
      },
      params: {
        q: name,
        type: 'artist',
        limit: 5
      }
    });

    const artists = response.data.artists.items.map(artist => ({
      id: artist.id,
      name: artist.name,
      imageUrl: artist.images[0]?.url || null,
      images: artist.images,
      followers: artist.followers.total,
      genres: artist.genres,
      popularity: artist.popularity,
      externalUrl: artist.external_urls.spotify
    }));

    const result = { artists };
    
    // Cache the result
    cache.set(cacheKey, result);

    res.json(result);
  } catch (error) {
    console.error('Error searching artist:', error.response?.data || error.message);
    
    if (error.response?.status === 401) {
      return res.status(401).json({ error: 'Spotify authentication failed' });
    }
    
    res.status(500).json({ 
      error: 'Failed to search artist',
      message: error.message 
    });
  }
});

// Get artist details by ID
app.get('/api/artist/:id', rateLimit, async (req, res) => {
  try {
    const { id } = req.params;

    if (!id) {
      return res.status(400).json({ error: 'Artist ID is required' });
    }

    // Check cache
    const cacheKey = `artist:${id}`;
    const cachedData = cache.get(cacheKey);
    if (cachedData) {
      return res.json({ ...cachedData, cached: true });
    }

    const token = await getSpotifyAccessToken();

    const response = await axios.get(`https://api.spotify.com/v1/artists/${id}`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    const artist = {
      id: response.data.id,
      name: response.data.name,
      imageUrl: response.data.images[0]?.url || null,
      images: response.data.images,
      followers: response.data.followers.total,
      genres: response.data.genres,
      popularity: response.data.popularity,
      externalUrl: response.data.external_urls.spotify
    };

    // Cache the result
    cache.set(cacheKey, artist);

    res.json(artist);
  } catch (error) {
    console.error('Error getting artist details:', error.response?.data || error.message);
    
    if (error.response?.status === 404) {
      return res.status(404).json({ error: 'Artist not found' });
    }
    
    if (error.response?.status === 401) {
      return res.status(401).json({ error: 'Spotify authentication failed' });
    }
    
    res.status(500).json({ 
      error: 'Failed to get artist details',
      message: error.message 
    });
  }
});

// Clear cache endpoint (optional, for debugging)
app.post('/api/cache/clear', (req, res) => {
  cache.flushAll();
  res.json({ message: 'Cache cleared successfully' });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📡 Endpoints:`);
  console.log(`   GET  /api/artist/search?name=<artist_name>`);
  console.log(`   GET  /api/artist/:id`);
});

module.exports = app;
