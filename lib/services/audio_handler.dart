import 'package:flutter/services.dart';

class AudioHandler {
  static const MethodChannel _channel = MethodChannel('com.example.audio_x/audio');

  Future<void> play() async {
    try {
      await _channel.invokeMethod('play');
    } on PlatformException catch (e) {
      print("Failed to play: '${e.message}'.");
    }
  }

  Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
    } on PlatformException catch (e) {
      print("Failed to pause: '${e.message}'.");
    }
  }

  Future<void> setUri(String uri) async {
    try {
      await _channel.invokeMethod('setUri', {'uri': uri});
    } on PlatformException catch (e) {
      print("Failed to set URI: '${e.message}'.");
    }
  }

  Future<void> setPlaylist(List<Map<String, dynamic>> songs, {int initialIndex = 0}) async {
    try {
      await _channel.invokeMethod('setPlaylist', {'songs': songs, 'initialIndex': initialIndex});
    } on PlatformException catch (e) {
      print("Failed to set playlist: '${e.message}'.");
    }
  }

  Future<List<Map<dynamic, dynamic>>> getSongs() async {
    try {
      final List<dynamic> songs = await _channel.invokeMethod('getSongs');
      return songs.cast<Map<dynamic, dynamic>>();
    } on PlatformException catch (e) {
      print("Failed to get songs: '${e.message}'.");
      return [];
    }
  }

  Future<Uint8List?> getAlbumArt(String albumId) async {
    try {
      final result = await _channel.invokeMethod('getAlbumArt', {'albumId': albumId});
      return result as Uint8List?;
    } on PlatformException catch (e) {
      print("Failed to get album art: '${e.message}'.");
      return null;
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _channel.invokeMethod('seekTo', {'position': position.inMilliseconds});
    } on PlatformException catch (e) {
      print("Failed to seek: '${e.message}'.");
    }
  }

  Future<void> next() async {
    try {
      await _channel.invokeMethod('seekToNext');
    } on PlatformException catch (e) {
      print("Failed to skip next: '${e.message}'.");
    }
  }

  Future<void> previous() async {
    try {
      await _channel.invokeMethod('seekToPrevious');
    } on PlatformException catch (e) {
      print("Failed to skip previous: '${e.message}'.");
    }
  }

  Future<Duration> getPosition() async {
    try {
      final position = await _channel.invokeMethod('getPosition');
      final duration = Duration(milliseconds: position as int);
      print('🎯 Flutter getPosition: ${duration.inSeconds}s (${position}ms)');
      return duration;
    } on PlatformException catch (e) {
      print("Failed to get position: '${e.message}'.");
      return Duration.zero;
    }
  }

  Future<int> getCurrentMediaItemIndex() async {
    try {
      final index = await _channel.invokeMethod('getCurrentMediaItemIndex');
      return index as int;
    } on PlatformException catch (e) {
      print("Failed to get current media item index: '${e.message}'.");
      return -1;
    }
  }

  Future<void> setShuffleMode(bool enabled) async {
    try {
      await _channel.invokeMethod('setShuffleMode', {'enabled': enabled});
    } on PlatformException catch (e) {
      print("Failed to set shuffle: '${e.message}'.");
    }
  }

  Future<void> setRepeatMode(int mode) async {
    try {
      await _channel.invokeMethod('setRepeatMode', {'mode': mode});
    } on PlatformException catch (e) {
      print("Failed to set repeat: '${e.message}'.");
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume});
    } on PlatformException catch (e) {
      print("Failed to set volume: '${e.message}'.");
    }
  }

  Future<void> setSpeed(double speed) async {
    try {
      await _channel.invokeMethod('setSpeed', {'speed': speed});
    } on PlatformException catch (e) {
      print("Failed to set speed: '${e.message}'.");
    }
  }

  // Equalizer & Effects Methods
  Future<void> setEqualizerBand(int bandIndex, int level) async {
    try {
      await _channel.invokeMethod('setEqualizerBand', {
        'bandIndex': bandIndex,
        'level': level, // -1500 to 1500 (millibels)
      });
    } on PlatformException catch (e) {
      print("Failed to set equalizer band: '${e.message}'.");
    }
  }

  Future<int> getEqualizerBand(int bandIndex) async {
    try {
      final level = await _channel.invokeMethod('getEqualizerBand', {'bandIndex': bandIndex});
      return level as int;
    } on PlatformException catch (e) {
      print("Failed to get equalizer band: '${e.message}'.");
      return 0;
    }
  }

  Future<void> setBassBoost(int strength) async {
    try {
      await _channel.invokeMethod('setBassBoost', {'strength': strength}); // 0-1000
    } on PlatformException catch (e) {
      print("Failed to set bass boost: '${e.message}'.");
    }
  }

  Future<void> setVirtualizer(int strength) async {
    try {
      await _channel.invokeMethod('setVirtualizer', {'strength': strength}); // 0-1000
    } on PlatformException catch (e) {
      print("Failed to set virtualizer: '${e.message}'.");
    }
  }

  Future<void> setReverb(int preset) async {
    try {
      await _channel.invokeMethod('setReverb', {'preset': preset}); // 0-6
    } on PlatformException catch (e) {
      print("Failed to set reverb: '${e.message}'.");
    }
  }

  Future<void> resetEqualizer() async {
    try {
      await _channel.invokeMethod('resetEqualizer');
    } on PlatformException catch (e) {
      print("Failed to reset equalizer: '${e.message}'.");
    }
  }
}
