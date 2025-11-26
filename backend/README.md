# Audio-X Spotify Backend API

Backend service for fetching Spotify artist metadata securely.

## 🚀 Features

- ✅ Spotify Artist Search
- ✅ Artist Details Fetch
- ✅ Client Credentials Flow (Secure)
- ✅ Response Caching (5 minutes)
- ✅ Rate Limiting (100 req/15 min)
- ✅ CORS Enabled
- ✅ Ready for Render Deployment

## 📋 Prerequisites

1. **Spotify Developer Account**
   - Go to: https://developer.spotify.com/dashboard
   - Create a new app
   - Get your `Client ID` and `Client Secret`

## 🛠️ Local Setup

### 1. Install Dependencies
```bash
cd backend
npm install
```

### 2. Configure Environment Variables
```bash
# Copy example file
cp .env.example .env

# Edit .env and add your Spotify credentials:
SPOTIFY_CLIENT_ID=your_actual_client_id
SPOTIFY_CLIENT_SECRET=your_actual_client_secret
PORT=3000
```

### 3. Run Locally
```bash
# Development mode with auto-reload
npm run dev

# Production mode
npm start
```

Server will run at: `http://localhost:3000`

## 🌐 Deploy to Render

### Method 1: One-Click Deploy (Recommended)

1. Push this `backend/` folder to a GitHub repository
2. Go to [Render Dashboard](https://dashboard.render.com/)
3. Click "New +" → "Blueprint"
4. Connect your GitHub repository
5. Render will read `render.json` automatically
6. Add environment variables:
   - `SPOTIFY_CLIENT_ID`: Your Spotify Client ID
   - `SPOTIFY_CLIENT_SECRET`: Your Spotify Client Secret
7. Click "Apply" and wait for deployment

### Method 2: Manual Deploy

1. Go to [Render Dashboard](https://dashboard.render.com/)
2. Click "New +" → "Web Service"
3. Connect your GitHub repository
4. Configure:
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Environment**: Node
5. Add environment variables (same as above)
6. Click "Create Web Service"

### Get Your Backend URL
After deployment, Render will give you a URL like:
```
https://audio-x-spotify-api.onrender.com
```

**⚠️ Important**: Copy this URL, you'll need it in your Flutter app!

## 📡 API Endpoints

### 1. Health Check
```
GET /
```

Response:
```json
{
  "status": "ok",
  "message": "Spotify Artist API Backend",
  "version": "1.0.0"
}
```

### 2. Search Artist
```
GET /api/artist/search?name=<artist_name>
```

Example:
```bash
curl "https://your-backend-url.onrender.com/api/artist/search?name=Arijit%20Singh"
```

Response:
```json
{
  "artists": [
    {
      "id": "4YRxDV8wJFPHPTeXepOstw",
      "name": "Arijit Singh",
      "imageUrl": "https://i.scdn.co/image/...",
      "images": [...],
      "followers": 15234567,
      "genres": ["filmi", "modern bollywood"],
      "popularity": 85,
      "externalUrl": "https://open.spotify.com/artist/..."
    }
  ],
  "cached": false
}
```

### 3. Get Artist Details
```
GET /api/artist/:id
```

Example:
```bash
curl "https://your-backend-url.onrender.com/api/artist/4YRxDV8wJFPHPTeXepOstw"
```

Response: Same as individual artist object above

## 🔒 Security Features

- ✅ API credentials stored server-side only
- ✅ Rate limiting prevents abuse
- ✅ CORS configured for your Flutter app
- ✅ HTTPS automatic on Render
- ✅ No sensitive data in frontend

## 🐛 Troubleshooting

### "Spotify authentication failed"
- Check if `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET` are correct
- Verify environment variables are set on Render

### "Too many requests"
- You've hit the rate limit (100 req/15 min)
- Wait 15 minutes or implement request queuing

### Cache Issues
Clear cache by hitting:
```bash
POST /api/cache/clear
```

## 📱 Integration with Flutter

Update your Flutter app's API service:
```dart
class SpotifyApiService {
  static const String baseUrl = 'https://your-backend-url.onrender.com';
  
  // Your API calls here...
}
```

## 📄 License

MIT
