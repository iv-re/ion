import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:ion_web/ion_web.dart';
import 'package:test/test.dart' as test;

final Expando<Future<Uint8List>> _cachedResponseBytes = Expando();

/// Extension on [Response] providing helper utilities for testing and
/// comparison.
extension IonResponseUtils on Response {
  /// Reads the complete body bytes of this [Response].
  Future<Uint8List> readBytes() {
    switch (body) {
      case EmptyResponseBody():
        return Future.value(Uint8List(0));
      case BytesResponseBody(:final bytes):
        return Future.value(bytes);
      case StreamResponseBody(:final stream):
        final cached = _cachedResponseBytes[this];
        if (cached != null) return cached;

        final future = _readStream(stream);
        _cachedResponseBytes[this] = future;
        return future;
    }
  }

  static Future<Uint8List> _readStream(Stream<Uint8List> stream) async {
    final builder = BytesBuilder();
    await stream.forEach(builder.add);
    return builder.takeBytes();
  }

  /// Reads the complete body as a decoded string using [encoding].
  Future<String> readText({Encoding encoding = utf8}) async {
    return encoding.decode(await readBytes());
  }

  /// Returns the media type string of the Content-Type header, or `null` if not
  /// present.
  String? get contentType => headers.get<ContentTypeHeader>()?.mediaType;
}

/// Function callback signature to determine if a comparator can handle [actual]
/// and [expected].
typedef ResponseCanCompare =
    bool Function(
      Response actual,
      Response expected,
    );

/// Function callback signature to compare [actual] and [expected] responses.
typedef ResponseCompare =
    FutureOr<void> Function(
      Response actual,
      Response expected,
    );

/// Abstract strategy for comparing HTTP [Response] instances in `ionTest`.
///
/// Implement custom comparators to provide domain-specific response assertions
/// (e.g. XML formatting, Protobuf matching, or custom [Response] subclasses).
abstract class ResponseComparator {
  const ResponseComparator();

  /// Creates a custom [ResponseComparator] using function callbacks.
  factory ResponseComparator.custom({
    required ResponseCanCompare canCompare,
    required ResponseCompare compare,
  }) {
    return _CustomResponseComparator(
      canCompareFn: canCompare,
      compareFn: compare,
    );
  }

  /// Creates a comparator that matches when the Content-Type header of
  /// actual or expected contains [contentTypeSubstring].
  factory ResponseComparator.byContentType(
    String contentTypeSubstring, {
    required ResponseCompare compare,
  }) {
    return _ContentTypeResponseComparator(
      contentTypeSubstring,
      compareFn: compare,
    );
  }

  /// Creates a comparator that matches when actual and/or expected is of type [T].
  static ResponseComparator byType<T extends Response>({
    required ResponseCompare compare,
  }) {
    return _TypeResponseComparator<T>(compareFn: compare);
  }

  /// Returns `true` if this comparator can handle comparing [actual] and
  /// [expected].
  bool canCompare(Response actual, Response expected);

  /// Performs assertion/comparison between [actual] and [expected].
  ///
  /// Should throw [test.TestFailure] if [actual] does not match [expected].
  FutureOr<void> compare(Response actual, Response expected);
}

final class _CustomResponseComparator extends ResponseComparator {
  const _CustomResponseComparator({
    required this.canCompareFn,
    required this.compareFn,
  });

  final ResponseCanCompare canCompareFn;
  final ResponseCompare compareFn;

  @override
  bool canCompare(Response actual, Response expected) {
    return canCompareFn(actual, expected);
  }

  @override
  FutureOr<void> compare(Response actual, Response expected) {
    return compareFn(actual, expected);
  }
}

final class _TypeResponseComparator<T extends Response>
    extends ResponseComparator {
  const _TypeResponseComparator({required this.compareFn});

  final ResponseCompare compareFn;

  @override
  bool canCompare(Response actual, Response expected) {
    return actual is T || expected is T;
  }

  @override
  FutureOr<void> compare(Response actual, Response expected) {
    return compareFn(actual, expected);
  }
}

final class _ContentTypeResponseComparator extends ResponseComparator {
  const _ContentTypeResponseComparator(
    this.contentTypeSubstring, {
    required this.compareFn,
  });

  final String contentTypeSubstring;
  final ResponseCompare compareFn;

  @override
  bool canCompare(Response actual, Response expected) {
    final actualCt = actual.contentType ?? '';
    final expectedCt = expected.contentType ?? '';
    return actualCt.contains(contentTypeSubstring) ||
        expectedCt.contains(contentTypeSubstring);
  }

  @override
  FutureOr<void> compare(Response actual, Response expected) {
    return compareFn(actual, expected);
  }
}

/// Built-in comparator for Server-Sent Events (`text/event-stream`).
class SseResponseComparator extends ResponseComparator {
  const SseResponseComparator();

  @override
  bool canCompare(Response actual, Response expected) {
    final actualCt = actual.contentType ?? '';
    final expectedCt = expected.contentType ?? '';
    return actualCt.contains('text/event-stream') ||
        expectedCt.contains('text/event-stream');
  }

  @override
  Future<void> compare(Response actual, Response expected) async {
    final actualBytes = await actual.readBytes();
    final expectedBytes = await expected.readBytes();

    final actualEvents = await Stream.value(
      actualBytes,
    ).transform(const SseDecoder()).toList();
    final expectedEvents = await Stream.value(
      expectedBytes,
    ).transform(const SseDecoder()).toList();

    try {
      test.expect(actualEvents, test.equals(expectedEvents));
    } on test.TestFailure catch (e) {
      final actualStr = actualEvents.map((e) => e.toFormattedString()).join();
      final expectedStr = expectedEvents
          .map((e) => e.toFormattedString())
          .join();
      final diffText = formatDiff(expected: expectedStr, actual: actualStr);

      throw test.TestFailure('${e.message}\n$diffText');
    }
  }
}

/// Built-in comparator for JSON payloads (`application/json`).
class JsonResponseComparator extends ResponseComparator {
  const JsonResponseComparator();

  @override
  bool canCompare(Response actual, Response expected) {
    final actualCt = actual.contentType ?? '';
    final expectedCt = expected.contentType ?? '';
    return actualCt.contains('json') || expectedCt.contains('json');
  }

  @override
  Future<void> compare(Response actual, Response expected) async {
    final actualBytes = await actual.readBytes();
    final expectedBytes = await expected.readBytes();

    if (actualBytes.isEmpty || expectedBytes.isEmpty) {
      try {
        test.expect(actualBytes, test.equals(expectedBytes));
        return;
      } on test.TestFailure catch (e) {
        final actualStr = utf8.decode(actualBytes);
        final expectedStr = utf8.decode(expectedBytes);
        final diffText = formatDiff(expected: expectedStr, actual: actualStr);
        throw test.TestFailure('${e.message}\n$diffText');
      }
    }

    final actualJson = jsonDecode(utf8.decode(actualBytes));
    final expectedJson = jsonDecode(utf8.decode(expectedBytes));

    try {
      test.expect(actualJson, test.equals(expectedJson));
    } on test.TestFailure catch (e) {
      final prettyActual = const JsonEncoder.withIndent(
        '  ',
      ).convert(actualJson);
      final prettyExpected = const JsonEncoder.withIndent(
        '  ',
      ).convert(expectedJson);
      final diffText = formatDiff(
        expected: prettyExpected,
        actual: prettyActual,
      );

      throw test.TestFailure('${e.message}\n$diffText');
    }
  }
}

/// Built-in default comparator comparing raw response payload bytes and text
/// diffs.
class DefaultResponseComparator extends ResponseComparator {
  const DefaultResponseComparator();

  @override
  bool canCompare(Response actual, Response expected) {
    return true;
  }

  @override
  Future<void> compare(Response actual, Response expected) async {
    final actualBytes = await actual.readBytes();
    final expectedBytes = await expected.readBytes();

    try {
      test.expect(actualBytes, test.equals(expectedBytes));
    } on test.TestFailure catch (e) {
      final actualStr = utf8.decode(actualBytes);
      final expectedStr = utf8.decode(expectedBytes);
      final diffText = formatDiff(expected: expectedStr, actual: actualStr);

      throw test.TestFailure('${e.message}\n$diffText');
    }
  }
}

final List<ResponseComparator> _userRegisteredComparators = [];

/// Registers a global [ResponseComparator] for use in `ionTest`.
///
/// Comparators registered here take precedence over built-in defaults.
void registerResponseComparator(ResponseComparator comparator) {
  _userRegisteredComparators.insert(0, comparator);
}

/// Unregisters a previously registered global [ResponseComparator].
void unregisterResponseComparator(ResponseComparator comparator) {
  _userRegisteredComparators.remove(comparator);
}

/// Removes all user-registered global response comparators.
void resetResponseComparators() {
  _userRegisteredComparators.clear();
}

/// Returns all active comparators, including local, user-registered, and
/// built-in defaults.
List<ResponseComparator> getResponseComparators({
  List<ResponseComparator>? local,
}) {
  return [
    ...?local,
    ..._userRegisteredComparators,
    const SseResponseComparator(),
    const JsonResponseComparator(),
    const DefaultResponseComparator(),
  ];
}

/// Formats a colored text diff between [expected] and [actual].
String formatDiff({required String expected, required String actual}) {
  final buffer = StringBuffer();
  final differences = diff(expected, actual);
  buffer
    ..writeln('${"=" * 4} diff ${"=" * 40}')
    ..writeln()
    ..writeln(differences.toPrettyString())
    ..writeln()
    ..writeln('${"=" * 4} end diff ${"=" * 36}');
  return buffer.toString();
}

extension on List<Diff> {
  String toPrettyString() {
    String identical(String str) => '\u001b[90m$str\u001B[0m';
    String deletion(String str) => '\u001b[31m[-$str-]\u001B[0m';
    String insertion(String str) => '\u001b[32m{+$str+}\u001B[0m';

    final buffer = StringBuffer();
    forEach((difference) {
      switch (difference.operation) {
        case DIFF_EQUAL:
          buffer.write(identical(difference.text));
        case DIFF_DELETE:
          buffer.write(deletion(difference.text));
        case DIFF_INSERT:
          buffer.write(insertion(difference.text));
      }
    });
    return buffer.toString();
  }
}
