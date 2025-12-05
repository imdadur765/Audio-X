// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SongAdapter extends TypeAdapter<Song> {
  @override
  final int typeId = 0;

  @override
  Song read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return Song(
      id: fields[0] as String,
      title: fields[1] as String,
      artist: fields[2] as String,
      album: fields[3] as String,
      uri: fields[4] as String,
      artworkUri: fields[5] as String?,
      duration: fields[6] as int,
      localArtworkPath: fields[7] as String?,
      lyricsPath: fields[8] as String?,
      lyricsSource: fields[9] as String?,
      isFavorite: fields[10] as bool,
      playCount: fields[11] as int,
      dateAdded: fields[12] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, Song obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.artist)
      ..writeByte(3)
      ..write(obj.album)
      ..writeByte(4)
      ..write(obj.uri)
      ..writeByte(5)
      ..write(obj.artworkUri)
      ..writeByte(6)
      ..write(obj.duration)
      ..writeByte(7)
      ..write(obj.localArtworkPath)
      ..writeByte(8)
      ..write(obj.lyricsPath)
      ..writeByte(9)
      ..write(obj.lyricsSource)
      ..writeByte(10)
      ..write(obj.isFavorite)
      ..writeByte(11)
      ..write(obj.playCount)
      ..writeByte(12)
      ..write(obj.dateAdded);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SongAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
