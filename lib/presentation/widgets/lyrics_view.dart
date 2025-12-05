import 'dart:ui';
import 'package:flutter/material.dart';
import '../../data/models/lyrics_model.dart';
import 'dart:async';

class LyricsView extends StatefulWidget {
  final Lyrics lyrics;
  final Duration currentPosition;
  final Function(Duration)? onSeek;
  final Function(Duration)? onOffsetChanged; // NEW: Callback for offset changes

  const LyricsView({super.key, required this.lyrics, required this.currentPosition, this.onSeek, this.onOffsetChanged});

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

    // CRITICAL: Only consider a line as "current" if we're actually close to it
    // This prevents marking lines as current when they're still far in the future
    if (newIndex >= 0 && newIndex < widget.lyrics.lines.length) {
      final line = widget.lyrics.lines[newIndex];
      final timeUntilLine = line.timestamp - widget.currentPosition;

      // If line is more than 5 seconds in the future, don't mark it as current yet
      // This handles edge case where getCurrentLineIndex returns too early
      if (timeUntilLine > const Duration(seconds: 5)) {
        // Keep previous line as current, or stay at -1
        return;
      }
    }

    // Only update and scroll if the line INDEX actually changed
    if (newIndex != _currentLineIndex && newIndex >= 0) {
      final oldIndex = _currentLineIndex;
      setState(() {
        _currentLineIndex = newIndex;
      });

      // Only auto-scroll if:
      // 1. User is not manually scrolling
      // 2. Line actually changed (not just position update)
      // 3. NOT in a long gap (smart gap detection)
      if (!_isUserScrolling && oldIndex != newIndex) {
        // Check if we should scroll or freeze (for long gaps)
        final shouldScroll = _shouldScrollToLine(oldIndex, newIndex);

        if (shouldScroll) {
          // Small delay to ensure the line is actually active and layout updated
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted && _currentLineIndex == newIndex) {
              _scrollToCurrentLine();
            }
          });
        }
      }
    }
  }

  // Smart logic to decide if we should scroll during line change
  bool _shouldScrollToLine(int oldIndex, int newIndex) {
    // Going backwards (seeking) - always scroll
    if (newIndex < oldIndex && oldIndex != -1) {
      return true;
    }

    // CRITICAL FIX: Check if we're actually CLOSE to the next line
    // Don't scroll if the next line is still far away in the future
    if (newIndex >= 0 && newIndex < widget.lyrics.lines.length) {
      final nextLine = widget.lyrics.lines[newIndex];
      final currentPosition = widget.currentPosition;

      // If next line is more than 3 seconds in the future, DON'T scroll yet
      // This handles long intros and gaps
      final timeUntilNextLine = nextLine.timestamp - currentPosition;
      if (timeUntilNextLine > const Duration(seconds: 3)) {
        return false; // Too early to scroll
      }
    }

    // Special handling for first line activation
    if (oldIndex == -1 && newIndex == 0) {
      // Check if first line starts much later (long intro)
      if (widget.lyrics.lines.isNotEmpty) {
        final firstLine = widget.lyrics.lines[0];
        final currentPosition = widget.currentPosition;

        // If we're activating first line but it's still >2 seconds away, wait
        final timeUntilFirstLine = firstLine.timestamp - currentPosition;
        if (timeUntilFirstLine > const Duration(seconds: 2)) {
          return false; // Long intro detected - don't scroll yet
        }
      }
      return true; // First line and we're close to it
    }

    // Check if there's a long gap between old and new line
    if (oldIndex >= 0 && oldIndex < widget.lyrics.lines.length) {
      final isLongGap = widget.lyrics.isLongGap(oldIndex);

      // If we're IN a long gap, check if we're actually close to next line
      if (isLongGap) {
        if (newIndex >= 0 && newIndex < widget.lyrics.lines.length) {
          final nextLine = widget.lyrics.lines[newIndex];
          final currentPosition = widget.currentPosition;

          // Only scroll if we're within 2 seconds of the next line
          final timeUntilNextLine = nextLine.timestamp - currentPosition;
          if (timeUntilNextLine > const Duration(seconds: 2)) {
            return false; // Still in gap, don't scroll
          }
        }
        return true; // Close to next line after gap, scroll now
      }
    }

    // Default: scroll normally for regular line changes
    return true;
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

        // Sync Offset Adjustment (Top)
        if (widget.onOffsetChanged != null)
          Positioned(
            top: 12,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.white.withOpacity(0.25), Colors.white.withOpacity(0.15)]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync, size: 16, color: Colors.white.withOpacity(0.9)),
                      const SizedBox(width: 8),
                      Text(
                        'Sync:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Decrease button
                      _buildOffsetButton(
                        icon: Icons.remove,
                        onTap: () {
                          final newOffset = widget.lyrics.syncOffset - const Duration(milliseconds: 500);
                          widget.onOffsetChanged!(newOffset);
                        },
                      ),
                      const SizedBox(width: 8),
                      // Offset display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${widget.lyrics.syncOffset.isNegative ? "-" : "+"}${(widget.lyrics.syncOffset.inMilliseconds.abs() / 1000).toStringAsFixed(1)}s',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Increase button
                      _buildOffsetButton(
                        icon: Icons.add,
                        onTap: () {
                          final newOffset = widget.lyrics.syncOffset + const Duration(milliseconds: 500);
                          widget.onOffsetChanged!(newOffset);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
    final isInstrumental = line.isInstrumental;
    final isDialogue = line.isDialogue;

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
                    if (isCurrentLine && !isInstrumental)
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
                            ? Colors.white.withOpacity(isInstrumental ? 0.2 : 0.25)
                            : Colors.white.withOpacity(isInstrumental ? 0.35 : 0.45),
                        fontWeight: isCurrentLine ? FontWeight.w700 : FontWeight.w400,
                        fontSize: isCurrentLine ? 24 : (isInstrumental ? 14 : 16),
                        fontStyle: (isInstrumental || isDialogue) ? FontStyle.italic : FontStyle.normal,
                        height: 1.5,
                        letterSpacing: isCurrentLine ? 0.3 : 0.1,
                        shadows: isCurrentLine
                            ? [const Shadow(blurRadius: 10, color: Colors.black, offset: Offset(0, 1))]
                            : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Music note icon for instrumental sections
                          if (isInstrumental && isCurrentLine) ...[
                            Icon(Icons.music_note_rounded, size: 18, color: Colors.white.withOpacity(0.6)),
                            const SizedBox(width: 8),
                          ],
                          Flexible(child: Text(line.text, textAlign: TextAlign.center)),
                          if (isInstrumental && isCurrentLine) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.music_note_rounded, size: 18, color: Colors.white.withOpacity(0.6)),
                          ],
                        ],
                      ),
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

  // Helper method to build offset adjustment buttons
  Widget _buildOffsetButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}
