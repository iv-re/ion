import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

final Converter<Object?, List<int>> _jsonEncoder = json.encoder.fuse(
  utf8.encoder,
);

final Uint8List _eventPrefix = ascii.encode('event: ');
final Uint8List _dataPrefix = ascii.encode('data: ');
final Uint8List _idPrefix = ascii.encode('id: ');
final Uint8List _retryPrefix = ascii.encode('retry: ');
final Uint8List _commentPrefix = ascii.encode(':');
final Uint8List _lf = Uint8List.fromList([10]); // \n

/// Represents a Server-Sent Event (SSE) message or comment.
@immutable
abstract class SseEvent extends Equatable {
  const SseEvent({
    this.event,
    this.id,
    this.retry,
  });

  /// Creates a text-payload SSE event.
  const factory SseEvent.text(
    String data, {
    String? event,
    String? id,
    Duration? retry,
  }) = SseTextEvent;

  /// Creates a JSON-payload SSE event.
  const factory SseEvent.json(
    Object? data, {
    String? event,
    String? id,
    Duration? retry,
  }) = SseJsonEvent;

  /// Creates an SSE comment line (e.g. `: ping`).
  const factory SseEvent.comment(
    String comment,
  ) = SseCommentEvent;

  /// The optional event field name (e.g. `event: user_updated`).
  final String? event;

  /// The optional event ID (e.g. `id: 123`).
  final String? id;

  /// The optional reconnection time (e.g. `retry: 5000`).
  final Duration? retry;

  /// Encodes this SSE event into UTF-8 bytes for network transmission.
  Uint8List toBytes();

  /// Formats this SSE event into its canonical String representation.
  String toFormattedString() => utf8.decode(toBytes());
}

/// A text-payload SSE event.
final class SseTextEvent extends SseEvent {
  const SseTextEvent(
    this.data, {
    super.event,
    super.id,
    super.retry,
  });

  final String data;

  @override
  Uint8List toBytes() {
    return _formatMessageBytes(
      data: data,
      event: event,
      id: id,
      retry: retry,
    );
  }

  @override
  List<Object?> get props => [data, event, id, retry];
}

/// A JSON-payload SSE event.
final class SseJsonEvent extends SseEvent {
  const SseJsonEvent(
    this.data, {
    super.event,
    super.id,
    super.retry,
  });

  final Object? data;

  @override
  Uint8List toBytes() {
    final jsonBytes = _jsonEncoder.convert(data);
    final builder = BytesBuilder(copy: false);

    if (event != null) {
      final cleanEvent = _hasLineBreaks(event!)
          ? event!.replaceAll('\r', '').replaceAll('\n', '')
          : event!;
      builder.add(_eventPrefix);
      builder.add(utf8.encode(cleanEvent));
      builder.add(_lf);
    }

    builder.add(_dataPrefix);
    builder.add(jsonBytes);
    builder.add(_lf);

    if (id != null) {
      final cleanId = _hasLineBreaks(id!)
          ? id!.replaceAll('\r', '').replaceAll('\n', '')
          : id!;
      builder.add(_idPrefix);
      builder.add(utf8.encode(cleanId));
      builder.add(_lf);
    }

    if (retry != null) {
      builder.add(_retryPrefix);
      builder.add(ascii.encode(retry!.inMilliseconds.toString()));
      builder.add(_lf);
    }

    builder.add(_lf);
    return builder.takeBytes();
  }

  @override
  List<Object?> get props => [data, event, id, retry];
}

/// An SSE comment line (e.g. `: ping`).
final class SseCommentEvent extends SseEvent {
  const SseCommentEvent(this.comment) : super();

  final String comment;

  @override
  Uint8List toBytes() {
    final cleanComment = comment.replaceAll('\r', '').replaceAll('\n', '');
    final builder = BytesBuilder(copy: false);
    builder.add(_commentPrefix);
    builder.add(utf8.encode(cleanComment));
    builder.add(_lf);
    builder.add(_lf);
    return builder.takeBytes();
  }

  @override
  List<Object?> get props => [comment];
}

@pragma('vm:prefer-inline')
bool _hasLineBreaks(String s) {
  for (var i = 0; i < s.length; i++) {
    final code = s.codeUnitAt(i);
    if (code == 10 || code == 13) return true;
  }
  return false;
}

Uint8List _formatMessageBytes({
  required String data,
  String? event,
  String? id,
  Duration? retry,
}) {
  final builder = BytesBuilder(copy: false);

  if (event != null) {
    final cleanEvent = _hasLineBreaks(event)
        ? event.replaceAll('\r', '').replaceAll('\n', '')
        : event;
    builder.add(_eventPrefix);
    builder.add(utf8.encode(cleanEvent));
    builder.add(_lf);
  }

  final normalizedData = data.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  var start = 0;
  while (start < normalizedData.length) {
    var end = normalizedData.indexOf('\n', start);
    final isLast = end == -1;
    if (isLast) end = normalizedData.length;

    builder.add(_dataPrefix);
    final line = start == 0 && isLast
        ? normalizedData
        : normalizedData.substring(start, end);
    builder.add(utf8.encode(line));
    builder.add(_lf);

    if (isLast) break;
    start = end + 1;
  }

  if (id != null) {
    final cleanId = _hasLineBreaks(id)
        ? id.replaceAll('\r', '').replaceAll('\n', '')
        : id;
    builder.add(_idPrefix);
    builder.add(utf8.encode(cleanId));
    builder.add(_lf);
  }

  if (retry != null) {
    builder.add(_retryPrefix);
    builder.add(ascii.encode(retry.inMilliseconds.toString()));
    builder.add(_lf);
  }

  builder.add(_lf);
  return builder.takeBytes();
}
