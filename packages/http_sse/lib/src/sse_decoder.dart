import 'dart:async';
import 'dart:convert';

import 'package:http_sse/src/sse_event.dart';

/// A [StreamTransformer] that decodes bytes or strings into [SseEvent]s.
class SseDecoder<T extends List<int>>
    extends StreamTransformerBase<T, SseEvent> {
  /// Creates an [SseDecoder].
  ///
  /// Set [parseJson] to `true` (default) to automatically deserialize JSON
  /// payloads into [SseJsonEvent] when data is valid JSON.
  /// Set [emitComments] to `true` (default `false`) if you want comment lines
  /// (e.g. `: ping`) emitted as [SseCommentEvent]s.
  const SseDecoder({
    this.parseJson = true,
    this.emitComments = false,
  });

  /// Whether to parse valid JSON payloads into [SseJsonEvent].
  final bool parseJson;

  /// Whether to emit comment lines as [SseCommentEvent].
  final bool emitComments;

  @override
  Stream<SseEvent> bind(Stream<T> stream) {
    final lineStream = stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const _SseLineSplitter());

    return lineStream.transform(
      _SseLineDecoder(
        parseJson: parseJson,
        emitComments: emitComments,
      ),
    );
  }
}

/// A [StreamTransformer] that decodes line streams into [SseEvent]s.
class _SseLineDecoder extends StreamTransformerBase<String, SseEvent> {
  const _SseLineDecoder({
    required this.parseJson,
    required this.emitComments,
  });

  final bool parseJson;
  final bool emitComments;

  @override
  Stream<SseEvent> bind(Stream<String> stream) async* {
    String? lastEvent;
    String? lastId;
    Duration? lastRetry;
    final dataBuffer = StringBuffer();
    var hasData = false;
    var isFirstLine = true;

    await for (var line in stream) {
      // Strip one leading UTF-8 Byte Order Mark (BOM) if present
      if (isFirstLine) {
        isFirstLine = false;
        if (line.startsWith('\uFEFF')) {
          line = line.substring(1);
        }
      }

      if (line.isEmpty) {
        // Empty line indicates end of an event block (dispatch event)
        if (hasData ||
            lastEvent != null ||
            lastId != null ||
            lastRetry != null) {
          final rawData = dataBuffer.toString();
          final dataString = rawData.endsWith('\n')
              ? rawData.substring(0, rawData.length - 1)
              : rawData;

          if (parseJson && _isLikelyJson(dataString)) {
            try {
              final jsonObj = json.decoder.convert(dataString);
              yield SseEvent.json(
                jsonObj,
                event: lastEvent,
                id: lastId,
                retry: lastRetry,
              );
              lastEvent = null;
              lastId = null;
              lastRetry = null;
              dataBuffer.clear();
              hasData = false;
              continue;
            } catch (_) {
              // Not valid JSON, fallback to text
            }
          }

          yield SseEvent.text(
            dataString,
            event: lastEvent,
            id: lastId,
            retry: lastRetry,
          );

          lastEvent = null;
          lastId = null;
          lastRetry = null;
          dataBuffer.clear();
          hasData = false;
        }
        continue;
      }

      final firstCode = line.codeUnitAt(0);

      // Fast-path: Comment line starting with ':' (ASCII 58)
      if (firstCode == 58) {
        if (emitComments) {
          final commentText = line.length > 1 && line.codeUnitAt(1) == 32
              ? line.substring(2)
              : line.substring(1);
          yield SseEvent.comment(commentText);
        }
        continue;
      }

      // Fast-path field matching without allocating field Substring objects
      if (line.startsWith('data:')) {
        final valStart = line.length > 5 && line.codeUnitAt(5) == 32 ? 6 : 5;
        dataBuffer.write(line.substring(valStart));
        dataBuffer.write('\n');
        hasData = true;
      } else if (line == 'data') {
        dataBuffer.write('\n');
        hasData = true;
      } else if (line.startsWith('event:')) {
        final valStart = line.length > 6 && line.codeUnitAt(6) == 32 ? 7 : 6;
        lastEvent = line.substring(valStart);
      } else if (line == 'event') {
        lastEvent = '';
      } else if (line.startsWith('id:')) {
        final valStart = line.length > 3 && line.codeUnitAt(3) == 32 ? 4 : 3;
        final val = line.substring(valStart);
        if (!val.contains('\u0000')) {
          lastId = val;
        }
      } else if (line == 'id') {
        lastId = '';
      } else if (line.startsWith('retry:')) {
        final valStart = line.length > 6 && line.codeUnitAt(6) == 32 ? 7 : 6;
        final valStr = line.substring(valStart);
        if (_isDigitsOnly(valStr)) {
          final ms = int.tryParse(valStr);
          if (ms != null) {
            lastRetry = Duration(milliseconds: ms);
          }
        }
      } else {
        // Fallback for custom colon fields
        final colonIndex = line.indexOf(':');
        String field;
        String value;

        if (colonIndex == -1) {
          field = line;
          value = '';
        } else {
          field = line.substring(0, colonIndex);
          value = line.substring(colonIndex + 1);
          if (value.startsWith(' ')) {
            value = value.substring(1);
          }
        }

        switch (field) {
          case 'event':
            lastEvent = value;
          case 'id':
            if (!value.contains('\u0000')) {
              lastId = value;
            }
          case 'retry':
            if (_isDigitsOnly(value)) {
              final ms = int.tryParse(value);
              if (ms != null) {
                lastRetry = Duration(milliseconds: ms);
              }
            }
          case 'data':
            dataBuffer.write(value);
            dataBuffer.write('\n');
            hasData = true;
        }
      }
    }

    // Flush any remaining buffered event if stream ends without trailing blank
    // line
    if (hasData || lastEvent != null || lastId != null || lastRetry != null) {
      final rawData = dataBuffer.toString();
      final dataString = rawData.endsWith('\n')
          ? rawData.substring(0, rawData.length - 1)
          : rawData;

      if (parseJson && _isLikelyJson(dataString)) {
        try {
          final jsonObj = json.decoder.convert(dataString);
          yield SseEvent.json(
            jsonObj,
            event: lastEvent,
            id: lastId,
            retry: lastRetry,
          );
          return;
        } catch (_) {}
      }

      yield SseEvent.text(
        dataString,
        event: lastEvent,
        id: lastId,
        retry: lastRetry,
      );
    }
  }
}

@pragma('vm:prefer-inline')
bool _isDigitsOnly(String s) {
  if (s.isEmpty) return false;
  for (var i = 0; i < s.length; i++) {
    final code = s.codeUnitAt(i);
    if (code < 48 || code > 57) return false;
  }
  return true;
}

/// Zero-allocation helper checking if string starts with `{` or `[` and ends
/// with `}` or `]`.
@pragma('vm:prefer-inline')
bool _isLikelyJson(String s) {
  var start = 0;
  while (start < s.length && s.codeUnitAt(start) <= 32) {
    start++;
  }
  if (start >= s.length) return false;

  var end = s.length - 1;
  while (end > start && s.codeUnitAt(end) <= 32) {
    end--;
  }

  final first = s.codeUnitAt(start);
  final last = s.codeUnitAt(end);
  return (first == 123 && last == 125) || (first == 91 && last == 93);
}

/// A line splitter that correctly handles \r, \n, and \r\n chunk boundaries.
class _SseLineSplitter extends StreamTransformerBase<String, String> {
  const _SseLineSplitter();

  @override
  Stream<String> bind(Stream<String> stream) async* {
    var carry = '';

    await for (final chunk in stream) {
      final input = carry + chunk;
      var start = 0;

      for (var i = 0; i < input.length; i++) {
        final char = input[i];
        if (char == '\n') {
          yield input.substring(start, i);
          start = i + 1;
        } else if (char == '\r') {
          yield input.substring(start, i);
          if (i + 1 < input.length && input[i + 1] == '\n') {
            i++;
          }
          start = i + 1;
        }
      }

      carry = start < input.length ? input.substring(start) : '';
    }

    if (carry.isNotEmpty) {
      yield carry;
    }
  }
}
