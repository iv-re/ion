import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ion_web/ion_web.dart';
import 'package:test/test.dart';

void main() {
  group('RequestTextExtractor', () {
    test('text() decodes UTF-8 request stream', () async {
      final stream = Stream<Uint8List>.fromIterable([
        Uint8List.fromList(utf8.encode('Hello ')),
        Uint8List.fromList(utf8.encode('World!')),
      ]);

      final request = Request(
        stream,
        method: .post,
        uri: .parse('http://localhost/test'),
        version: .http11,
        headers: TypedHeaders([]),
      );

      final body = await request.text();
      expect(body, equals('Hello World!'));
    });

    test('text() returns empty string for empty stream', () async {
      final request = Request(
        const Stream<Uint8List>.empty(),
        method: .post,
        uri: .parse('http://localhost/test'),
        version: .http11,
        headers: TypedHeaders([]),
      );

      final body = await request.text();
      expect(body, equals(''));
    });
  });

  group('Request.copyWith', () {
    late Request base;

    setUp(() {
      base = Request(
        Stream<Uint8List>.fromIterable([
          Uint8List.fromList(utf8.encode('original')),
        ]),
        method: HttpMethod.get,
        uri: Uri.parse('http://localhost/original'),
        version: HttpVersion.http11,
        headers: TypedHeaders([]),
      );
    });

    test('returns identical values when no args provided', () async {
      final copy = base.copyWith();
      expect(copy.method, equals(base.method));
      expect(copy.uri, equals(base.uri));
      expect(copy.version, equals(base.version));
      expect(copy.ctx, equals(base.ctx));
      // body stream is the same object (this)
      expect(await copy.text(), equals('original'));
    });

    test('replaces body stream', () async {
      final newStream = Stream<Uint8List>.fromIterable([
        Uint8List.fromList(utf8.encode('replaced')),
      ]);

      final copy = base.copyWith(body: newStream);
      expect(await copy.text(), equals('replaced'));
      // other fields unchanged
      expect(copy.method, equals(base.method));
      expect(copy.uri, equals(base.uri));
    });

    test('replaces individual fields independently', () {
      final newUri = Uri.parse('http://localhost/new-path');

      final withMethod = base.copyWith(method: HttpMethod.post);
      expect(withMethod.method, equals(HttpMethod.post));
      expect(withMethod.uri, equals(base.uri));

      final withUri = base.copyWith(uri: newUri);
      expect(withUri.uri, equals(newUri));
      expect(withUri.method, equals(base.method));
    });
  });
}
