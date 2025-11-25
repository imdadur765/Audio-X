// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_effects_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AudioEffectsAdapter extends TypeAdapter<AudioEffects> {
  @override
  final int typeId = 2;

  @override
  AudioEffects read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AudioEffects(
      equalizerBands: (fields[0] as List?)?.cast<int>(),
      bassBoost: fields[1] as int,
      virtualizer: fields[2] as int,
      reverbPreset: fields[3] as int,
      currentPreset: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AudioEffects obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.equalizerBands)
      ..writeByte(1)
      ..write(obj.bassBoost)
      ..writeByte(2)
      ..write(obj.virtualizer)
      ..writeByte(3)
      ..write(obj.reverbPreset)
      ..writeByte(4)
      ..write(obj.currentPreset);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioEffectsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
