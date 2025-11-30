const express = require('express');
const cors = require('cors');
const axios = require('axios');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;
const LASTFM_API_KEY = process.env.LASTFM_API_KEY;
const LASTFM_BASE_URL = 'http://ws.audioscrobbler.com/2.0/';

app.use(cors());
app.use(express.json());

// Health Check
app.get('/', (req, res) => {
  res.send('Audio X Backend is running');
});

// Get Artist Info
app.get('/api/artist/:name', async (req, res) => {
  try {
    const artistName = req.params.name;
    if (!LASTFM_API_KEY) {
      return res.status(500).json({ error: 'LASTFM_API_KEY is not configured' });
    }

    const response = await axios.get(LASTFM_BASE_URL, {
      params: {
        method: 'artist.getinfo',
        artist: artistName,
        api_key: LASTFM_API_KEY,
        format: 'json'
      }
    });

    res.json(response.data);
  } catch (error) {
    console.error('Error fetching artist info:', error.message);
    res.status(500).json({ error: 'Failed to fetch artist info' });
  }
});

// Search Artists
app.get('/api/search/artist/:query', async (req, res) => {
  try {
    const query = req.params.query;
    if (!LASTFM_API_KEY) {
      return res.status(500).json({ error: 'LASTFM_API_KEY is not configured' });
    }

    const response = await axios.get(LASTFM_BASE_URL, {
      params: {
        method: 'artist.search',
        artist: query,
        api_key: LASTFM_API_KEY,
        format: 'json'
      }
    });

    res.json(response.data);
  } catch (error) {
    console.error('Error searching artists:', error.message);
    res.status(500).json({ error: 'Failed to search artists' });
  }
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
