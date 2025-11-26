// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_spotify_artist.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CachedSpotifyArtistAdapter extends TypeAdapter<CachedSpotifyArtist> {
  @override
  final int typeId = 1;

  @override
  CachedSpotifyArtist read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedSpotifyArtist(
      artistName: fields[0] as String,
      spotifyId: fields[1] as String?,
      imageUrl: fields[2] as String?,
      followers: fields[3] as int?,
      genres: (fields[4] as List).cast<String>(),
      popularity: fields[5] as int?,
      cachedAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CachedSpotifyArtist obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.artistName)
      ..writeByte(1)
      ..write(obj.spotifyId)
      ..writeByte(2)
      ..write(obj.imageUrl)
      ..writeByte(3)
      ..write(obj.followers)
      ..writeByte(4)
      ..write(obj.genres)
      ..writeByte(5)
      ..write(obj.popularity)
      ..writeByte(6)
      ..write(obj.cachedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedSpotifyArtistAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
