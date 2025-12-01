import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/song_model.dart';

class HybridSongArtwork extends StatelessWidget {
  final String? artworkUri;
  final String? localArtworkPath;
  final double size;
  final double borderRadius;
  final IconData fallbackIcon;
  final Color? fallbackColor;

  const HybridSongArtwork({
    super.key,
    this.artworkUri,
    this.localArtworkPath,
    required this.size,
    this.borderRadius = 8.0,
    this.fallbackIcon = Icons.music_note_rounded,
    this.fallbackColor,
  });

  factory HybridSongArtwork.fromSong({required Song song, required double size, double borderRadius = 8.0}) {
    return HybridSongArtwork(
      artworkUri: song.artworkUri,
      localArtworkPath: song.localArtworkPath,
      size: size,
      borderRadius: borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(width: size, height: size, child: _buildArtwork()),
    );
  }

  Widget _buildArtwork() {
    // 1. Try Local File
    if (localArtworkPath != null && File(localArtworkPath!).existsSync()) {
      return Image.file(
        File(localArtworkPath!),
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    }

    // 2. Try URI (Content Provider or Network)
    if (artworkUri != null && artworkUri!.isNotEmpty) {
      // If it's a content URI (Android MediaStore)
      if (artworkUri!.startsWith('content://')) {
        // We can't directly display content URIs with Image.network or Image.file easily without a custom loader
        // But often audio_service or similar plugins handle this.
        // For now, we'll rely on the fact that we should have cached it to localArtworkPath if possible.
        // If we haven't cached it yet, we might show fallback or try a specific content provider image provider if we had one.
        // Let's assume for this specific widget, we prefer the local path.
        // If we really want to support content URIs directly, we might need a specific package or just show fallback until cached.
        return _buildFallback();
      }

      // If it's a network URL (e.g. from Spotify in the past, or a remote server)
      if (artworkUri!.startsWith('http')) {
        return Image.network(
          artworkUri!,
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      }
    }

    // 3. Fallback
    return _buildFallback();
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColor ?? Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(fallbackIcon, color: Colors.deepPurple.shade200, size: size * 0.5),
    );
  }
}
