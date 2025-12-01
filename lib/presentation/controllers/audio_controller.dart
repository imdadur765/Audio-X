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

      // Restore session only if requested
      if (restoreSession) {
        await _restoreSession();
      }

      // Cache artwork in background
      _cacheArtwork();
    }
  }

  Future<void> _restoreSession() async {
    print('🔄 Starting session restoration...');
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

  Future<void> _cacheArtwork() async {
    final directory = await getApplicationDocumentsDirectory();

    for (var song in _songs) {
      if (song.localArtworkPath == null && song.artworkUri != null) {
        try {
          // Extract albumId from artworkUri (content://.../albumart/123)
          final uriParts = song.artworkUri!.split('/');
          final albumId = uriParts.last;
          final path = '${directory.path}/album_$albumId.jpg';
          final file = File(path);

          if (await file.exists()) {
            song.localArtworkPath = path;
            song.save();
          } else {
            final bytes = await _audioHandler.getAlbumArt(albumId);
            if (bytes != null) {
              await file.writeAsBytes(bytes);
              song.localArtworkPath = path;
              song.save(); // Update Hive
            }
          }
        } catch (e) {
          print("Error caching artwork for ${song.title}: $e");
        }
      }
    }
    notifyListeners();
  }

  Future<void> playSong(Song song) async {
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
      notifyListeners();
    }
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
