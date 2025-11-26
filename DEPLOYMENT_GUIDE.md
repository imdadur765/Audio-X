# 🚀 Spotify Artist Integration - Deployment Guide

## Overview
यह guide आपको step-by-step दिखाएगा कि कैसे backend deploy करें और Flutter app में integrate करें।

---

## 📋 Prerequisites Checklist

- [ ] Spotify Developer Account बनाया
- [ ] Client ID और Client Secret मिल गया
- [ ] GitHub account है
- [ ] Render account बनाया (free tier काफी है)
- [ ] Flutter project ready है

---

## Step 1: Spotify Developer Dashboard Setup

### 1.1 Developer Account Create करें
1. **Visit**: https://developer.spotify.com/dashboard
2. **Login** with your Spotify account (create one if needed)
3. **Accept** Terms of Service

### 1.2 Create App
1. Click **"Create app"**
2. Fill details:
   - **App name**: `Audio-X Artist Metadata`
   - **App description**: `Backend service to fetch artist metadata`
   - **Redirect URIs**: Leave empty (not needed for Client Credentials flow)
   - **APIs used**: Check "Web API"
3. Click **"Save"**

### 1.3 Get Credentials
1. Open your newly created app
2. Click **"Settings"**
3. आपको मिलेगा:
   - **Client ID** (copy करें)
   - **Client Secret** (View client secret पर click करके copy करें)

⚠️ **IMPORTANT**: इन credentials को कहीं safe note कर लें!

---

## Step 2: Backend Deployment on Render

### 2.1 Push Backend to GitHub

```bash
cd c:\audio_x

# Initialize git in backend folder (if not already)
cd backend
git init

# Add files
git add .
git commit -m "Initial backend setup"

# Create a new repository on GitHub named: audio-x-backend

# Push to GitHub
git remote add origin https://github.com/YOUR_USERNAME/audio-x-backend.git
git branch -M main
git push -u origin main
```

### 2.2 Deploy on Render (Method 1: Blueprint - Recommended)

#### Option A: One-Click Deploy
1. Go to: https://dashboard.render.com/
2. Click **"New +"** → **"Blueprint"**
3. Connect your GitHub account
4. Select your `audio-x-backend` repository
5. Render will automatically detect `render.json`
6. Click **"Apply"**

#### Add Environment Variables:
1. In Render dashboard, go to your service
2. Click **"Environment"** tab
3. Add these variables:
   - `SPOTIFY_CLIENT_ID` = (paste your Client ID)
   - `SPOTIFY_CLIENT_SECRET` = (paste your Client Secret)
   - `PORT` = `3000` (already set)
4. Click **"Save Changes"**

#### Wait for Deployment:
- Status देखें: "Deploy in progress..."
- 2-3 minutes में "Live" हो जाएगा
- **Copy your backend URL**: `https://audio-x-backend-xxxx.onrender.com`

### 2.3 Test Backend

अपने browser में जाएं:
```
https://your-backend-url.onrender.com/
```

आपको यह response दिखना चाहिए:
```json
{
  "status": "ok",
  "message": "Spotify Artist API Backend",
  "version": "1.0.0"
}
```

Test artist search:
```
https://your-backend-url.onrender.com/api/artist/search?name=Arijit Singh
```

✅ अगर artist data दिखा, तो backend working है!

---

## Step 3: Flutter App Integration

### 3.1 Update Backend URL

File: `c:\audio_x\lib\data\services\spotify_api_service.dart`

Find line 8 और update करें:
```dart
// BEFORE:
static const String _baseUrl = 'YOUR_RENDER_BACKEND_URL_HERE';

// AFTER:
static const String _baseUrl = 'https://your-actual-backend-url.onrender.com';
```

**Example**:
```dart
static const String _baseUrl = 'https://audio-x-backend-m3k9.onrender.com';
```

⚠️ **Important**: URL के end में `/` मत लगाओ!

### 3.2 Privacy Policy Update

अपनी app की privacy policy में यह add करें:

> **Third-Party Services**
> 
> This app uses Spotify Web API to fetch publicly available artist metadata such as profile images, follower counts, genres, and popularity scores. No copyrighted content is downloaded or streamed. All music playback is from local files on your device.
> 
> Artist metadata is powered by Spotify. For more information, see [Spotify's Privacy Policy](https://www.spotify.com/privacy).

### 3.3 Integration Example

अपने existing artist list से artist page open करने के लिए:

```dart
// Example: In your artists list screen
ListTile(
  title: Text(artistName),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArtistPage(
          artistName: artistName,
          localSongs: artistSongs, // Your local songs list
        ),
      ),
    );
  },
)
```

---

## Step 4: Testing

### 4.1 Test Online Mode
1. **Enable** internet connection
2. **Open** an artist from your local songs
3. **Verify**:
   - ✅ Artist profile image loads
   - ✅ Follower count shows
   - ✅ Genres display
   - ✅ Popularity bar appears
   - ✅ "Powered by Spotify" attribution visible

### 4.2 Test Offline Mode
1. **Disable** internet connection
2. **Open** an artist
3. **Verify**:
   - ✅ Artist name shows
   - ✅ Local song count correct
   - ✅ Songs list visible
   - ✅ "Offline mode" indicator appears
   - ✅ Play/Shuffle buttons work

### 4.3 Test Play Functionality
Currently, play buttons show snackbar messages. आपको integrate करना होगा अपने audio player के साथ:

1. Find `_playAll()` function in `artist_page.dart`
2. Replace with your player logic
3. Same for `_shuffleAll()` and `_playSong()`

---

## Step 5: Play Store Preparation

### 5.1 Required Actions

✅ **Privacy Policy** updated (see Step 3.2)
✅ **Spotify Attribution** already included in UI
✅ **No copyrighted content** downloaded
✅ **Offline functionality** works

### 5.2 App Description Template

```
Audio-X - Local Music Player with Artist Insights

FEATURES:
• Play local music files from your device
• Beautiful artist profiles powered by Spotify
• See artist follower counts, genres, and popularity
• Works offline - local music always accessible
• No ads, no subscriptions

SPOTIFY INTEGRATION:
This app fetches publicly available artist metadata from Spotify to enhance your local music experience. No music is streamed or downloaded from Spotify. All playback is from your local files.

PRIVACY:
Your music stays on your device. We only fetch public artist information when internet is available.
```

### 5.3 Final Checklist

- [ ] Backend deployed on Render (free tier)
- [ ] Environment variables set correctly
- [ ] Flutter app updated with backend URL
- [ ] Tested online mode
- [ ] Tested offline mode
- [ ] Privacy policy updated
- [ ] App description mentions Spotify
- [ ] Screenshots show attribution

---

## 🐛 Troubleshooting

### Issue: "Failed to search artist"
**Причина**: Backend unreachable या Spotify credentials wrong

**Solution**:
1. Check backend URL correct hai
2. Render dashboard में logs check करें
3. Environment variables verify करें

### Issue: "Rate limit exceeded"
**Причина**: Too many requests (100/15min limit hit)

**Solution**:
- Wait 15 minutes
- Backend automatically caches responses
- Users won't hit this normally

### Issue: Images not loading
**Причина**: No internet or Spotify returned no images

**Solution**:
- Check internet connection
- Placeholder image automatically shows
- Offline mode works without images

### Issue: Artist not found
**Причина**: Artist spelling mismatch या niche artist

**Solution**:
- App shows local data anyway
- Try exact artist name
- Some local artists may not be on Spotify

---

## 📱 Integration with Your Audio Player

Replace TODOs in `artist_page.dart`:

```dart
void _playAll(List<Song> songs) {
  // Your audio player integration
  // Example:
  final audioService = Provider.of<AudioService>(context, listen: false);
  audioService.setPlaylist(songs);
  audioService.play(0);
}

void _shuffleAll(List<Song> songs) {
  // Shuffle and play
  final shuffled = List<Song>.from(songs)..shuffle();
  final audioService = Provider.of<AudioService>(context, listen: false);
  audioService.setPlaylist(shuffled);
  audioService.play(0);
}

void _playSong(List<Song> songs, int index) {
  // Play specific song
  final audioService = Provider.of<AudioService>(context, listen: false);
  audioService.setPlaylist(songs);
  audioService.play(index);
}
```

---

## 🎉 Success!

अगर सब steps follow किए, तो आपका app:

✅ Spotify से artist metadata fetch करता है  
✅ Security best practices follow करता है  
✅ Offline mode में काम करता है  
✅ Play Store safe है  
✅ Backend Render पर free में hosted है  

**Questions?** Check backend logs on Render dashboard या artist controller error messages.

---

## 📞 Support

- **Backend logs**: Render Dashboard → Your Service → Logs
- **Flutter errors**: Check console output
- **Spotify API**: https://developer.spotify.com/documentation/web-api
