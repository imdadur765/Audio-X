import 'package:hive/hive.dart';

part 'audio_effects_model.g.dart';

@HiveType(typeId: 2)
class AudioEffects extends HiveObject {
  // Equalizer: 5 bands with range -15dB to +15dB (stored as -1500 to 1500 millibels)
  @HiveField(0)
  List<int> equalizerBands;

  // Bass Boost: 0-1000
  @HiveField(1)
  int bassBoost;

  // Virtualizer: 0-1000
  @HiveField(2)
  int virtualizer;

  // Reverb Preset: 0=None, 1=SmallRoom, 2=MediumRoom, 3=LargeRoom, 4=MediumHall, 5=LargeHall, 6=Plate
  @HiveField(3)
  int reverbPreset;

  // Current preset name (e.g., 'Rock', 'Pop', 'Custom')
  @HiveField(4)
  String? currentPreset;

  // Frequency labels (e.g., "60Hz", "1kHz")
  @HiveField(5)
  List<String>? frequencyLabels;

  AudioEffects({
    List<int>? equalizerBands,
    this.bassBoost = 0,
    this.virtualizer = 0,
    this.reverbPreset = 0,
    this.currentPreset,
    this.frequencyLabels,
  }) : equalizerBands = equalizerBands ?? [0, 0, 0, 0, 0]; // 5 bands default to 0

  // Built-in presets
  static const Map<String, List<int>> builtInPresets = {
    'Flat': [0, 0, 0, 0, 0],
    'Rock': [300, 200, -100, -200, 400],
    'Pop': [-100, 200, 400, 400, -100],
    'Jazz': [300, 200, 100, 200, 300],
    'Classical': [400, 300, -200, 300, 400],
    'Electronic': [400, 300, 0, 200, 400],
    'Bass Boost': [600, 400, 200, 0, 0],
    'Treble Boost': [0, 0, 200, 400, 600],
  };

  // Reverb preset names
  static const List<String> reverbPresets = [
    'None',
    'Small Room',
    'Medium Room',
    'Large Room',
    'Medium Hall',
    'Large Hall',
    'Plate',
  ];

  // Apply a built-in preset
  void applyPreset(String presetName) {
    if (builtInPresets.containsKey(presetName)) {
      // Create a temporary list of target values
      // If native bands != 5, we might need value mapping, but for now apply direct mapping or fallback
      // Ideally we should interpolate, but for simplicity we'll just apply to first N bands or repeat
      // A better approach for dynamic bands is to skip presets or intelligent map.
      // For this task, we will apply 5-band presets to first 5 bands or stretch.

      final preset = builtInPresets[presetName]!;
      if (equalizerBands.length == 5) {
        equalizerBands = List.from(preset);
      } else {
        // Naive mapping for dynamic bands: just map what we can or reset to 0
        // TODO: Implement intelligent mapping for 10 bands
        // For now, reset to flat if band count mismatches standard 5-band presets
        equalizerBands = List.filled(equalizerBands.length, 0);
      }
      currentPreset = presetName;
    }
  }

  // Reset to flat
  void reset() {
    equalizerBands = List.filled(equalizerBands.length, 0);
    bassBoost = 0;
    virtualizer = 0;
    reverbPreset = 0;
    currentPreset = 'Flat';
  }

  // Copy with
  AudioEffects copyWith({
    List<int>? equalizerBands,
    int? bassBoost,
    int? virtualizer,
    int? reverbPreset,
    String? currentPreset,
    List<String>? frequencyLabels,
  }) {
    return AudioEffects(
      equalizerBands: equalizerBands ?? List.from(this.equalizerBands),
      bassBoost: bassBoost ?? this.bassBoost,
      virtualizer: virtualizer ?? this.virtualizer,
      reverbPreset: reverbPreset ?? this.reverbPreset,
      currentPreset: currentPreset ?? this.currentPreset,
      frequencyLabels: frequencyLabels ?? this.frequencyLabels,
    );
  }
}
