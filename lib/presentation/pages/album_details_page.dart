import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/song_model.dart';
import '../controllers/audio_controller.dart';
import '../widgets/hybrid_song_artwork.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/glass_button.dart';

import '../widgets/glass_background.dart';

class AlbumDetailsPage extends StatefulWidget {
  final String albumName;
  final List<Song> songs;
  final String? heroTag;

  const AlbumDetailsPage({super.key, required this.albumName, required this.songs, this.heroTag});

  @override
  State<AlbumDetailsPage> createState() => _AlbumDetailsPageState();
}

class _AlbumDetailsPageState extends State<AlbumDetailsPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animationController.forward();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _artistName {
    // Get the most common artist from songs
    if (widget.songs.isEmpty) return 'Unknown Artist';
    final artistCounts = <String, int>{};
    for (final song in widget.songs) {
      artistCounts[song.artist] = (artistCounts[song.artist] ?? 0) + 1;
    }
    return artistCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  int get _totalDuration {
    return widget.songs.fold(0, (sum, song) => sum + song.duration);
  }

  Widget? get _albumArtwork {
    final firstSong = widget.songs.firstOrNull;
    if (firstSong?.localArtworkPath != null) {
      return Image.file(File(firstSong!.localArtworkPath!), fit: BoxFit.cover);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Standardize opacity logic (0 to 1 based on scroll)
    final opacity = (_scrollOffset / 200).clamp(0.0, 1.0);
    // Dark glass background
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Dark Glass Background (consitent with Home/Artist)
          GlassBackground(
            artworkPath: widget.songs.firstOrNull?.localArtworkPath,
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),

          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                stretch: true,
                backgroundColor: opacity > 0.8
                    ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.8)
                    : Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Image.asset(
                    'assets/images/back.png',
                    width: 24,
                    height: 24,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Image.asset(
                      'assets/images/more.png',
                      width: 24,
                      height: 24,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: _showOptionsMenu,
                  ),
                ],
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: opacity * 20, sigmaY: opacity * 20),
                    child: FlexibleSpaceBar(
                      title: AnimatedOpacity(
                        opacity: opacity,
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          widget.albumName,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_albumArtwork != null) _albumArtwork! else Container(color: Colors.deepPurple.shade900),

                          // Gradient Overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                          ),

                          // Content (Album Art + Info when expanded)
                          // We can hide this when collapsed using Opacity
                          Opacity(
                            opacity: (1.0 - opacity * 1.5).clamp(0.0, 1.0),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 60),
                              child: Center(child: _buildAlbumArtSection()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildAlbumInfo(),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                    const SizedBox(height: 24),
                    _buildTrackList(),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Removed _buildAppBar as it is replaced by SliverAppBar

  Widget _buildAlbumArtSection() {
    return Hero(
      tag: widget.heroTag ?? 'album_${widget.albumName}',
      child: Container(
        width: 280,
        height: 280,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.3),
              blurRadius: 40,
              spreadRadius: 5,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child:
              _albumArtwork ??
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.deepPurple.shade300, Colors.purple.shade400],
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/album.png',
                    width: 100,
                    height: 100,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildAlbumInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            widget.albumName,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              shadows: [
                Shadow(
                  offset: Offset(0, 2),
                  blurRadius: 4,
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.5),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              context.pushNamed('artist_details', pathParameters: {'name': _artistName});
            },
            child: Text(
              _artistName,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildInfoChip(icon: 'assets/images/song.png', text: '${widget.songs.length} songs'),
              const SizedBox(width: 12),
              _buildInfoChip(icon: 'assets/images/duration.png', text: _formatTotalDuration(_totalDuration)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required String icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            icon,
            width: 16,
            height: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _addToPlaylist() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AddToPlaylistSheet(songs: widget.songs),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildGlassButton(
              text: 'Play All',
              iconPath: 'assets/images/play.png',
              onTap: _playAll,
              isPrimary: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildGlassButton(
              text: 'Shuffle',
              iconPath: 'assets/images/shuffle.png',
              onTap: _shuffleAll,
              isPrimary: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildGlassButton(
              text: 'Add',
              iconPath: 'assets/images/playlist_open.png',
              onTap: _addToPlaylist,
              isPrimary: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required String text,
    required String iconPath,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: isPrimary
                  ? Colors.deepPurple.withValues(alpha: 0.8)
                  : Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPrimary ? Colors.transparent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isPrimary
                      ? Colors.deepPurple.withValues(alpha: 0.3)
                      : Theme.of(context).shadowColor.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  iconPath,
                  width: 24,
                  height: 24,
                  color: isPrimary ? Colors.white : Theme.of(context).colorScheme.onSurface,
                ),
                if (isPrimary) ...[
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: TextStyle(
                      color: isPrimary ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackList() {
    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Tracks',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...widget.songs.asMap().entries.map((entry) {
              final index = entry.key;
              final song = entry.value;
              final isCurrentlyPlaying = audioController.currentSong?.id == song.id;
              final isPlaying = isCurrentlyPlaying && audioController.isPlaying;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrentlyPlaying
                      ? Colors.deepPurple.withValues(alpha: 0.3)
                      : Theme.of(context).colorScheme.surface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCurrentlyPlaying ? Colors.deepPurple.withValues(alpha: 0.5) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _playSong(index),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Album artwork thumbnail with track number
                          Stack(
                            children: [
                              HybridSongArtwork.fromSong(song: song, size: 48, borderRadius: 8),
                              // Track number overlay or playing indicator
                              if (isPlaying)
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Image.asset(
                                      'assets/images/equalizer.png',
                                      width: 20,
                                      height: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              else if (isCurrentlyPlaying)
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Image.asset(
                                      'assets/images/pause.png',
                                      width: 24,
                                      height: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              else
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          // Song info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isCurrentlyPlaying
                                        ? Colors.deepPurple.shade100
                                        : Theme.of(context).colorScheme.onSurface,
                                    fontWeight: isCurrentlyPlaying ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isCurrentlyPlaying
                                        ? Colors.deepPurple.shade200
                                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Duration
                          Text(
                            _formatDuration(song.duration),
                            style: TextStyle(
                              color: isCurrentlyPlaying
                                  ? Colors.deepPurple.shade100
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              fontWeight: isCurrentlyPlaying ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void _playAll() {
    if (widget.songs.isEmpty) return;
    final controller = Provider.of<AudioController>(context, listen: false);
    controller.playSong(widget.songs.first);
    context.pushNamed('player', extra: {'song': widget.songs.first, 'heroTag': 'album_song_${widget.songs.first.id}'});
  }

  void _shuffleAll() {
    if (widget.songs.isEmpty) return;
    final controller = Provider.of<AudioController>(context, listen: false);
    final shuffled = List<Song>.from(widget.songs)..shuffle();
    controller.playSong(shuffled.first);
    context.pushNamed('player', extra: {'song': shuffled.first, 'heroTag': 'album_song_${shuffled.first.id}'});
  }

  void _playSong(int index) {
    final song = widget.songs[index];
    final controller = Provider.of<AudioController>(context, listen: false);

    // Only play if it's a NEW song. If it's the SAME song, just open player.
    if (controller.currentSong?.id != song.id) {
      controller.playSongList(widget.songs, index);
    }
    context.pushNamed('player', extra: {'song': song, 'heroTag': 'album_song_${song.id}'});
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatTotalDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours hr $minutes min';
    }
    return '$minutes min';
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                // Header with Album Art
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).shadowColor.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child:
                              _albumArtwork ??
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Colors.deepPurple.shade700, Colors.purple.shade900],
                                  ),
                                ),
                                child: Image.asset(
                                  'assets/images/album.png',
                                  width: 28,
                                  height: 28,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.albumName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _artistName,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                // Options
                _buildOptionTile(
                  iconPath: 'assets/images/playlist_open.png',
                  title: 'Add to Playlist',
                  onTap: () {
                    Navigator.pop(context);
                    _addToPlaylist();
                  },
                ),
                _buildOptionTile(
                  iconPath: 'assets/images/share.png',
                  title: 'Share Album',
                  onTap: () async {
                    Navigator.pop(context);
                    final firstSong = widget.songs.firstOrNull;
                    final path = firstSong?.localArtworkPath;
                    final text =
                        '🎵 Check out this album on Audio X!\n\nAlbum: ${widget.albumName}\nArtist: $_artistName\n\n#AudioX #Music';

                    if (path != null && File(path).existsSync()) {
                      await Share.shareXFiles([XFile(path)], text: text);
                    } else {
                      await Share.share(text);
                    }
                  },
                ),
                _buildOptionTile(
                  iconPath: 'assets/images/info.png',
                  title: 'Album Info',
                  onTap: () {
                    Navigator.pop(context);
                    context.pushNamed(
                      'album_info',
                      extra: {'albumName': widget.albumName, 'artistName': _artistName, 'albumArt': _albumArtwork},
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({required String iconPath, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Image.asset(iconPath, width: 24, height: 24, color: Theme.of(context).colorScheme.onSurface),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
