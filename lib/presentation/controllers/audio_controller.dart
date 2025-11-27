import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/song_model.dart';
import '../../services/audio_handler.dart';

class AudioController extends ChangeNotifier with WidgetsBindingObserver {
  final AudioHandler _audioHandler = AudioHandler();
  List<Song> _songs = [];
  bool _isPlaying = false;
  Song? _currentSong;
  Timer? _progressTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isShuffleEnabled = false;
  int _repeatMode = 0; // 0: Off, 1: One, 2: All
  double _volume = 1.0;
  double _speed = 1.0;

  List<Song> get songs => _songs;
  bool get isPlaying => _isPlaying;
  Song? get currentSong => _currentSong;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isShuffleEnabled => _isShuffleEnabled;
  int get repeatMode => _repeatMode;
  double get volume => _volume;
  double get speed => _speed;

  AudioController() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('📱 App lifecycle changed: $state');
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App going to background - save state and stop timer
      print('⏸️ App going to background, saving state and stopping timer');
      _saveState();
      _stopProgressTimer();
    } else if (state == AppLifecycleState.resumed && _isPlaying) {
      // App resumed and was playing - restart timer
      print('▶️ App resumed, restarting timer');
      _startProgressTimer();
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      final pos = await _audioHandler.getPosition();
      if (_currentSong != null) {
        _duration = Duration(milliseconds: _currentSong!.duration);
      }
      _position = pos;
      _saveState(); // Persist state
      notifyListeners();
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
  }

  Future<void> loadSongs() async {
    // Check permissions
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      // Check if request is already in progress (simple check)
      if (await Permission.storage.request().isGranted) {
        status = PermissionStatus.granted;
      }
    }

    // Also check for audio permission on Android 13+
    var audioStatus = await Permission.audio.status;
    if (!audioStatus.isGranted) {
      audioStatus = await Permission.audio.request();
    }

    if (status.isGranted || audioStatus.isGranted) {
      final songsData = await _audioHandler.getSongs();
      final box = Hive.box<Song>('songs');

      // Clear existing (simple cache strategy for now)
      // In a real app, we would sync/update
      await box.clear();

      for (var data in songsData) {
        final song = Song(
          id: data['id'].toString(),
          title: data['title'].toString(),
          artist: data['artist'].toString(),
          album: data['album'].toString(),
          uri: data['uri'].toString(),
          duration: int.tryParse(data['duration'].toString()) ?? 0,
          artworkUri: data['artworkUri']?.toString(),
        );
        box.add(song);
      }

      _songs = box.values.toList();
      notifyListeners();

      // Restore session
      await _restoreSession();

      // Cache artwork in background
      _cacheArtwork();
    }
  }

  Future<void> _restoreSession() async {
    print('🔄 Starting session restoration...');

    // Check if native player is already playing (service running)
    final isNativePlaying = await _audioHandler.isPlaying();
    final currentNativeItem = await _audioHandler.getCurrentMediaItem();

    if (isNativePlaying && currentNativeItem != null) {
      print('🔊 Native player is ALREADY PLAYING. Syncing state...');

      // Find the song in our list
      // Note: Native item ID might need matching strategy if IDs are complex
      // Assuming ID matches
      final songId = currentNativeItem['id']?.toString();
      if (songId != null && _songs.isNotEmpty) {
        try {
          final song = _songs.firstWhere((s) => s.id == songId);
          _currentSong = song;
          _duration = Duration(milliseconds: song.duration);
          _isPlaying = true;

          // Restore other settings
          final settingsBox = Hive.box('settings');
          _isShuffleEnabled = settingsBox.get('shuffleMode') as bool? ?? false;
          _repeatMode = settingsBox.get('repeatMode') as int? ?? 0;

          _startProgressTimer();
          notifyListeners();
          return; // Sync successful
        } catch (e) {
          print('⚠️ Could not find playing song in list: $e. Falling back to normal restore.');
          // Fall through to normal restoration
        }
      }
    }

    // If not playing OR sync failed, proceed with normal restoration
    final settingsBox = Hive.box('settings');
    final lastSongId = settingsBox.get('lastPlayedSongId');
    final lastPosition = settingsBox.get('lastPosition') as int? ?? 0;
    final shuffleMode = settingsBox.get('shuffleMode') as bool? ?? false;
    final repeatMode = settingsBox.get('repeatMode') as int? ?? 0;
    final volume = settingsBox.get('volume') as double? ?? 1.0;
    final speed = settingsBox.get('speed') as double? ?? 1.0;

    print('📖 Restored values: songId=$lastSongId, pos=${lastPosition}ms, shuffle=$shuffleMode, repeat=$repeatMode');

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

      _currentSong = song;
      _duration = Duration(milliseconds: song.duration);
      _position = Duration(milliseconds: lastPosition);

      print('✅ Restored song: ${song.title} at ${_position.inSeconds}s / ${_duration.inSeconds}s');

      // Prepare player in paused state
      final index = _songs.indexOf(song);
      if (index != -1) {
        // Set playlist WITHOUT auto-playing
        final songMaps = _songs
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
        await _audioHandler.setPlaylist(songMaps, initialIndex: index);

        // IMPORTANT: Pause immediately to prevent auto-play
        await _audioHandler.pause();

        // Small delay to ensure pause command processed
        await Future.delayed(const Duration(milliseconds: 100));

        // Now seek to the saved position
        await _audioHandler.seek(Duration(milliseconds: lastPosition));

        print('🎵 Player prepared at index $index, paused at ${lastPosition}ms');
      }
      notifyListeners();
    } else {
      print('⚠️ No previous session found or no songs available');
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
      print('💾 Session Saved: ${_currentSong!.title} at ${_position.inSeconds}s');
    }
  }

  Future<void> _trackRecentlyPlayed(String songId) async {
    try {
      final settingsBox = Hive.box('settings');
      final recentIds = List<String>.from(settingsBox.get('recentlyPlayedIds', defaultValue: <String>[]));

      // Remove if already exists (move to top)
      recentIds.remove(songId);

      // Add to front
      recentIds.insert(0, songId);

      // Keep only last 50
      if (recentIds.length > 50) {
        recentIds.removeRange(50, recentIds.length);
      }

      await settingsBox.put('recentlyPlayedIds', recentIds);

      // Also track play count
      await _trackPlayCount(songId);

      print('🕒 Tracked recently played: $songId');
    } catch (e) {
      print('Error tracking recently played: $e');
    }
  }

  Future<void> _trackPlayCount(String songId) async {
    try {
      final settingsBox = Hive.box('settings');
      final Map<dynamic, dynamic> counts = settingsBox.get('playCounts', defaultValue: {});
      final Map<String, int> playCounts = Map<String, int>.from(counts);

      playCounts[songId] = (playCounts[songId] ?? 0) + 1;

      await settingsBox.put('playCounts', playCounts);
      print('📈 Updated play count for $songId: ${playCounts[songId]}');
    } catch (e) {
      print('Error tracking play count: $e');
    }
  }

  Future<void> _cacheArtwork() async {
    final directory = await getApplicationDocumentsDirectory();

    for (var song in _songs) {
      if (song.localArtworkPath == null && song.artworkUri != null) {
        try {
          // Extract albumId from artworkUri (content://.../albumart/123)
          final uriParts = song.artworkUri!.split('/');
          final albumId = uriParts.last;

          final bytes = await _audioHandler.getAlbumArt(albumId);
          if (bytes != null) {
            final path = '${directory.path}/album_$albumId.jpg';
            final file = File(path);
            await file.writeAsBytes(bytes);

            song.localArtworkPath = path;
            song.save(); // Update Hive
          }
        } catch (e) {
          print("Error caching artwork for ${song.title}: $e");
        }
      }
    }
    notifyListeners();
  }

  Future<void> playSong(Song song) async {
    // If same song is clicked
    if (_currentSong?.id == song.id) {
      // If paused, resume
      if (!_isPlaying) {
        await resume();
      }
      // If already playing, do nothing (just return)
      return;
    }

    final index = _songs.indexOf(song);
    if (index != -1) {
      final songMaps = _songs
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
      await _audioHandler.setPlaylist(songMaps, initialIndex: index);
      _isPlaying = true;
      _currentSong = song;
      _duration = Duration(milliseconds: song.duration);
      _startProgressTimer();
      _trackRecentlyPlayed(song.id);
      notifyListeners();
    }
  }

  Future<void> pause() async {
    try {
      await _audioHandler.pause();
      _isPlaying = false;
      _stopProgressTimer();
      await _saveState(); // Save when pausing
      notifyListeners();
    } catch (e) {
      print('⚠️ Pause failed: $e');
      // Even if native pause fails, update UI state
      _isPlaying = false;
      _stopProgressTimer();
      await _saveState();
      notifyListeners();
    }
  }

  Future<void> resume() async {
    try {
      await _audioHandler.play();
      _isPlaying = true;
      _startProgressTimer();
      notifyListeners();
    } catch (e) {
      print('⚠️ Resume failed, retrying... Error: $e');
      // Retry after short delay (service might be restarting)
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        await _audioHandler.play();
        _isPlaying = true;
        _startProgressTimer();
        notifyListeners();
        print('✅ Resume succeeded on retry');
      } catch (retryError) {
        print('❌ Failed to resume after retry: $retryError');
        // Keep UI in sync - don't mark as playing if it failed
        _isPlaying = false;
        notifyListeners();
      }
    }
  }

  Future<void> seek(Duration position) async {
    await _audioHandler.seek(position);
    _position = position;
    await _saveState(); // Save immediately after seeking
    notifyListeners();
  }

  Future<void> next() async {
    await _audioHandler.next();
    // Optimistic update
    if (_currentSong != null) {
      final index = _songs.indexOf(_currentSong!);
      if (index < _songs.length - 1) {
        _currentSong = _songs[index + 1];
        _duration = Duration(milliseconds: _currentSong!.duration);
      } else if (_repeatMode == 2) {
        _currentSong = _songs.first;
        _duration = Duration(milliseconds: _currentSong!.duration);
      }
    }
    await _saveState(); // Save after track change
    notifyListeners();
  }

  Future<void> previous() async {
    await _audioHandler.previous();
    if (_currentSong != null) {
      final index = _songs.indexOf(_currentSong!);
      if (index > 0) {
        _currentSong = _songs[index - 1];
        _duration = Duration(milliseconds: _currentSong!.duration);
      }
    }
    await _saveState(); // Save after track change
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

  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.5, 2.0);
    await _audioHandler.setSpeed(_speed);
    await _saveState();
    notifyListeners();
  }
}
