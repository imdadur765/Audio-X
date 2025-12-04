import 'dart:ui';
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

class _LyricsViewState extends State<LyricsView> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  int _currentLineIndex = -1;
  late AnimationController _glowController;
  bool _isUserScrolling = false;
  Timer? _scrollResumeTimer;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);

    // Create keys for each line to measure their actual height
    for (int i = 0; i < widget.lyrics.lines.length; i++) {
      _lineKeys[i] = GlobalKey();
    }

    // Listen for user scrolling to pause auto-scroll
    _scrollController.addListener(_onUserScroll);

    // Initial setup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _updateCurrentLine();
      }
    });
  }

  void _onUserScroll() {
    if (_scrollController.hasClients && _scrollController.position.isScrollingNotifier.value) {
      if (!_isUserScrolling) {
        setState(() {
          _isUserScrolling = true;
        });
      }

      // Cancel previous timer
      _scrollResumeTimer?.cancel();

      // Resume auto-scroll after 3 seconds of no activity
      _scrollResumeTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isUserScrolling = false;
          });
          _scrollToCurrentLine(force: true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPosition != oldWidget.currentPosition) {
      _updateCurrentLine();
    }
  }

  void _updateCurrentLine() {
    if (!_isInitialized) return;

    final newIndex = widget.lyrics.getCurrentLineIndex(widget.currentPosition);

    // Only update and scroll if the line INDEX actually changed
    if (newIndex != _currentLineIndex && newIndex >= 0) {
      final oldIndex = _currentLineIndex;
      setState(() {
        _currentLineIndex = newIndex;
      });

      // Only auto-scroll if:
      // 1. User is not manually scrolling
      // 2. Line actually changed (not just position update)
      if (!_isUserScrolling && oldIndex != newIndex) {
        // Small delay to ensure the line is actually active and layout updated
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && _currentLineIndex == newIndex) {
            _scrollToCurrentLine();
          }
        });
      }
    }
  }

  void _scrollToCurrentLine({bool force = false}) {
    if (_currentLineIndex < 0 || !_scrollController.hasClients || !mounted) return;

    // Double frame callback ensures current line renders at full size (expanded font) first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;

        try {
          final viewportHeight = _scrollController.position.viewportDimension;
          final maxScrollExtent = _scrollController.position.maxScrollExtent;

          // If all lyrics fit on screen, no need to scroll
          if (maxScrollExtent <= 0) {
            return;
          }

          // Calculate accumulated height of all lines BEFORE current line
          double accumulatedHeight = 0;

          for (int i = 0; i < _currentLineIndex; i++) {
            final key = _lineKeys[i];
            double lineHeight = 60; // Default fallback

            if (key?.currentContext != null) {
              try {
                final RenderBox? box = key!.currentContext!.findRenderObject() as RenderBox?;
                if (box != null && box.hasSize) {
                  lineHeight = box.size.height + 12; // Add margin
                }
              } catch (e) {
                // Use fallback
              }
            }

            accumulatedHeight += lineHeight;
          }

          // Get CURRENT line's height
          double currentLineHeight = 90;
          final currentKey = _lineKeys[_currentLineIndex];
          if (currentKey?.currentContext != null) {
            try {
              final RenderBox? box = currentKey!.currentContext!.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) {
                currentLineHeight = box.size.height + 12; // Add margin
              }
            } catch (e) {
              // Use fallback
            }
          }

          // Target: Keep current line at 40% of viewport (slightly above center)
          final highlightPosition = viewportHeight * 0.40;

          // Calculate target offset
          double targetOffset = accumulatedHeight - highlightPosition + (currentLineHeight / 2);

          // Smart clamping
          if (targetOffset < 0) {
            targetOffset = 0;
          } else if (targetOffset > maxScrollExtent) {
            targetOffset = maxScrollExtent;
          }

          // Only scroll if difference is significant (avoid micro-scrolls)
          if ((targetOffset - _scrollController.offset).abs() > 5 || force) {
            _scrollController.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
            );
          }
        } catch (e) {
          print('Scroll error: $e');
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onUserScroll);
    _scrollController.dispose();
    _glowController.dispose();
    _scrollResumeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyrics.isEmpty) {
      return _buildEmptyState();
    }

    return Stack(
      children: [
        // Lyrics List
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
          physics: const ClampingScrollPhysics(),
          itemCount: widget.lyrics.lines.length,
          itemBuilder: (context, index) {
            return _buildLyricLine(index);
          },
        ),

        // Attribution at bottom
        if (widget.lyrics.attribution != null)
          Positioned(
            bottom: 12,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_note_rounded, size: 12, color: Colors.white.withOpacity(0.5)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.lyrics.attribution!,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.5),
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLyricLine(int index) {
    final line = widget.lyrics.lines[index];
    final isCurrentLine = index == _currentLineIndex;
    final isPastLine = index < _currentLineIndex;
    final isFutureLine = index > _currentLineIndex;

    return GestureDetector(
      key: _lineKeys[index],
      onTap: widget.onSeek != null
          ? () {
              // Haptic feedback could be added here
              widget.onSeek!(line.timestamp);
            }
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: isCurrentLine
                  ? ImageFilter.blur(sigmaX: 20, sigmaY: 20)
                  : isFutureLine
                  ? ImageFilter.blur(sigmaX: 5, sigmaY: 5)
                  : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isCurrentLine ? 24 : 16, vertical: isCurrentLine ? 16 : 10),
                decoration: BoxDecoration(
                  gradient: isCurrentLine
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white.withOpacity(0.22), Colors.white.withOpacity(0.12)],
                        )
                      : isFutureLine
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(18),
                  border: isCurrentLine ? Border.all(color: Colors.white.withOpacity(0.3), width: 1.5) : null,
                  boxShadow: isCurrentLine
                      ? [BoxShadow(color: Colors.white.withOpacity(0.15), blurRadius: 25, spreadRadius: 3)]
                      : null,
                ),
                child: Stack(
                  children: [
                    // Pulsating glow for current line
                    if (isCurrentLine)
                      AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: 0.3 + (_glowController.value * 0.2),
                            child: Text(
                              line.text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 24,
                                height: 1.5,
                                letterSpacing: 0.3,
                                shadows: [Shadow(blurRadius: 30, color: Colors.white.withOpacity(0.5))],
                              ),
                            ),
                          );
                        },
                      ),

                    // Main text with dynamic styling
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 350),
                      style: TextStyle(
                        color: isCurrentLine
                            ? Colors.white
                            : isPastLine
                            ? Colors.white.withOpacity(0.25)
                            : Colors.white.withOpacity(0.45),
                        fontWeight: isCurrentLine ? FontWeight.w700 : FontWeight.w400,
                        fontSize: isCurrentLine ? 24 : 16,
                        height: 1.5,
                        letterSpacing: isCurrentLine ? 0.3 : 0.1,
                        shadows: isCurrentLine
                            ? [const Shadow(blurRadius: 10, color: Colors.black, offset: Offset(0, 1))]
                            : [],
                      ),
                      child: Text(line.text, textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.08)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.lyrics_outlined, size: 48, color: Colors.white.withOpacity(0.6)),
                ),
                const SizedBox(height: 20),
                Text(
                  'No Lyrics Available',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Lyrics not found for this track',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
