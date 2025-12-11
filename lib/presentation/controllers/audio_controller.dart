import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/song_model.dart';
import '../../services/audio_handler.dart';
import '../../data/services/itunes_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../core/utils/color_utils.dart';
import '../../services/cloud_sync_service.dart';

class AudioController extends ChangeNotifier with WidgetsBindingObserver {
  final AudioHandler _audioHandler = AudioHandler();
  List<Song> _songs = [];
  List<Song> _queue = []; // Current playing queue
  bool _isPlaying = false;
  Song? _currentSong;
  Timer? _progressTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isShuffleEnabled = false;
  int _repeatMode = 0; // 0: Off, 1: One, 2: All
  double _volume = 1.0;
  double _speed = 1.0;
  bool _hasCountedPlay = false; // Track if current song play has been counted
  Color _accentColor = Colors.deepPurple;

  List<Song> get songs => _songs;
  List<Song> get queue => _queue;
  bool get isPlaying => _isPlaying;
  Song? get currentSong => _currentSong;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isShuffleEnabled => _isShuffleEnabled;
  int get repeatMode => _repeatMode;
  double get volume => _volume;
  double get speed => _speed;
  Color get accentColor => _accentColor;
  List<Song> get allSongs => _songs; // Access to all songs for playlists

  AudioController() {
    WidgetsBinding.instance.addObserver(this);

    // Listen for stop events from notification
    _audioHandler.onStoppedCallback = () {
      stop();
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App going to background - save state and stop timer
      _saveState();
      _stopProgressTimer();
    } else if (state == AppLifecycleState.resumed) {
      // App resumed - check for stop marker file first
      await _checkStopMarker();

      // Only restart timer if still playing after marker check
      if (_isPlaying) {
        _startProgressTimer();
      }
    }
  }

  /// Check if playback was stopped from notification while app was in background
  Future<void> _checkStopMarker() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final markerFile = File('${directory.parent.path}/files/playback_stopped.marker');

      if (await markerFile.exists()) {
        await markerFile.delete();

        // Clear playback state
        _isPlaying = false;
        _currentSong = null;
        _position = Duration.zero;
        _duration = Duration.zero;
        _stopProgressTimer();

        // Clear saved session
        final settingsBox = Hive.box('settings');
        await settingsBox.delete('lastPlayedSongId');
        await settingsBox.delete('lastPosition');

        notifyListeners();
      }
    } catch (e) {
      print('⚠️ Error checking stop marker: $e');
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      final pos = await _audioHandler.getPosition();

      // Check for auto-song change
      final currentIndex = await _audioHandler.getCurrentMediaItemIndex();
      if (currentIndex != -1 && currentIndex < _queue.length) {
        final playingSong = _queue[currentIndex];
        if (_currentSong?.id != playingSong.id) {
          _currentSong = playingSong;
          _hasCountedPlay = false;
          _duration = Duration(milliseconds: playingSong.duration);
          // Save new state immediately
          await _saveState();
          _updatePalette(playingSong.localArtworkPath);
        }
      }

      if (_currentSong != null) {
        _duration = Duration(milliseconds: _currentSong!.duration);

        // Check if we should increment play count
        if (!_hasCountedPlay && _duration.inSeconds > 0) {
          // Count if played > 30 seconds OR > 50% of duration (for short songs)
          final threshold = _duration.inSeconds < 60 ? _duration.inSeconds * 0.5 : 30.0;

          if (pos.inSeconds >= threshold) {
            _hasCountedPlay = true;
            incrementPlayCount(_currentSong!);
          }
        }
      }
      _position = pos;
      notifyListeners();
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
  }

  Future<void> loadSongs({bool restoreSession = true}) async {
    // Check permissions
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    // Also check for audio permission on Android 13+
    var audioStatus = await Permission.audio.status;
    if (!audioStatus.isGranted) {
      audioStatus = await Permission.audio.request();
    }

    if (status.isGranted || audioStatus.isGranted) {
      final songsData = await _audioHandler.getSongs();
      final box = Hive.box<Song>('songs');

      // Create a map of existing songs to preserve user data
      final Map<String, Song> existingSongs = {};
      for (var song in box.values) {
        existingSongs[song.id] = song;
      }

      // Clear box to remove deleted songs
      await box.clear();

      for (var data in songsData) {
        final id = data['id'].toString();
        final existing = existingSongs[id];

        final song = Song(
          id: id,
          title: data['title'].toString(),
          artist: data['artist'].toString(),
          album: data['album'].toString(),
          uri: data['uri'].toString(),
          duration: int.tryParse(data['duration'].toString()) ?? 0,
          artworkUri: data['artworkUri']?.toString(),
          dateAdded: int.tryParse(data['dateAdded'].toString()) ?? 0,
          // Preserve user data if exists
          isFavorite: existing?.isFavorite ?? false,
          playCount: existing?.playCount ?? 0,
          lyricsPath: existing?.lyricsPath,
          lyricsSource: existing?.lyricsSource,
          localArtworkPath: existing?.localArtworkPath,
        );
        box.add(song);
      }

      _songs = box.values.toList();
      _queue = List.from(_songs); // Default queue is all songs
      notifyListeners();

      // Restore session only if requested
      if (restoreSession) {
        await _restoreSession();
      }

      // Cache artwork in background
      _cacheArtwork();
    }
  }

  Future<void> _restoreSession() async {
    // Check for stop marker file (created when user closes from notification)
    try {
      final directory = await getApplicationDocumentsDirectory();
      final markerFile = File('${directory.parent.path}/files/playback_stopped.marker');

      if (await markerFile.exists()) {
        await markerFile.delete();

        // Clear session
        final settingsBox = Hive.box('settings');
        await settingsBox.delete('lastPlayedSongId');
        await settingsBox.delete('lastPosition');

        return;
      }
    } catch (e) {
      print('⚠️ Error checking stop marker: $e');
    }

    final settingsBox = Hive.box('settings');
    final lastSongId = settingsBox.get('lastPlayedSongId');
    final lastPosition = settingsBox.get('lastPosition') as int? ?? 0;
    final shuffleMode = settingsBox.get('shuffleMode') as bool? ?? false;
    final repeatMode = settingsBox.get('repeatMode') as int? ?? 0;
    final volume = settingsBox.get('volume') as double? ?? 1.0;
    final speed = settingsBox.get('speed') as double? ?? 1.0;
    _isCrossfadeEnabled = settingsBox.get('crossfade', defaultValue: false);

    // Restore playback settings
    _isShuffleEnabled = shuffleMode;
    _repeatMode = repeatMode;
    _volume = volume;
    _speed = speed;

    await _audioHandler.setShuffleMode(shuffleMode);
    await _audioHandler.setRepeatMode(repeatMode);
    await _audioHandler.setVolume(volume);
    await _audioHandler.setSpeed(speed);

    if (lastSongId != null && _songs.isNotEmpty) {
      final song = _songs.firstWhere((s) => s.id == lastSongId, orElse: () => _songs.first);

      // On restore, we default the queue to all songs unless we persist the queue (future improvement)
      _queue = List.from(_songs);

      _currentSong = song;
      _duration = Duration(milliseconds: song.duration);
      _position = Duration(milliseconds: lastPosition);
      _updatePalette(song.localArtworkPath);

      // Prepare player in paused state
      final index = _songs.indexOf(song);
      if (index != -1) {
        // Set playlist WITHOUT auto-playing
        final songMaps = _queue
            .map(
              (s) => {
                'id': s.id,
                'title': s.title,
                'artist': s.artist,
                'album': s.album,
                'uri': s.uri,
                'artworkUri': s.artworkUri,
              },
            )
            .toList();

        // Retry logic for when service was just killed and restarted
        bool success = false;
        int retries = 0;

        while (!success && retries < 3) {
          try {
            await _audioHandler.setPlaylist(songMaps, initialIndex: index);

            // IMPORTANT: Pause immediately to prevent auto-play
            await _audioHandler.pause();

            // Small delay to ensure pause command processed
            await Future.delayed(const Duration(milliseconds: 200));

            // Now seek to the saved position
            await _audioHandler.seek(Duration(milliseconds: lastPosition));

            success = true;
          } catch (e) {
            retries++;
            if (retries < 3) {
              await Future.delayed(Duration(milliseconds: 500 * retries)); // Exponential backoff
            }
          }
        }

        if (!success) {
          // Clear invalid session
          final settingsBox = Hive.box('settings');
          await settingsBox.delete('lastPlayedSongId');
          await settingsBox.delete('lastPosition');
        }
      }
      notifyListeners();
    }
  }

  Future<void> _saveState() async {
    if (_currentSong != null) {
      final settingsBox = Hive.box('settings');
      await settingsBox.put('lastPlayedSongId', _currentSong!.id);
      await settingsBox.put('lastPosition', _position.inMilliseconds);
      await settingsBox.put('shuffleMode', _isShuffleEnabled);
      await settingsBox.put('repeatMode', _repeatMode);
      await settingsBox.put('volume', _volume);
      await settingsBox.put('speed', _speed);
    }
  }

  Future<void> _cacheArtwork() async {
    // Run in background to prevent ANR
    final directory = await getApplicationDocumentsDirectory();
    // ITunesService is static, no need to instantiate

    // Increased batch size for faster parallel processing
    const batchSize = 20; // Increased from 10 to 20

    for (int i = 0; i < _songs.length; i += batchSize) {
      final batch = _songs.skip(i).take(batchSize).toList();

      // Process batch songs in parallel
      await Future.wait(
        batch.map((song) => _processSongArtwork(song, directory)),
        eagerError: false, // Continue even if some fail
      ).timeout(
        Duration(seconds: 60), // Increased timeout for larger batch
        onTimeout: () {
          return [];
        },
      );

      // Reduced delay between batches
      await Future.delayed(Duration(milliseconds: 50));

      // Notify listeners after each batch for progressive updates
      notifyListeners();
    }
  }

  Future<void> _processSongArtwork(Song song, Directory directory) async {
    try {
      // PRIORITY 1: MediaStore Artwork (Instant, Local)
      if (song.artworkUri != null) {
        final uriParts = song.artworkUri!.split('/');
        final albumId = uriParts.last;
        final path = '${directory.path}/album_$albumId.jpg';
        final file = File(path);

        if (await file.exists()) {
          // Use existing cached MediaStore artwork
          if (song.localArtworkPath != path) {
            song.localArtworkPath = path;
            await song.save();
          }
        } else {
          // Extract MediaStore artwork
          try {
            final bytes = await _audioHandler.getAlbumArt(albumId);
            if (bytes != null) {
              await file.writeAsBytes(bytes);
              song.localArtworkPath = path;
              await song.save();
            }
          } catch (e) {
            print('MediaStore extraction failed: $e');
          }
        }
      }

      // PRIORITY 2: iTunes Artwork (Background Upgrade to Higher Quality)
      // Only attempt if we don't already have iTunes artwork cached
      final safeName = '${song.artist}_${song.album}'.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      final itunesPath = '${directory.path}/itunes_$safeName.jpg';
      final itunesFile = File(itunesPath);

      if (!await itunesFile.exists()) {
        // Try to fetch from iTunes (if online) - with better error handling
        try {
          final query = '${song.artist} ${song.album}';
          final artworkUrl = await ITunesService.fetchArtwork(query, retries: 1);

          if (artworkUrl != null) {
            final response = await http
                .get(Uri.parse(artworkUrl))
                .timeout(Duration(seconds: 10), onTimeout: () => throw TimeoutException('iTunes fetch timeout'));

            if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
              await itunesFile.writeAsBytes(response.bodyBytes);
              // Upgrade to iTunes artwork
              song.localArtworkPath = itunesPath;
              await song.save();
            }
          }
        } catch (e) {
          // iTunes failed, but we already have MediaStore fallback, so just log and continue
          print('iTunes upgrade skipped: $e');
        }
      } else {
        // iTunes artwork already exists, use it (highest quality)
        if (song.localArtworkPath != itunesPath) {
          song.localArtworkPath = itunesPath;
          await song.save();
        }
      }
    } catch (e) {
      // Silently continue on error
      print('Artwork processing error: $e');
    }
  }

  Future<void> _updatePalette(String? artworkPath) async {
    if (artworkPath == null || !File(artworkPath).existsSync()) {
      _accentColor = Colors.deepPurple;
      notifyListeners();
      return;
    }

    try {
      final palette = await PaletteGenerator.fromImageProvider(FileImage(File(artworkPath)), maximumColorCount: 20);

      // Vibrant > LightVibrant > DarkVibrant > Fallback (Matches PlayerPage)
      Color extracted =
          palette.vibrantColor?.color ??
          palette.lightVibrantColor?.color ??
          palette.darkVibrantColor?.color ??
          const Color(0xFF9B51E0); // Default purple

      // Apply safety check (too dark/gray fallback)
      _accentColor = ColorUtils.getSafeAccentColor(extracted);
    } catch (e) {
      print('Error generating palette: $e');
      _accentColor = Colors.deepPurple;
    }
    notifyListeners();
  }

  Future<void> playSong(Song song) async {
    final index = _songs.indexOf(song);
    if (index != -1) {
      // Reset queue to full song library when playing individual songs
      // This ensures the index matches the playlist
      _queue = List.from(_songs);

      final songMaps = _queue
          .map(
            (s) => {
              'id': s.id,
              'title': s.title,
              'artist': s.artist,
              'album': s.album,
              'uri': s.uri,
              'artworkUri': s.artworkUri,
            },
          )
          .toList();
      
      await _fadeOut();
      await _audioHandler.setPlaylist(songMaps, initialIndex: index);
      _isPlaying = true;
      _currentSong = song;
      _hasCountedPlay = false; // Reset for new song
      _duration = Duration(milliseconds: song.duration);
      _startProgressTimer();
      _updatePalette(song.localArtworkPath);
      await _fadeIn();
      notifyListeners();
    }
  }

  /// Play a custom list of songs (for playlists)
  Future<void> playSongList(List<Song> songs, int initialIndex, {bool shuffle = false}) async {
    if (songs.isEmpty) return;

    // Update queue to the custom list
    _queue = List.from(songs);

    final songMaps = _queue
        .map(
          (s) => {
            'id': s.id,
            'title': s.title,
            'artist': s.artist,
            'album': s.album,
            'uri': s.uri,
            'artworkUri': s.artworkUri,
          },
        )
        .toList();

    await _fadeOut();
    await _audioHandler.setPlaylist(songMaps, initialIndex: initialIndex);

    // Apply shuffle if requested
    if (shuffle && !_isShuffleEnabled) {
      _isShuffleEnabled = true;
      await _audioHandler.setShuffleMode(true);
    }

    _isPlaying = true;
    _currentSong = songs[initialIndex];
    _hasCountedPlay = false; // Reset for new song
    _duration = Duration(milliseconds: _currentSong!.duration);
    _startProgressTimer();
    _updatePalette(_currentSong!.localArtworkPath);
    await _fadeIn();
    notifyListeners();
  }

  Future<void> pause() async {
    await _audioHandler.pause();
    _isPlaying = false;
    _stopProgressTimer();
    await _saveState(); // Save when pausing
    notifyListeners();
  }

  Future<void> resume() async {
    await _audioHandler.play();
    _isPlaying = true;
    _startProgressTimer();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioHandler.seek(position);
    _position = position;
    await _saveState(); // Save immediately after seeking
    notifyListeners();
  }

  Future<void> next() async {
    await _fadeOut();
    await _audioHandler.next();
    await _fadeIn();

    // Wait for the audio handler to process the skip
    await Future.delayed(const Duration(milliseconds: 200));

    // Get the actual current media item index from the player
    final currentIndex = await _audioHandler.getCurrentMediaItemIndex();

    if (currentIndex >= 0 && currentIndex < _queue.length) {
      _currentSong = _queue[currentIndex];
      _hasCountedPlay = false; // Reset for new song
      _duration = Duration(milliseconds: _currentSong!.duration);
      _position = Duration.zero;
      _updatePalette(_currentSong!.localArtworkPath);
    }

    await _saveState();
    notifyListeners();
  }

  Future<void> previous() async {
    await _fadeOut();
    await _audioHandler.previous();
    await _fadeIn();

    // Wait for the audio handler to process the skip
    await Future.delayed(const Duration(milliseconds: 200));

    // Get the actual current media item index from the player
    final currentIndex = await _audioHandler.getCurrentMediaItemIndex();

    if (currentIndex >= 0 && currentIndex < _queue.length) {
      _currentSong = _queue[currentIndex];
      _hasCountedPlay = false; // Reset for new song
      _duration = Duration(milliseconds: _currentSong!.duration);
      _position = Duration.zero;
      _updatePalette(_currentSong!.localArtworkPath);
    }

    await _saveState();
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    _isShuffleEnabled = !_isShuffleEnabled;
    await _audioHandler.setShuffleMode(_isShuffleEnabled);
    await _saveState();
    notifyListeners();
  }

  Future<void> toggleRepeat() async {
    _repeatMode = (_repeatMode + 1) % 3;
    await _audioHandler.setRepeatMode(_repeatMode);
    await _saveState();
    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioHandler.setVolume(_volume);
    await _saveState();
    notifyListeners();
  }

  // Crossfade (Smart Fading)
  bool _isCrossfadeEnabled = false;
  bool get isCrossfadeEnabled => _isCrossfadeEnabled;

  Future<void> setCrossfade(bool enabled) async {
    _isCrossfadeEnabled = enabled;
    final settingsBox = Hive.box('settings');
    await settingsBox.put('crossfade', enabled);
    notifyListeners();
  }

  /// Helper to fade out volume
  Future<void> _fadeOut() async {
    if (!_isCrossfadeEnabled) return;
    final startVol = _volume;
    const steps = 10;
    const duration = Duration(milliseconds: 500); // 500ms fade
    final stepTime = Duration(milliseconds: duration.inMilliseconds ~/ steps);

    for (int i = 1; i <= steps; i++) {
      final vol = startVol * (1 - (i / steps));
      await _audioHandler.setVolume(vol);
      await Future.delayed(stepTime);
    }
  }

  /// Helper to fade in volume
  Future<void> _fadeIn() async {
    if (!_isCrossfadeEnabled) {
      // Ensure volume is restored if crossfade disabled mid-transition
      await _audioHandler.setVolume(_volume);
      return;
    }
    final targetVol = _volume;
    const steps = 10;
    const duration = Duration(milliseconds: 500);
    final stepTime = Duration(milliseconds: duration.inMilliseconds ~/ steps);

    // Start from 0
    await _audioHandler.setVolume(0);

    for (int i = 1; i <= steps; i++) {
      final vol = targetVol * (i / steps);
      await _audioHandler.setVolume(vol);
      await Future.delayed(stepTime);
    }
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.5, 2.0);
    await _audioHandler.setSpeed(_speed);
    await _saveState();
    notifyListeners();
  }

  Future<void> toggleFavorite(Song song) async {
    song.isFavorite = !song.isFavorite;
    await song.save(); // Persist to Hive
    notifyListeners();

    // Sync all favorites to cloud in background
    final favoriteSongIds = _songs.where((s) => s.isFavorite).map((s) => s.id).toList();
    CloudSyncService().syncFavoritesToCloud(favoriteSongIds);
  }

  /// Apply favorites from cloud sync (called after login)
  Future<void> applyCloudFavorites(List<String> cloudFavoriteIds) async {
    for (var song in _songs) {
      if (cloudFavoriteIds.contains(song.id) && !song.isFavorite) {
        song.isFavorite = true;
        await song.save();
      }
    }
    notifyListeners();
  }

  Future<void> incrementPlayCount(Song song) async {
    song.playCount = song.playCount + 1;
    await song.save(); // Persist to Hive

    // Also add to play history
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('play_history');
    List<dynamic> history = [];

    if (historyJson != null) {
      try {
        history = jsonDecode(historyJson);
      } catch (e) {
        print('Error parsing history: $e');
      }
    }

    history.add({'songId': song.id, 'timestamp': DateTime.now().toIso8601String()});

    // Keep only last 100 entries
    if (history.length > 100) {
      history = history.sublist(history.length - 100);
    }

    await prefs.setString('play_history', jsonEncode(history));
  }

  // Sleep Timer
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;

  bool get isSleepTimerActive => _sleepTimer != null && _sleepTimer!.isActive;

  Duration? get sleepTimerRemaining {
    if (_sleepTimerEndTime == null) return null;
    final remaining = _sleepTimerEndTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void scheduleSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepTimerEndTime = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      pause();
      cancelSleepTimer();
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;
    notifyListeners();
  }

  /// Stop playback and clear session (called from notification close button)
  Future<void> stop() async {
    // Stop timer
    _stopProgressTimer();

    // Clear state
    _isPlaying = false;
    _currentSong = null;
    _position = Duration.zero;
    _duration = Duration.zero;

    // Clear saved session so app doesn't try to restore
    final settingsBox = Hive.box('settings');
    await settingsBox.delete('lastPlayedSongId');
    await settingsBox.delete('lastPosition');

    // Also delete marker file if it exists (for consistency)
    try {
      final directory = await getApplicationDocumentsDirectory();
      final markerFile = File('${directory.parent.path}/files/playback_stopped.marker');
      if (await markerFile.exists()) {
        await markerFile.delete();
      }
    } catch (e) {
      // Ignore errors
    }

    notifyListeners();
  }

  Future<Map<String, dynamic>?> getAlbumInfo(String album, String artist) async {
    try {
      final box = await Hive.openBox('album_info_cache');
      final key = '${album}_$artist'.toLowerCase().replaceAll(RegExp(r'\s+'), '_');

      if (box.containsKey(key)) {
        final cachedData = box.get(key);
        if (cachedData != null) {
          // Convert LinkedMap to Map<String, dynamic> if needed
          try {
            return Map<String, dynamic>.from(cachedData);
          } catch (e) {
            print('Error parsing cached data: $e');
          }
        }
      }

      final service = ITunesService();
      final data = await service.fetchAlbumDetails(album, artist);

      if (data != null) {
        await box.put(key, data);
      }

      return data;
    } catch (e) {
      print('Error getting album info: $e');
      return null;
    }
  }
}
