import 'dart:convert';
import 'dart:typed_data';

import 'package:ion_web/ion_web.dart';

export 'dart:convert';
export 'dart:typed_data';

/// Encodes a UTF-8 string to [Uint8List].
Uint8List stringToBytes(String input) => Uint8List.fromList(utf8.encode(input));

/// Decodes a [Uint8List] to a UTF-8 string.
String bytesToString(Uint8List bytes) => utf8.decode(bytes);

/// Collects all chunks from a byte stream into a single [Uint8List].
Future<Uint8List> readStreamBytes(Stream<List<int>> stream) async {
  final chunks = await stream.toList();
  return Uint8List.fromList(chunks.expand((b) => b).toList());
}

/// Collects all chunks from a byte stream and decodes to a UTF-8 string.
Future<String> readStreamText(Stream<List<int>> stream) async {
  final bytes = await readStreamBytes(stream);
  return bytesToString(bytes);
}

/// Extracts all body bytes from a [Response].
Future<Uint8List> readResponseBodyBytes(Response response) async {
  switch (response.body) {
    case BytesResponseBody(:final bytes):
      return bytes;
    case StreamResponseBody(:final stream):
      return readStreamBytes(stream);
    case EmptyResponseBody():
      return Uint8List(0);
  }
}

/// Extracts body text as a UTF-8 string from a [Response].
Future<String> readResponseBodyText(Response response) async {
  final bytes = await readResponseBodyBytes(response);
  return bytesToString(bytes);
}
