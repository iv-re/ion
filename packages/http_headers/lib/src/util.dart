/// Helper utilities for parsing comma-separated header value lists
Iterable<String> parseCsv(Iterable<String> values) sync* {
  for (final raw in values) {
    if (raw.isEmpty) continue;

    var start = 0;
    var inQuotes = false;
    final len = raw.length;

    for (var i = 0; i < len; i++) {
      final code = raw.codeUnitAt(i);
      if (code == 34 /* " */ ) {
        inQuotes = !inQuotes;
      } else if (code == 44 /* , */ && !inQuotes) {
        final item = _trimSubstring(raw, start, i);
        if (item.isNotEmpty) yield item;
        start = i + 1;
      }
    }

    if (start < len) {
      final item = _trimSubstring(raw, start, len);
      if (item.isNotEmpty) yield item;
    }
  }
}

String _trimSubstring(String s, int start, int end) {
  var curStart = start;
  var curEnd = end;
  while (curStart < curEnd && s.codeUnitAt(curStart) <= 32) {
    curStart++;
  }
  while (curEnd > curStart && s.codeUnitAt(curEnd - 1) <= 32) {
    curEnd--;
  }
  if (curStart >= curEnd) return '';
  return s.substring(curStart, curEnd);
}

/// Checks whether all characters in the string are ASCII digits (0-9).
@pragma('vm:prefer-inline')
bool isAsciiDigits(String s) {
  if (s.isEmpty) return false;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c < 48 || c > 57) return false;
  }
  return true;
}
