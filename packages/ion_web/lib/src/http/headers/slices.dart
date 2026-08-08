import 'dart:typed_data';

/// Tracks whether the parser buffer backing a batch of [HeaderByteSlice]s is
/// still valid to read.
final class SliceBufferToken {
  bool _valid = true;

  bool get isValid => _valid;

  void invalidate() => _valid = false;
}

/// A slice of bytes representing a header key or value.
final class HeaderByteSlice {
  HeaderByteSlice(this._buffer, this._start, this._end, this._token);

  final Uint8List _buffer;
  final int _start;
  final int _end;
  final SliceBufferToken _token;

  int get length => _end - _start;

  void _checkValid() {
    if (!_token.isValid) {
      throw StateError(
        'This header can no longer be read: the request it belongs to has '
        'been fully processed and its backing buffer reused. Read (or copy) '
        'request headers before the handler returns its response.',
      );
    }
  }

  String asString() {
    _checkValid();
    return String.fromCharCodes(_buffer, _start, _end).trim();
  }

  /// Efficiently checks if the slice matches a lowercase ASCII string.
  bool matches(String lowerCaseTarget) {
    _checkValid();
    if (length != lowerCaseTarget.length) return false;
    for (var i = 0; i < length; i++) {
      var byte = _buffer[_start + i];
      if (byte >= 65 && byte <= 90) byte += 32;
      if (byte != lowerCaseTarget.codeUnitAt(i)) return false;
    }
    return true;
  }

  /// Checks if the slice matches an ASCII string, case-insensitively.
  bool matchesKey(String target) {
    _checkValid();
    if (length != target.length) return false;
    for (var i = 0; i < length; i++) {
      var byte = _buffer[_start + i];
      if (byte >= 65 && byte <= 90) byte += 32;
      var targetByte = target.codeUnitAt(i);
      if (targetByte >= 65 && targetByte <= 90) targetByte += 32;
      if (byte != targetByte) return false;
    }
    return true;
  }
}

/// A pair of key/value slices.
final class HeaderEntrySlices {
  HeaderEntrySlices(this.key, this.value);

  final HeaderByteSlice key;
  final HeaderByteSlice value;
}
