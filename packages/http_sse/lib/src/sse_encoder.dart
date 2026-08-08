import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http_sse/src/sse_event.dart';

/// A [Converter] and [StreamTransformer] that converts [SseEvent]s into UTF-8
/// bytes.
class SseEncoder extends Converter<SseEvent, Uint8List> {
  const SseEncoder();

  @override
  Uint8List convert(SseEvent input) => input.toBytes();

  @override
  Stream<Uint8List> bind(Stream<SseEvent> stream) {
    return stream.map(convert);
  }
}
