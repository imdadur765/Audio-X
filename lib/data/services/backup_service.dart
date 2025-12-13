import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/song_model.dart';
import '../models/audio_effects_model.dart';

class BackupService {
  static const String _backupFileName = 'audio_x_backup.json';

  /// Export data to a JSON file and share it
  Future<void> createBackup() async {
    try {
      if (!Hive.isBoxOpen('audioEffects')) await Hive.openBox<AudioEffects>('audioEffects');

      final backupData = <String, dynamic>{
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'songs': _getSongData(),
        'settings': _getSettingsData(),
        'audio_effects': _getAudioEffectsData(),
      };

      final jsonString = jsonEncode(backupData);
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$_backupFileName');
      await file.writeAsString(jsonString);

      await Share.shareXFiles([XFile(file.path)], text: 'Audio X Backup');
    } catch (e) {
      throw Exception('Failed to create backup: $e');
    }
  }

  /// Import data from a selected JSON file
  Future<void> restoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        final data = jsonDecode(jsonString) as Map<String, dynamic>;

        await _restoreSettings(data['settings']);
        await _restoreAudioEffects(data['audio_effects']);
        await _restoreSongs(data['songs']);
      }
    } catch (e) {
      throw Exception('Failed to restore backup: $e');
    }
  }

  // --- Helpers for Getting Data ---

  Map<String, dynamic> _getSongData() {
    final songBox = Hive.box<Song>('songs');
    final songsData = <String, dynamic>{};

    for (var song in songBox.values) {
      // Key by Title + Artist to be device-independent
      final key = '${song.title}|${song.artist}';
      if (song.isFavorite || song.playCount > 0) {
        songsData[key] = {'isFavorite': song.isFavorite, 'playCount': song.playCount, 'dateAdded': song.dateAdded};
      }
    }
    return songsData;
  }

  Map<String, dynamic> _getSettingsData() {
    final settingsBox = Hive.box('settings');
    return {
      'themeMode': settingsBox.get('themeMode'),
      'isOledMode': settingsBox.get('isOledMode'),
      'fontScale': settingsBox.get('fontScale'),
    };
  }

  Map<String, dynamic> _getAudioEffectsData() {
    if (!Hive.isBoxOpen('audioEffects')) return {};

    final effectsBox = Hive.box<AudioEffects>('audioEffects');
    final effects = effectsBox.get('current');

    if (effects == null) return {};

    return {
      'equalizerBands': effects.equalizerBands,
      'bassBoost': effects.bassBoost,
      'virtualizer': effects.virtualizer,
      'reverbPreset': effects.reverbPreset,
      'currentPreset': effects.currentPreset,
    };
  }

  // --- Helpers for Restoring Data ---

  Future<void> _restoreSettings(Map<String, dynamic>? data) async {
    if (data == null) return;
    final settingsBox = Hive.box('settings');
    if (data.containsKey('themeMode')) await settingsBox.put('themeMode', data['themeMode']);
    if (data.containsKey('isOledMode')) await settingsBox.put('isOledMode', data['isOledMode']);
    if (data.containsKey('fontScale')) await settingsBox.put('fontScale', data['fontScale']);
  }

  Future<void> _restoreAudioEffects(Map<String, dynamic>? data) async {
    if (data == null) return;
    if (!Hive.isBoxOpen('audioEffects')) await Hive.openBox<AudioEffects>('audioEffects');
    final effectsBox = Hive.box<AudioEffects>('audioEffects');
    final effects = effectsBox.get('current') ?? AudioEffects();

    if (data.containsKey('equalizerBands')) {
      effects.equalizerBands = List<int>.from(data['equalizerBands']);
    }
    if (data.containsKey('bassBoost')) effects.bassBoost = data['bassBoost'];
    if (data.containsKey('virtualizer')) effects.virtualizer = data['virtualizer'];
    if (data.containsKey('reverbPreset')) effects.reverbPreset = data['reverbPreset'];
    if (data.containsKey('currentPreset')) effects.currentPreset = data['currentPreset'];

    await effectsBox.put('current', effects);
  }

  Future<void> _restoreSongs(Map<String, dynamic>? data) async {
    if (data == null) return;
    final songBox = Hive.box<Song>('songs');

    // Create a lookup map for local songs: "Title|Artist" -> Song Object
    final localSongs = <String, Song>{};
    for (var song in songBox.values) {
      localSongs['${song.title}|${song.artist}'] = song;
    }

    // Update local songs with backup data
    data.forEach((key, value) {
      if (localSongs.containsKey(key)) {
        final song = localSongs[key]!;
        final map = value as Map<String, dynamic>;

        bool changed = false;
        if (map.containsKey('isFavorite')) {
          song.isFavorite = map['isFavorite'];
          changed = true;
        }
        if (map.containsKey('playCount')) {
          song.playCount = map['playCount'];
          changed = true;
        }

        if (changed) song.save();
      }
    });
  }
}
