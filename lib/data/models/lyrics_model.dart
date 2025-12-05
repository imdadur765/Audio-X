class LyricsLine {
  final Duration timestamp;
  final String text;
  final bool isInstrumental;
  final bool isDialogue;

  LyricsLine({required this.timestamp, required this.text, this.isInstrumental = false, this.isDialogue = false});

  @override
  String toString() => '[${_formatTimestamp(timestamp)}] $text';

  String _formatTimestamp(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final centiseconds = ((duration.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds.$centiseconds';
  }
}

class Lyrics {
  final String source; // 'lrclib', 'manual', 'none'
  final List<LyricsLine> lines;
  final String? attribution;
  final String? plainLyrics; // Fallback for non-synced lyrics
  final Duration syncOffset; // User-adjustable timing offset

  Lyrics({
    required this.source,
    required this.lines,
    this.attribution,
    this.plainLyrics,
    this.syncOffset = Duration.zero,
  });

  factory Lyrics.empty() {
    return Lyrics(source: 'none', lines: [], attribution: null, plainLyrics: null);
  }

  factory Lyrics.fromLRCLIB(Map<String, dynamic> json) {
    final syncedLyrics = json['syncedLyrics'] as String?;
    final plainLyrics = json['plainLyrics'] as String?;

    if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
      return Lyrics(
        source: 'lrclib',
        lines: _parseLRC(syncedLyrics),
        attribution: 'Lyrics provided by LRCLIB.net community',
        plainLyrics: plainLyrics,
      );
    } else if (plainLyrics != null && plainLyrics.isNotEmpty) {
      return Lyrics(
        source: 'lrclib',
        lines: _convertPlainToLines(plainLyrics),
        attribution: 'Lyrics provided by LRCLIB.net community',
        plainLyrics: plainLyrics,
      );
    } else {
      return Lyrics.empty();
    }
  }

  factory Lyrics.fromLRCString(String lrcContent, {String source = 'manual'}) {
    return Lyrics(
      source: source,
      lines: _parseLRC(lrcContent),
      attribution: source == 'manual' ? 'User-provided lyrics' : null,
    );
  }

  static List<LyricsLine> _parseLRC(String lrcContent) {
    final lines = <LyricsLine>[];
    // Support both [mm:ss.xx] and [mm:ss.xxx] formats
    final regex = RegExp(r'\[(\d+):(\d+)\.(\d+)\](.*)');

    for (var line in lrcContent.split('\n')) {
      final match = regex.firstMatch(line.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        var millisecondsStr = match.group(3)!;
        final text = match.group(4)!.trim();

        // Handle both centiseconds (xx) and milliseconds (xxx)
        int milliseconds;
        if (millisecondsStr.length == 2) {
          // Centiseconds format: convert to milliseconds
          milliseconds = int.parse(millisecondsStr) * 10;
        } else if (millisecondsStr.length == 3) {
          // Direct milliseconds
          milliseconds = int.parse(millisecondsStr);
        } else {
          // Pad or truncate to 3 digits
          millisecondsStr = millisecondsStr.padRight(3, '0').substring(0, 3);
          milliseconds = int.parse(millisecondsStr);
        }

        if (text.isNotEmpty) {
          final timestamp = Duration(minutes: minutes, seconds: seconds, milliseconds: milliseconds);

          // Auto-detect instrumental sections
          final isInstrumental = _detectInstrumental(text);

          // Auto-detect dialogue sections
          final isDialogue = _detectDialogue(text);

          lines.add(
            LyricsLine(timestamp: timestamp, text: text, isInstrumental: isInstrumental, isDialogue: isDialogue),
          );
        }
      }
    }

    // Sort by timestamp
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  // Detect instrumental sections
  static bool _detectInstrumental(String text) {
    final lowerText = text.toLowerCase();

    // Check for common instrumental markers
    final instrumentalKeywords = [
      '♪',
      '♫',
      'instrumental',
      '[instrumental]',
      '(instrumental)',
      '[music]',
      '(music)',
      '[guitar solo]',
      '[piano solo]',
      '[drum solo]',
      '[solo]',
      '[bridge]',
      '[interlude]',
      '[break]',
      'guitar solo',
      'piano solo',
      'drum solo',
      'saxophone solo',
      'music',
    ];

    return instrumentalKeywords.any((keyword) => lowerText.contains(keyword));
  }

  // Detect dialogue/spoken word sections
  static bool _detectDialogue(String text) {
    final lowerText = text.toLowerCase();

    // Check for dialogue markers
    final dialogueKeywords = ['(spoken)', '[spoken]', '(dialogue)', '[dialogue]', '(speech)', '[speech]'];

    // Check if entire line is in CAPS (common for dialogue)
    final isAllCaps = text == text.toUpperCase() && text != text.toLowerCase() && text.length > 3;

    return dialogueKeywords.any((keyword) => lowerText.contains(keyword)) || isAllCaps;
  }

  static List<LyricsLine> _convertPlainToLines(String plainLyrics) {
    // For plain lyrics without timestamps, create dummy timestamps
    final lines = <LyricsLine>[];
    var index = 0;
    for (var line in plainLyrics.split('\n')) {
      if (line.trim().isNotEmpty) {
        lines.add(
          LyricsLine(
            timestamp: Duration(seconds: index * 5), // Dummy timestamps
            text: line.trim(),
          ),
        );
        index++;
      }
    }
    return lines;
  }

  // Get the current line index based on playback position
  int getCurrentLineIndex(Duration position) {
    if (lines.isEmpty) return -1;

    // Apply user-defined sync offset
    final adjustedPosition = position + syncOffset;

    // Find the line whose timestamp has passed
    for (var i = lines.length - 1; i >= 0; i--) {
      if (adjustedPosition >= lines[i].timestamp) {
        return i;
      }
    }

    // Special case: If no line timestamp has passed yet, check if first line is coming soon
    // Don't activate the first line if it's too far in the future (long intro)
    if (lines.isNotEmpty) {
      final firstLine = lines[0];
      final timeUntilFirstLine = firstLine.timestamp - adjustedPosition;

      // Only activate first line if we're within 10 seconds of it
      // This prevents early activation during long intros
      if (timeUntilFirstLine <= const Duration(seconds: 10) && timeUntilFirstLine >= Duration.zero) {
        return 0; // Close enough to first line
      }
    }

    return -1; // No active line yet
  }

  // Get next line after current index
  LyricsLine? getNextLine(int currentIndex) {
    if (currentIndex == -1 || currentIndex >= lines.length - 1) return null;
    return lines[currentIndex + 1];
  }

  // Get duration gap between current line and next line
  Duration? getGapToNextLine(int currentIndex) {
    if (currentIndex == -1 || currentIndex >= lines.length - 1) return null;

    final current = lines[currentIndex];
    final next = lines[currentIndex + 1];

    return next.timestamp - current.timestamp;
  }

  // Check if gap to next line is long (>5 seconds = instrumental break likely)
  bool isLongGap(int currentIndex, {Duration threshold = const Duration(seconds: 5)}) {
    final gap = getGapToNextLine(currentIndex);
    if (gap == null) return false;
    return gap > threshold;
  }

  // Create a copy with updated sync offset
  Lyrics copyWith({Duration? syncOffset}) {
    return Lyrics(
      source: source,
      lines: lines,
      attribution: attribution,
      plainLyrics: plainLyrics,
      syncOffset: syncOffset ?? this.syncOffset,
    );
  }

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;
  bool get isSynced => source != 'none' && lines.isNotEmpty;
}
