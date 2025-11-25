class LyricsLine {
  final Duration timestamp;
  final String text;

  LyricsLine({
    required this.timestamp,
    required this.text,
  });

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

  Lyrics({
    required this.source,
    required this.lines,
    this.attribution,
    this.plainLyrics,
  });

  factory Lyrics.empty() {
    return Lyrics(
      source: 'none',
      lines: [],
      attribution: null,
      plainLyrics: null,
    );
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
    final regex = RegExp(r'\[(\d+):(\d+)\.(\d+)\](.*)');

    for (var line in lrcContent.split('\n')) {
      final match = regex.firstMatch(line.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final centiseconds = int.parse(match.group(3)!);
        final text = match.group(4)!.trim();

        if (text.isNotEmpty) {
          final timestamp = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: centiseconds * 10,
          );
          lines.add(LyricsLine(timestamp: timestamp, text: text));
        }
      }
    }

    // Sort by timestamp
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  static List<LyricsLine> _convertPlainToLines(String plainLyrics) {
    // For plain lyrics without timestamps, create dummy timestamps
    final lines = <LyricsLine>[];
    var index = 0;
    for (var line in plainLyrics.split('\n')) {
      if (line.trim().isNotEmpty) {
        lines.add(LyricsLine(
          timestamp: Duration(seconds: index * 5), // Dummy timestamps
          text: line.trim(),
        ));
        index++;
      }
    }
    return lines;
  }

  // Get the current line index based on playback position
  int getCurrentLineIndex(Duration position) {
    if (lines.isEmpty) return -1;

    for (var i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].timestamp) {
        return i;
      }
    }
    return -1;
  }

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;
  bool get isSynced => source != 'none' && lines.isNotEmpty;
}
