abstract class HttpRangeException implements Exception {
  const HttpRangeException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HttpRangeInvalidException extends HttpRangeException {
  const HttpRangeInvalidException([super.message = 'invalid range']);
}

class HttpRangeNoOverlapException extends HttpRangeException {
  const HttpRangeNoOverlapException([
    super.message = 'invalid range: failed to overlap',
  ]);
}

class HttpRange {
  const HttpRange({required this.start, required this.length});

  final int start;
  final int length;

  static const _prefix = 'bytes=';

  /// Returns the `Content-Range` header value for a response of [size] bytes.
  ///
  /// [size] must be positive and greater than [start].
  String contentRange(int size) {
    assert(size > 0, 'size must be positive');
    return 'bytes $start-${start + length - 1}/$size';
  }

  /// Parses the `Range` header value per RFC 7233 §2.1.
  ///
  /// Returns an empty list if [header] is empty.
  /// Silently drops ranges whose start is beyond [contentLength], unless
  /// every range is out of bounds — in that case throws
  /// [HttpRangeNoOverlapException].
  /// Throws [HttpRangeInvalidException] on malformed input.
  static List<HttpRange> parse(String header, int contentLength) {
    if (header.isEmpty) return [];

    if (!header.startsWith(_prefix)) {
      throw const HttpRangeInvalidException();
    }

    final ranges = <HttpRange>[];
    var noOverlap = false;

    var partStart = _prefix.length;
    while (partStart < header.length) {
      final commaIdx = header.indexOf(',', partStart);
      var partEnd = commaIdx == -1 ? header.length : commaIdx;

      // trim leading spaces
      while (partStart < partEnd && header[partStart] == ' ') {
        partStart++;
      }
      // trim trailing spaces
      while (partEnd > partStart && header[partEnd - 1] == ' ') {
        partEnd--;
      }

      final rangeStart = partStart;
      partStart = (commaIdx == -1 ? header.length : commaIdx) + 1;

      if (rangeStart == partEnd) continue; // empty part

      final dashIdx = header.indexOf('-', rangeStart);
      if (dashIdx == -1 || dashIdx >= partEnd) {
        throw const HttpRangeInvalidException();
      }

      int start;
      int length;

      if (dashIdx == rangeStart) {
        // Suffix range: -N  (e.g. "bytes=-500")
        final endStr = header.substring(dashIdx + 1, partEnd);
        if (endStr.isEmpty || endStr.startsWith('-')) {
          throw const HttpRangeInvalidException();
        }
        var i = int.tryParse(endStr);
        if (i == null || i < 0) throw const HttpRangeInvalidException();
        if (i > contentLength) i = contentLength;
        start = contentLength - i;
        length = i;
      } else {
        // Normal range: N-  or  N-M
        final i = int.tryParse(header.substring(rangeStart, dashIdx));
        if (i == null || i < 0) throw const HttpRangeInvalidException();

        if (i >= contentLength) {
          noOverlap = true;
          continue;
        }

        start = i;

        if (dashIdx + 1 == partEnd) {
          // open-ended: "bytes=10-"
          length = contentLength - start;
        } else {
          var endI = int.tryParse(header.substring(dashIdx + 1, partEnd));
          if (endI == null || start > endI) {
            throw const HttpRangeInvalidException();
          }
          if (endI >= contentLength) endI = contentLength - 1;
          length = endI - start + 1;
        }
      }

      ranges.add(HttpRange(start: start, length: length));
    }

    if (noOverlap && ranges.isEmpty) {
      throw const HttpRangeNoOverlapException();
    }

    return ranges;
  }
}
