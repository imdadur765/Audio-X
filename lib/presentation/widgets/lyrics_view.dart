import 'package:flutter/material.dart';
import '../../data/models/lyrics_model.dart';
import 'dart:async';

class LyricsView extends StatefulWidget {
  final Lyrics lyrics;
  final Duration currentPosition;
  final Function(Duration)? onSeek;

  const LyricsView({super.key, required this.lyrics, required this.currentPosition, this.onSeek});

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  int _currentLineIndex = -1;

  @override
  void initState() {
    super.initState();
    _updateCurrentLine();
  }

  @override
  void didUpdateWidget(LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPosition != oldWidget.currentPosition) {
      _updateCurrentLine();
    }
  }

  void _updateCurrentLine() {
    final newIndex = widget.lyrics.getCurrentLineIndex(widget.currentPosition);
    if (newIndex != _currentLineIndex) {
      setState(() {
        _currentLineIndex = newIndex;
      });
      _scrollToCurrentLine();
    }
  }

  void _scrollToCurrentLine() {
    if (_currentLineIndex >= 0 && _scrollController.hasClients) {
      // Calculate offset to center the current line
      final itemHeight = 60.0; // Approximate height of each line
      final offset = (_currentLineIndex * itemHeight) - (MediaQuery.of(context).size.height / 3);

      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyrics.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Attribution
        if (widget.lyrics.attribution != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              widget.lyrics.attribution!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),

        // Lyrics Lines
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 40),
            itemCount: widget.lyrics.lines.length,
            itemBuilder: (context, index) {
              return _buildLyricLine(index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLyricLine(int index) {
    final line = widget.lyrics.lines[index];
    final isCurrentLine = index == _currentLineIndex;
    final isPastLine = index < _currentLineIndex;

    return InkWell(
      onTap: widget.onSeek != null ? () => widget.onSeek!(line.timestamp) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Text(
          line.text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: isCurrentLine
                ? Theme.of(context).colorScheme.primary
                : isPastLine
                ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: isCurrentLine ? FontWeight.bold : FontWeight.normal,
            fontSize: isCurrentLine ? 20 : 16,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lyrics_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Lyrics Available',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Try uploading your own .lrc file\nor search online',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
