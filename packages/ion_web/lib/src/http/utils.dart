import 'dart:math' as math;
import 'dart:typed_data';

/// A stack pool for reusable [ByteWriter] instances.
final class ByteWriterPool {
  ByteWriterPool({
    this.initialCapacity = 4096,
    this.maxPoolCapacity = 256,
  });

  final int initialCapacity;
  final int maxPoolCapacity;
  final List<ByteWriter> _stack = [];

  ByteWriter acquire() {
    if (_stack.isNotEmpty) {
      final buf = _stack.removeLast();
      buf.reset();
      return buf;
    }
    return ByteWriter(Uint8List(initialCapacity));
  }

  void release(ByteWriter buf) {
    buf.reset();
    if (_stack.length < maxPoolCapacity) {
      _stack.add(buf);
    }
  }
}

/// A growable byte buffer.
final class ByteWriter {
  ByteWriter(this.bytes);

  Uint8List bytes;
  int pos = 0;

  @pragma('vm:prefer-inline')
  void reset() => pos = 0;

  @pragma('vm:prefer-inline')
  Uint8List view() => Uint8List.sublistView(bytes, 0, pos);

  void ensure(int n) {
    if (pos + n > bytes.length) {
      final grown = Uint8List(math.max(bytes.length * 2, pos + n));
      grown.setRange(0, pos, bytes);
      bytes = grown;
    }
  }

  @pragma('vm:prefer-inline')
  void addByte(int byte) {
    ensure(1);
    bytes[pos++] = byte;
  }

  void addBytes(Uint8List b) {
    final len = b.length;
    ensure(len);
    bytes.setRange(pos, pos + len, b);
    pos += len;
  }

  void addInt(int value) {
    if (value == 0) {
      ensure(1);
      bytes[pos++] = 0x30;
      return;
    }
    var temp = value;
    var digits = 0;
    while (temp > 0) {
      digits++;
      temp ~/= 10;
    }
    ensure(digits);
    pos += digits;
    var p = pos - 1;
    temp = value;
    while (temp > 0) {
      bytes[p--] = 0x30 + (temp % 10);
      temp ~/= 10;
    }
  }

  void addAsciiString(String s) {
    final len = s.length;
    ensure(len);
    final buf = bytes;
    var p = pos;
    for (var i = 0; i < len; i++) {
      buf[p++] = s.codeUnitAt(i);
    }
    pos = p;
  }
}

extension CharUtils on int {
  @pragma('vm:prefer-inline')
  bool get isSpace => this == 32;

  @pragma('vm:prefer-inline')
  bool get isCr => this == 13;

  @pragma('vm:prefer-inline')
  bool get isLf => this == 10;

  @pragma('vm:prefer-inline')
  bool get isColon => this == 58;

  @pragma('vm:prefer-inline')
  bool get isSemicolon => this == 59;
}

extension StringAsciiCaseExtension on String {
  /// Compares two strings ignoring ASCII case without allocations.
  @pragma('vm:prefer-inline')
  bool equalsIgnoreAsciiCase(String other) {
    if (length != other.length) return false;
    for (var i = 0; i < length; i++) {
      var ca = codeUnitAt(i);
      if (ca >= 0x41 && ca <= 0x5A) ca += 0x20;
      var cb = other.codeUnitAt(i);
      if (cb >= 0x41 && cb <= 0x5A) cb += 0x20;
      if (ca != cb) return false;
    }
    return true;
  }

  /// Checks whether all characters in the string are ASCII digits (0-9).
  @pragma('vm:prefer-inline')
  bool get isAsciiDigits {
    if (isEmpty) return false;
    for (var i = 0; i < length; i++) {
      final c = codeUnitAt(i);
      if (c < 0x30 || c > 0x39) return false;
    }
    return true;
  }
}

final Uint8List _charFlagsBytes = Uint8List.fromList(_charFlags.codeUnits);

/// Parses a single hex character byte (0-9, a-f, A-F) to its integer value.
/// Returns a negative value if the byte is not a valid hex character.
@pragma('vm:prefer-inline')
int parseHex(int byte) {
  assert(byte >= 0 && byte <= 255);
  final entry = _charFlagsBytes[byte];
  return entry.toSigned(8);
}

/// Whether the byte is a valid HTTP token character (tchar).
@pragma('vm:prefer-inline')
bool isTchar(int byte) {
  assert(byte >= 0 && byte <= 255);
  return (_charFlagsBytes[byte] & _nonTChar) == 0;
}

/// Whether the byte is an invalid character in a header value.
@pragma('vm:prefer-inline')
bool isInvalidHeaderValueChar(int byte) {
  assert(byte >= 0 && byte <= 255);
  return (_charFlagsBytes[byte] & _nonHeaderChar) != 0;
}

/// Whether the byte is an invalid character in a URL.
@pragma('vm:prefer-inline')
bool isInvalidUrlChar(int byte) {
  assert(byte >= 0 && byte <= 255);
  return (_charFlagsBytes[byte] & _nonUrlChar) != 0;
}

// Bit masks for the bits in `_charFlags`.
// Chosen so that they are not set for a hex digit.
const _nonUrlChar = 0x10;
const _nonTChar = 0x20;
const _nonHeaderChar = 0x40;

/// A lookup table for character classification and parsing.
///
/// This table contains 256 entries, one for each byte value.
/// The bits of each entry encode multiple properties of the character:
///
/// *   **Bits 0-3:** The numeric value of the hex digit (0-15), if applicable.
/// *   **Bit 4 (0x10):** Flag indicating the character is invalid in a URL.
/// *   **Bit 5 (0x20):** Flag indicating the character is not a valid HTTP
///     token character (tchar).
/// *   **Bit 6 (0x40):** Flag indicating the character is invalid in a header
///     value.
/// *   **Bit 7 (0x80):** Flag indicating the character is not a valid hex digit
///     (0-9, a-f, A-F). The entry for all hex digits are their value,
///     and for all non-hex-digits, the entry is >= 0x80.
///
/// This layout allows extremely fast checks in performance-critical parsing
/// loops by avoiding multiple conditional branches.
const String _charFlags =
    '\xf0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xa0\xf0\xe0\xe0\xb0\xe0\xe0'
    '\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0'
    '\xa0\x80\xa0\x80\x80\x80\x80\x80\xa0\xa0\x80\x80\xa0\x80\x80\xa0'
    '\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\xa0\xa0\xa0\xa0\xa0\xa0' // ignore: missing_whitespace_between_adjacent_strings
    '\xa0\x0a\x0b\x0c\x0d\x0e\x0f\x80\x80\x80\x80\x80\x80\x80\x80\x80' // ignore: missing_whitespace_between_adjacent_strings
    '\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\xa0\xa0\xa0\x80\x80'
    '\x80\x0a\x0b\x0c\x0d\x0e\x0f\x80\x80\x80\x80\x80\x80\x80\x80\x80' // ignore: missing_whitespace_between_adjacent_strings
    '\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\xa0\x80\xa0\x80\xe0'
    '\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0'
    '\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0'
    '\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0'
    '\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0'
    '\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0'
    '\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0'
    '\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0'
    '\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0';

// The string above is a string representation of the bytes
// that the following function would create:
//
// const _nonHexDigit = 0x80; // Only bit whose placement matters.
// Uint8List _generateFlags() {
//   final list = Uint8List(256);
//   for (var i = 0; i < 256; i++) {
//     var flags = _nonTChar | _nonHexDigit;
//     // isTchar
//     if ((i >= 65 && i <= 90) ||
//         (i >= 97 && i <= 122) ||
//         (i >= 48 && i <= 57) ||
//         [
//           33,
//           35,
//           36,
//           37,
//           38,
//           39,
//           42,
//           43,
//           45,
//           46,
//           94,
//           95,
//           96,
//           124,
//           126,
//         ].contains(i)) {
//       flags &= ~_nonTChar;
//     }
//     // Hex digit (bits 0..3, and not 7)
//     if (i >= 0x30 && i <= 0x39) {
//       flags &= ~_nonHexDigit;
//       flags |= (i - 0x30);
//     } else if (i >= 0x41 && i <= 0x46 ||
//                i >= 0x61 && i <= 0x66) {
//       flags &= ~_nonHexDigit;
//       flags |= (i | 0x20) - 0x61 + 10;
//     }
//     // isInvalidUrlChar (Bit 4)
//     if (i == 0 || i == 10 || i == 13 || i > 127) {
//       flags |= _nonUrlChar;
//     }
//     // isInvalidHeaderValueChar (Bit 6)
//     if ((i < 32 && i != 9 && i != 13) || i == 127) {
//       flags |= _nonHeaderChar;
//     }
//     list[i] = flags;
//   }
//   return list;
// }

/// Efficient byte pattern search using the Boyer-Moore-Horspool algorithm.
final class BytePatternFinder {
  BytePatternFinder(this.pattern) {
    final m = pattern.length;
    _shiftTable.fillRange(0, 256, m);
    for (var i = 0; i < m - 1; i++) {
      _shiftTable[pattern[i]] = m - 1 - i;
    }
  }

  final Uint8List pattern;
  final Uint8List _shiftTable = Uint8List(256);

  @pragma('vm:prefer-inline')
  int indexOf(Uint8List src, int start) {
    final m = pattern.length;
    final n = src.length;
    if (m == 0 || n < m || start > n - m) return -1;

    var i = start;
    while (i <= n - m) {
      final lastByte = src[i + m - 1];
      if (lastByte == pattern[m - 1]) {
        var j = m - 2;
        while (j >= 0 && src[i + j] == pattern[j]) {
          j--;
        }
        if (j < 0) return i;
      }
      i += _shiftTable[lastByte];
    }
    return -1;
  }
}

/// Formats HTTP chunk header (`<hexLength>\r\n`) directly into [buffer].
/// Returns the total number of bytes written.
@pragma('vm:prefer-inline')
int formatChunkHeader(Uint8List buffer, int length) {
  if (length == 0) {
    buffer[0] = 0x30;
    buffer[1] = 13;
    buffer[2] = 10;
    return 3;
  }
  var temp = length;
  var digits = 0;
  while (temp > 0) {
    digits++;
    temp >>= 4;
  }
  var p = digits - 1;
  temp = length;
  while (temp > 0) {
    final digit = temp & 0xF;
    buffer[p--] = digit < 10 ? 0x30 + digit : 0x61 + (digit - 10);
    temp >>= 4;
  }
  buffer[digits] = 13;
  buffer[digits + 1] = 10;
  return digits + 2;
}
