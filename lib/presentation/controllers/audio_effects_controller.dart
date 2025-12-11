import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../data/models/audio_effects_model.dart';
import '../../services/audio_handler.dart';

class AudioEffectsController extends ChangeNotifier {
  final AudioHandler _audioHandler = AudioHandler();
  AudioEffects _effects = AudioEffects(); // Default value instead of late
  late Box<AudioEffects> _effectsBox;

  AudioEffects get effects => _effects;

  Future<void> initialize() async {
    // Open Hive box for audio effects
    _effectsBox = await Hive.openBox<AudioEffects>('audioEffects');

    // Load saved effects or create default
    _effects = _effectsBox.get('current') ?? AudioEffects();

    // Check native EQ capabilities
    try {
      final int nativeBandCount = await _audioHandler.getEqualizerBandCount();
      if (nativeBandCount > 0 && _effects.equalizerBands.length != nativeBandCount) {
        print('🎚️ Resizing EQ bands from ${_effects.equalizerBands.length} to $nativeBandCount');
        // Resize bands to match native count
        _effects.equalizerBands = List.filled(nativeBandCount, 0);
        // Also clear labels to force refresh
        _effects.frequencyLabels = null;
      }

      // Fetch Frequency Labels if missing or count mismatch
      if (_effects.frequencyLabels == null || _effects.frequencyLabels!.length != nativeBandCount) {
        final List<String> labels = [];
        for (int i = 0; i < nativeBandCount; i++) {
          final freq = await _audioHandler.getEqualizerCenterFreq(i);
          if (freq < 1000) {
            labels.add('${freq / 1000}Hz'); // This looks wrong, freq < 1000 should be Hz.
            // Wait, standard is mHz? No, usually Hz or mHz.
            // Android getCenterFreq returns milliHertz.
            // So 60000 mHz = 60 Hz.
            // Let's verify units. Android docs: "milliHertz".
          }
        }
        // Let's rewrite the loop with correct units logic
        final List<String> newLabels = [];
        for (int i = 0; i < nativeBandCount; i++) {
          final mHz = await _audioHandler.getEqualizerCenterFreq(i);
          final hz = mHz / 1000;
          if (hz >= 1000) {
            newLabels.add('${(hz / 1000).toStringAsFixed(1).replaceAll('.0', '')}kHz');
          } else {
            newLabels.add('${hz.toInt()}Hz');
          }
        }
        _effects.frequencyLabels = newLabels;
      }
    } catch (e) {
      print('Error initializing native EQ: $e');
    }

    // Apply saved effects to native layer
    await _applyAllEffects();
    notifyListeners();
  }

  Future<void> _applyAllEffects() async {
    // Apply equalizer bands
    for (int i = 0; i < _effects.equalizerBands.length; i++) {
      await _audioHandler.setEqualizerBand(i, _effects.equalizerBands[i]);
    }

    // Apply bass boost
    await _audioHandler.setBassBoost(_effects.bassBoost);

    // Apply virtualizer
    await _audioHandler.setVirtualizer(_effects.virtualizer);

    // Apply reverb
    await _audioHandler.setReverb(_effects.reverbPreset);

    print(
      '🎚️ Applied audio effects: EQ=${_effects.equalizerBands}, Bass=${_effects.bassBoost}, Virt=${_effects.virtualizer}, Reverb=${_effects.reverbPreset}',
    );
  }

  Future<void> setEqualizerBand(int bandIndex, int level) async {
    _effects.equalizerBands[bandIndex] = level;
    await _audioHandler.setEqualizerBand(bandIndex, level);
    await _saveEffects();
    notifyListeners();
  }

  Future<void> setBassBoost(int strength) async {
    _effects.bassBoost = strength;
    await _audioHandler.setBassBoost(strength);
    await _saveEffects();
    notifyListeners();
  }

  Future<void> setVirtualizer(int strength) async {
    _effects.virtualizer = strength;
    await _audioHandler.setVirtualizer(strength);
    await _saveEffects();
    notifyListeners();
  }

  Future<void> setReverb(int preset) async {
    _effects.reverbPreset = preset;
    await _audioHandler.setReverb(preset);
    await _saveEffects();
    notifyListeners();
  }

  Future<void> applyPreset(String presetName) async {
    _effects.applyPreset(presetName);
    await _applyAllEffects();
    await _saveEffects();
    notifyListeners();
  }

  Future<void> resetAll() async {
    _effects.reset();
    await _audioHandler.resetEqualizer();
    await _audioHandler.setBassBoost(0);
    await _audioHandler.setVirtualizer(0);
    await _audioHandler.setReverb(0);
    await _saveEffects();
    notifyListeners();
  }

  Future<void> _saveEffects() async {
    await _effectsBox.put('current', _effects);
  }

  // Convert millibels to display value (-15 to +15 dB)
  double bandLevelToDb(int level) {
    return level / 100.0;
  }

  // Convert display value to millibels
  int dbToBandLevel(double db) {
    return (db * 100).round();
  }
}
