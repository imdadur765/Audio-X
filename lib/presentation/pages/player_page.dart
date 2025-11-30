import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/song_model.dart';
import '../../data/models/lyrics_model.dart';
import '../../services/lyrics_service.dart';
import '../controllers/audio_controller.dart';
import '../widgets/lyrics_view.dart';
import 'equalizer_page.dart';

class PlayerPage extends StatefulWidget {
  final Song song;

  const PlayerPage({super.key, required this.song});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final LyricsService _lyricsService = LyricsService();
  Lyrics? _lyrics;
  bool _showLyrics = false;
  bool _isLoadingLyrics = false;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  Future<void> _loadLyrics() async {
    setState(() {
      _isLoadingLyrics = true;
    });

    try {
      final lyrics = await _lyricsService.getLyrics(
        songId: widget.song.id,
        title: widget.song.title,
        artist: widget.song.artist,
        album: widget.song.album,
        durationSeconds: widget.song.duration ~/ 1000,
        manualLyricsPath: widget.song.lyricsPath,
      );

      if (mounted) {
        setState(() {
          _lyrics = lyrics;
          _isLoadingLyrics = false;
        });
      }
    } catch (e) {
      print('Error loading lyrics: $e');
      if (mounted) {
        setState(() {
          _isLoadingLyrics = false;
        });
      }
    }
  }

  Future<void> _pickLyricsFile() async {
    final path = await _lyricsService.pickLRCFile();
    if (path != null && mounted) {
      widget.song.lyricsPath = path;
      widget.song.lyricsSource = 'manual';
      await widget.song.save();
      _loadLyrics();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Lyrics file loaded!')));
    }
  }

  Future<void> _searchOnline() async {
    setState(() {
      _isLoadingLyrics = true;
    });

    await _lyricsService.deleteCachedLyrics(widget.song.id);

    final lyrics = await _lyricsService.fetchFromLRCLIB(
      title: widget.song.title,
      artist: widget.song.artist,
      album: widget.song.album,
      durationSeconds: widget.song.duration ~/ 1000,
    );

    if (lyrics != null && mounted) {
      final lrcString = lyrics.lines.map((line) => line.toString()).join('\n');
      await _lyricsService.saveLRCFile(widget.song.id, lrcString);

      setState(() {
        _lyrics = lyrics;
        _isLoadingLyrics = false;
        // Don't auto-switch to lyrics - let user tap the icon
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Found ${lyrics.lines.length} lyrics lines! Tap lyrics icon to view'),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      if (mounted) {
        setState(() {
          _isLoadingLyrics = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('❌ Lyrics not found. Try uploading .lrc file')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => Navigator.of(context).pop()),
        actions: [
          // Lyrics toggle button - only show if lyrics available
          if (_lyrics != null && !_isLoadingLyrics)
            IconButton(
              icon: Icon(_showLyrics ? Icons.album : Icons.lyrics, color: Theme.of(context).primaryColor),
              tooltip: _showLyrics ? 'Show Album Art' : 'Show Lyrics',
              onPressed: () {
                setState(() {
                  _showLyrics = !_showLyrics;
                });
              },
            ),

          // 3-dot menu
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'upload':
                  await _pickLyricsFile();
                  break;
                case 'search':
                  await _searchOnline();
                  break;
                case 'equalizer':
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => const EqualizerPage()));
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'upload',
                child: Row(children: [Icon(Icons.upload_file), SizedBox(width: 12), Text('Upload .lrc file')]),
              ),
              const PopupMenuItem(
                value: 'search',
                child: Row(children: [Icon(Icons.search), SizedBox(width: 12), Text('Search lyrics online')]),
              ),
              const PopupMenuItem(
                value: 'equalizer',
                child: Row(children: [Icon(Icons.equalizer), SizedBox(width: 12), Text('Equalizer')]),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<AudioController>(
        builder: (context, controller, child) {
          final currentSong = controller.currentSong ?? widget.song;

          return Column(
            children: [
              // Main content area (Album Art OR Lyrics)
              Expanded(
                child: _showLyrics && _lyrics != null
                    ? LyricsView(
                        lyrics: _lyrics!,
                        currentPosition: controller.position,
                        onSeek: (position) => controller.seek(position),
                      )
                    : _buildAlbumArtSection(currentSong),
              ),

              // Player controls section
              _buildPlayerControls(controller),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAlbumArtSection(Song currentSong) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Artwork
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.grey[200],
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: currentSong.localArtworkPath != null
                  ? Image.file(File(currentSong.localArtworkPath!), fit: BoxFit.cover)
                  : const Icon(Icons.music_note, size: 100, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 40),

          // Title & Artist
          Text(
            currentSong.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            currentSong.artist,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerControls(AudioController controller) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress Bar
          Slider(
            value: controller.position.inSeconds.toDouble().clamp(0.0, controller.duration.inSeconds.toDouble()),
            max: controller.duration.inSeconds.toDouble() > 0 ? controller.duration.inSeconds.toDouble() : 1.0,
            onChanged: (value) {
              controller.seek(Duration(seconds: value.toInt()));
            },
            activeColor: Theme.of(context).primaryColor,
            inactiveColor: Colors.grey[300],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(_formatDuration(controller.position)), Text(_formatDuration(controller.duration))],
            ),
          ),
          const SizedBox(height: 20),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(
                  Icons.shuffle,
                  color: controller.isShuffleEnabled ? Theme.of(context).primaryColor : Colors.grey,
                ),
                onPressed: controller.toggleShuffle,
              ),
              IconButton(icon: const Icon(Icons.skip_previous, size: 40), onPressed: controller.previous),
              Container(
                decoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
                child: IconButton(
                  icon: Icon(controller.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 40),
                  onPressed: () {
                    if (controller.isPlaying) {
                      controller.pause();
                    } else {
                      controller.resume();
                    }
                  },
                ),
              ),
              IconButton(icon: const Icon(Icons.skip_next, size: 40), onPressed: controller.next),
              IconButton(
                icon: Icon(
                  controller.repeatMode == 1 ? Icons.repeat_one : Icons.repeat,
                  color: controller.repeatMode > 0 ? Theme.of(context).primaryColor : Colors.grey,
                ),
                onPressed: controller.toggleRepeat,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
