/// Minimal SRT / WebVTT parser for the subtitle overlay.
class SubCue {
  final Duration start;
  final Duration end;
  final String text;
  const SubCue(this.start, this.end, this.text);
}

class SrtParser {
  static final _time = RegExp(
      r'(?:(\d+):)?(\d{1,2}):(\d{2})[,.](\d{1,3})\s*-->\s*(?:(\d+):)?(\d{1,2}):(\d{2})[,.](\d{1,3})');

  static Duration _d(String? h, String m, String s, String ms) => Duration(
        hours: int.tryParse(h ?? '0') ?? 0,
        minutes: int.parse(m),
        seconds: int.parse(s),
        milliseconds: int.parse(ms.padRight(3, '0')),
      );

  static List<SubCue> parse(String raw) {
    final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final cues = <SubCue>[];
    for (final block in text.split(RegExp(r'\n{2,}'))) {
      final lines = block.split('\n');
      final ti = lines.indexWhere((l) => l.contains('-->'));
      if (ti < 0) continue;
      final m = _time.firstMatch(lines[ti]);
      if (m == null) continue;
      final body = lines
          .sublist(ti + 1)
          .join('\n')
          .replaceAll(RegExp(r'<[^>]*>'), '') // strip <i>, <b>, <c> tags
          .replaceAll(RegExp(r'\{\\[^}]*\}'), '') // strip {\an8} style tags
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAll('&amp;', '&')
          .trim();
      if (body.isEmpty) continue;
      cues.add(SubCue(
        _d(m.group(1), m.group(2)!, m.group(3)!, m.group(4)!),
        _d(m.group(5), m.group(6)!, m.group(7)!, m.group(8)!),
        body,
      ));
    }
    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  /// Returns the cue active at [pos], or null.
  static SubCue? at(List<SubCue> cues, Duration pos) {
    for (final c in cues) {
      if (c.start > pos) break;
      if (pos <= c.end) return c;
    }
    return null;
  }
}
