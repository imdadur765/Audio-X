import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/song_model.dart';
import '../../services/playlist_service.dart';
import '../controllers/audio_controller.dart';
import '../widgets/more_options_button.dart';
import '../widgets/glass_background.dart';

class PlaylistDetailsPage extends StatefulWidget {
  final String playlistId;
  final String title;
  final List<Song> songs;
  final List<Color> gradientColors;
  final bool isAuto;

  const PlaylistDetailsPage({
    super.key,
    this.playlistId = '',
    required this.title,
    required this.songs,
    required this.gradientColors,
    this.isAuto = false,
  });

  @override
  State<PlaylistDetailsPage> createState() => _PlaylistDetailsPageState();
}

class _PlaylistDetailsPageState extends State<PlaylistDetailsPage> {
  final PlaylistService _playlistService = PlaylistService();
  late List<Song> _songs;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _songs = widget.songs;
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _removeSongFromPlaylist(Song song) async {
    if (widget.isAuto) return;

    await _playlistService.removeSongFromPlaylist(widget.playlistId, song.id);

    setState(() {
      _songs.removeWhere((s) => s.id == song.id);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${song.title}"'),
          backgroundColor: Colors.deepPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _deletePlaylist() async {
    if (widget.isAuto) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
        ),
        title: Text('Delete Playlist?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'Are you sure you want to delete "${widget.title}"? This action cannot be undone.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _playlistService.deletePlaylist(widget.playlistId);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioController = Provider.of<AudioController>(context);
    final accentColor = widget.gradientColors.isNotEmpty ? widget.gradientColors.first : audioController.accentColor;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Adaptive Glass Background
          GlassBackground(
            // Using first song artwork if available, otherwise generic
            artworkPath: _songs.isNotEmpty ? _songs.first.localArtworkPath : null,
            accentColor: accentColor,
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),

          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildHeader(accentColor),
              _buildPlaylistStats(),
              _buildControls(audioController, accentColor),
              _buildSongsList(audioController, accentColor),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color accentColor) {
    final opacity = (_scrollOffset / 200).clamp(0.0, 1.0);

    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: opacity > 0.8
          ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.8)
          : Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (!widget.isAuto)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/images/more.png',
                width: 24,
                height: 24,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            onPressed: _deletePlaylist, // Currently only option is delete
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: opacity,
          child: Text(
            widget.title,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accentColor.withValues(alpha: 0.6),
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.4),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: widget.gradientColors),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: accentColor.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: Center(
                  child: Image.asset('assets/images/playlist_open.png', width: 60, height: 60, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: 1.0 - opacity, // Fade out on scroll
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistStats() {
    final totalDuration = _songs.fold(Duration.zero, (sum, song) => sum + Duration(milliseconds: song.duration));
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);
    final durationText = hours > 0 ? '$hours hr $minutes min' : '$minutes min';

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            '${_songs.length} songs • $durationText',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(AudioController audioController, Color accentColor) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _songs.isEmpty ? null : () => audioController.playSongList(_songs, 0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 28),
                    SizedBox(width: 8),
                    Text('Play All', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: IconButton(
                onPressed: _songs.isEmpty ? null : () => audioController.playSongList(_songs, 0, shuffle: true),
                icon: Image.asset(
                  'assets/images/shuffle.png',
                  width: 24,
                  height: 24,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongsList(AudioController audioController, Color accentColor) {
    if (_songs.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/playlist_open.png',
                width: 64,
                height: 64,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
              ),
              const SizedBox(height: 16),
              Text(
                'No songs yet',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final song = _songs[index];
        final isPlaying = audioController.currentSong?.id == song.id && audioController.isPlaying;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isPlaying ? accentColor.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isPlaying ? Border.all(color: accentColor.withValues(alpha: 0.2)) : null,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.only(left: 8, right: 8),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: song.localArtworkPath != null
                    ? DecorationImage(image: FileImage(File(song.localArtworkPath!)), fit: BoxFit.cover)
                    : null,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
              ),
              child: song.localArtworkPath == null
                  ? Center(
                      child: Image.asset(
                        'assets/images/song.png',
                        width: 24,
                        height: 24,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                      ),
                    )
                  : null,
            ),
            title: Text(
              song.title,
              style: TextStyle(
                color: isPlaying ? accentColor : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              song.artist,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: MoreOptionsButton(
              song: song,
              trailing: !widget.isAuto
                  ? IconButton(
                      icon: Image.asset(
                        'assets/images/delete.png',
                        width: 20,
                        height: 20,
                        color: Colors.red.withValues(alpha: 0.7),
                      ),
                      onPressed: () => _removeSongFromPlaylist(song),
                    )
                  : null,
            ),
            onTap: () => audioController.playSongList(_songs, index),
          ),
        );
      }, childCount: _songs.length),
    );
  }
}
