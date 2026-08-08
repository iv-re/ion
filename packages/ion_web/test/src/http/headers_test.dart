import 'dart:io';

import 'package:ion_web/src/http/headers/headers.dart';
import 'package:test/test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('HostHeader', () {
    test('parses host without port', () {
      final host = HostHeader.decode(['localhost']);
      expect(host?.host, equals('localhost'));
      expect(host?.port, isNull);
      expect(host?.value, equals('localhost'));
    });

    test('parses host with port', () {
      final host = HostHeader.decode(['localhost:8080']);
      expect(host?.host, equals('localhost'));
      expect(host?.port, equals(8080));
      expect(host?.value, equals('localhost:8080'));
    });

    test('parses IPv6 host with port', () {
      final host = HostHeader.decode(['[::1]:8080']);
      expect(host?.host, equals('[::1]'));
      expect(host?.port, equals(8080));
      expect(host?.value, equals('[::1]:8080'));
    });

    test('validates invalid host header formats', () {
      final empty = HostHeader.decode(['']);
      expect(empty?.isValid ?? false, isFalse);
    });
  });

  group('ContentLengthHeader and ConnectionHeader', () {
    test('ContentLengthHeader formats correctly', () {
      const header = ContentLengthHeader(1024);
      expect(header.name, equals('Content-Length'));
      expect(header.value, equals('1024'));
      expect(header.length, equals(1024));
    });

    test('ConnectionHeader values format correctly', () {
      const keepAlive = ConnectionHeader.keepAlive();
      expect(keepAlive.name, equals('Connection'));
      expect(keepAlive.value, equals('keep-alive'));
      expect(const ConnectionHeader.close().value, equals('close'));
    });
  });

  group('TransferEncodingHeader', () {
    test('parses single chunked transfer encoding', () {
      final header = TransferEncodingHeader.decode(['chunked']);
      expect(header?.isChunked, isTrue);
      expect(header?.codings.length, 1);
      expect(header?.codings.first, TransferCoding.chunked);
      expect(header?.value, 'chunked');
    });

    test('parses multiple transfer codings like gzip, chunked', () {
      final header = TransferEncodingHeader.decode(['gzip, chunked']);
      expect(header?.isChunked, isTrue);
      expect(header?.codings.length, 2);
      expect(header?.codings[0], TransferCoding.gzip);
      expect(header?.codings[1], TransferCoding.chunked);
      expect(header?.value, 'gzip, chunked');
    });
  });

  group('ContentTypeHeader', () {
    test('formats presets correctly', () {
      const textUtf8 = ContentTypeHeader.textUtf8();
      expect(textUtf8.name, 'Content-Type');
      expect(textUtf8.value, 'text/plain; charset=utf-8');

      expect(const ContentTypeHeader.html().value, 'text/html');
      expect(const ContentTypeHeader.json().value, 'application/json');
    });

    test('parses raw Content-Type with charset and boundary', () {
      final parsed = ContentTypeHeader.decode([
        'multipart/form-data; charset=utf-8; boundary=something123',
      ]);
      expect(parsed?.mediaType, 'multipart/form-data');
      expect(parsed?.charset, 'utf-8');
      expect(parsed?.boundary, 'something123');
    });
  });

  group('CacheControlHeader', () {
    test('formats directives correctly', () {
      const cc = CacheControlHeader(
        isPublic: true,
        maxAge: Duration(seconds: 3600),
        isImmutable: true,
      );
      expect(cc.name, 'Cache-Control');
      expect(cc.value, 'public, immutable, max-age=3600');

      expect(
        const CacheControlHeader(noCache: true).value,
        equals('no-cache'),
      );
      expect(
        const CacheControlHeader(noCache: true, noStore: true).value,
        equals('no-cache, no-store'),
      );
    });

    test('parses complex raw Cache-Control header', () {
      final parsed = CacheControlHeader.decode([
        'no-cache, no-store, public, immutable, max-age=3600, s-maxage=7200',
      ]);
      expect(parsed?.noCache, isTrue);
      expect(parsed?.noStore, isTrue);
      expect(parsed?.isPublic, isTrue);
      expect(parsed?.isImmutable, isTrue);
      expect(parsed?.maxAge, equals(const Duration(seconds: 3600)));
      expect(parsed?.sMaxAge, equals(const Duration(seconds: 7200)));
    });
  });

  group('SecWebSocketExtensionsHeader', () {
    test('parses permessage-deflate with parameters', () {
      const rawHeader =
          'permessage-deflate; client_no_context_takeover; '
          'server_no_context_takeover';
      final header = SecWebSocketExtensionsHeader.decode([rawHeader]);

      expect(header?.name, equals('Sec-WebSocket-Extensions'));
      expect(header?.perMessageDeflate, isTrue);
      expect(header?.clientNoContextTakeover, isTrue);
      expect(header?.serverNoContextTakeover, isTrue);
    });

    test('formats header via constructor correctly', () {
      const header = SecWebSocketExtensionsHeader(
        perMessageDeflate: true,
        clientNoContextTakeover: true,
      );

      expect(
        header.value,
        equals('permessage-deflate; client_no_context_takeover'),
      );
    });
  });

  group('TypedHeaders', () {
    test('parses and caches typed headers correctly', () {
      final headers = TypedHeaders.fromList([
        const .contentLength(2048),
        const .host('example.com:443'),
        const .connectionKeepAlive(),
        const .transferEncoding([.gzip, .chunked]),
        const .contentTypeJson(),
        const .cacheControl(noCache: true, maxAge: Duration(seconds: 60)),
        const .secWebSocketExtensions(
          perMessageDeflate: true,
          clientNoContextTakeover: true,
        ),
      ]);

      expect(headers.contentLength?.length, equals(2048));
      expect(headers.host?.host, equals('example.com'));
      expect(headers.host?.port, equals(443));
      expect(headers.connection?.isKeepAlive, isTrue);
      expect(headers.transferEncoding?.isChunked, isTrue);
      expect(headers.contentType?.mediaType, equals('application/json'));
      expect(headers.cacheControl?.noCache, isTrue);
      expect(
        headers.cacheControl?.maxAge,
        equals(const Duration(seconds: 60)),
      );
      expect(headers.secWebSocketExtensions?.perMessageDeflate, isTrue);
      expect(headers.secWebSocketExtensions?.clientNoContextTakeover, isTrue);
      expect(headers.secWebSocketExtensions?.serverNoContextTakeover, isFalse);

      // Verify cached instances return identical value
      expect(headers.contentLength?.length, equals(2048));
      expect(headers.connection?.isKeepAlive, isTrue);
    });

    test('decodes custom TypedHeader using public decode method', () {
      final headers = TypedHeaders.fromList([
        const TestCustomHeader('x-custom-token', 'secret123'),
      ]);

      final tokenHeader = headers.decode(
        const HttpHeader('x-custom-token'),
        TestCustomHeader.decode,
      );

      expect(tokenHeader?.value, equals('secret123'));
    });

    test('returns null for missing or invalid header values', () {
      final headers = TypedHeaders.fromList([
        const TestCustomHeader('content-length', 'invalid_number'),
        const TestCustomHeader('connection', 'unknown_type'),
      ]);

      expect(headers.contentLength, isNull);
      expect(headers.connection?.isKeepAlive, isFalse);
      expect(headers.host, isNull);
      expect(headers.contentType, isNull);
      expect(headers.cacheControl, isNull);
      expect(headers.secWebSocketExtensions, isNull);
    });

    test('SliceBufferToken invalidation throws StateError on read', () {
      final token = SliceBufferToken();
      final bytes = Uint8List.fromList('Host: localhost'.codeUnits);
      final slice = HeaderByteSlice(bytes, 0, 4, token);

      expect(slice.asString(), equals('Host'));
      expect(slice.matchesKey('host'), isTrue);

      token.invalidate();

      expect(slice.asString, throwsStateError);
      expect(() => slice.matchesKey('host'), throwsStateError);
    });
  });

  group('IfRangeHeader', () {
    test('returns null for empty or whitespace raw string', () {
      expect(IfRangeHeader.decode([]), isNull);
      expect(IfRangeHeader.decode(['   ']), isNull);
    });

    test('parses strong and weak ETags correctly', () {
      final parsedStrong = IfRangeHeader.decode(['"v1-sample"']);
      expect(parsedStrong, isA<IfRangeETag>());
      if (parsedStrong is IfRangeETag) {
        expect(parsedStrong.etag.tag, equals(const EntityTag('v1-sample')));
        expect(parsedStrong.name, equals('If-Range'));
      }

      final parsedWeak = IfRangeHeader.decode(['W/"v1-sample"']);
      expect(parsedWeak, isA<IfRangeETag>());
      if (parsedWeak is IfRangeETag) {
        expect(parsedWeak.etag.tag, equals(const EntityTag.weak('v1-sample')));
      }
    });

    test('parses valid HTTP Date string correctly', () {
      const dateStr = 'Wed, 21 Oct 2015 07:28:00 GMT';
      final expectedDate = HttpDate.parse(dateStr);

      final parsed = IfRangeHeader.decode([dateStr]);
      expect(parsed, isA<IfRangeDate>());
      if (parsed is IfRangeDate) {
        expect(parsed.date, equals(expectedDate));
        expect(parsed.name, equals('If-Range'));
      }
    });

    test('returns null for invalid header string', () {
      expect(IfRangeHeader.decode(['invalid_if_range_value']), isNull);
    });
  });

  group('TypedHeader extensions', () {
    test('has checks presence by type and by name', () {
      final headers = <TypedHeader>[
        const AcceptRangesHeader.bytes(),
        ETagHeader.strong('v1'),
      ];

      expect(headers.has<AcceptRangesHeader>(), isTrue);
      expect(headers.has<ETagHeader>(), isTrue);
      expect(headers.has<ContentTypeHeader>(), isFalse);

      expect(headers.has('Accept-Ranges'), isTrue);
      expect(headers.has('etag'), isTrue);
      expect(headers.has('content-type'), isFalse);
    });

    test('get retrieves typed headers', () {
      final headers = <TypedHeader>[
        const AcceptRangesHeader.bytes(),
        ETagHeader.strong('v1'),
      ];

      final etag = headers.get<ETagHeader>();
      expect(etag, isNotNull);
      expect(etag?.tag, equals(const EntityTag.strong('v1')));

      final contentType = headers.get<ContentTypeHeader>();
      expect(contentType, isNull);
    });

    test('addIfAbsent appends header only if not already present', () {
      final headers = <TypedHeader>[
        const AcceptRangesHeader.bytes(),
      ];

      headers.addIfAbsent(const AcceptRangesHeader.bytes());
      expect(headers.length, equals(1));

      headers.addIfAbsent(ETagHeader.strong('v1'));
      expect(headers.length, equals(2));
      expect(headers.has<ETagHeader>(), isTrue);
    });
  });

  group('TypedHeaders Content-Length framing', () {
    test('extracts Content-Length correctly', () {
      final headers = TypedHeaders.fromList([
        const .contentLength(1024),
      ]);
      expect(headers.hasContentLengthConflict, isFalse);
      expect(headers.parsedContentLength, equals(1024));
    });

    test('detects duplicate Content-Length conflict', () {
      final headers = TypedHeaders.fromList([
        const .contentLength(10),
        const .contentLength(20),
      ]);
      expect(headers.hasContentLengthConflict, isTrue);
      expect(headers.parsedContentLength, isNull);
    });

    test('detects malformed Content-Length digits', () {
      final invalidValues = [
        '1024abc',
        '1 0',
        '-10',
        '+10',
        '0x10',
        '0o10',
        '1_0',
        '',
      ];
      for (final val in invalidValues) {
        final headers = TypedHeaders.fromList([
          TestCustomHeader('Content-Length', val),
        ]);
        expect(
          headers.hasContentLengthConflict,
          isTrue,
          reason: 'Failed for: "$val"',
        );
        expect(headers.parsedContentLength, isNull);
      }
    });
  });

  group('TypedHeaders Host framing', () {
    test('extracts single Host header correctly', () {
      final headers = TypedHeaders.fromList([
        const .host('example.com:8080'),
      ]);
      expect(headers.hasHostConflict, isFalse);
      expect(headers.host?.host, equals('example.com'));
      expect(headers.host?.port, equals(8080));
    });

    test('detects duplicate Host header conflict with different values', () {
      final headers = TypedHeaders.fromList([
        const .host('example.com'),
        const .host('other.com'),
      ]);
      expect(headers.hasHostConflict, isTrue);
      expect(headers.host, isNull);
    });

    test('detects duplicate Host header conflict with identical values', () {
      final headers = TypedHeaders.fromList([
        const .host('example.com'),
        const .host('example.com'),
      ]);
      expect(headers.hasHostConflict, isTrue);
      expect(headers.host, isNull);
    });
  });

  group('TypedHeaders Transfer-Encoding framing', () {
    test('extracts chunked Transfer-Encoding correctly', () {
      final headers = TypedHeaders.fromList([
        const .transferEncodingChunked(),
      ]);
      expect(headers.hasTransferEncoding, isTrue);
      expect(headers.isChunkedTransferEncoding, isTrue);
      expect(headers.hasNonFinalChunkedConflict, isFalse);
      expect(headers.isTransferEncodingInvalid, isFalse);
    });

    test('detects non-final chunked Transfer-Encoding', () {
      final headers = TypedHeaders.fromList([
        const .transferEncoding([
          TransferCoding.chunked,
          TransferCoding.gzip,
        ]),
      ]);
      expect(headers.hasTransferEncoding, isTrue);
      expect(headers.isChunkedTransferEncoding, isFalse);
      expect(headers.hasNonFinalChunkedConflict, isTrue);
      expect(headers.isTransferEncodingInvalid, isFalse);
    });

    test('detects empty Transfer-Encoding header as invalid', () {
      final headers = TypedHeaders.fromList([
        const TestCustomHeader('Transfer-Encoding', ''),
      ]);
      expect(headers.hasTransferEncoding, isTrue);
      expect(headers.isTransferEncodingInvalid, isTrue);
    });
  });

  group('TypedHeaders entries', () {
    test('returns all raw key-value entries', () {
      final headers = TypedHeaders.fromList([
        const .host('example.com'),
        const .userAgent('IonTest'),
        const TestCustomHeader('Accept', 'application/json'),
      ]);

      final entries = headers.entries.toList();
      expect(entries.length, equals(3));
      expect(entries[0].key, equals('Host'));
      expect(entries[0].value, equals('example.com'));
      expect(entries[1].key, equals('User-Agent'));
      expect(entries[1].value, equals('IonTest'));
      expect(entries[2].key, equals('Accept'));
      expect(entries[2].value, equals('application/json'));
    });
  });

  group('DefaultTypedHeaders extension getters', () {
    test('decodes all default typed headers', () {
      final headers = TypedHeaders.fromList([
        const .acceptRangesBytes(),
        const .accessControlAllowCredentials(),
        const .accessControlAllowHeaders(['Content-Type']),
        const .accessControlAllowMethods(['GET', 'POST']),
        .accessControlAllowOrigin(const .any()),
        const .accessControlExposeHeaders(['X-Custom']),
        const .accessControlMaxAge(Duration(seconds: 86400)),
        const .accessControlRequestHeaders(['X-Ping']),
        const .accessControlRequestMethod('POST'),
        const .age(Duration(seconds: 120)),
        const .allow(['GET', 'POST']),
        .authorization(const .bearer('secret')),
        const .contentDispositionInline(),
        const .contentEncodingGzip(),
        const .contentLocation('/index.html'),
        const .contentRangeBytes(0, 499, 1000),
        const .cookie({'session': 'abc'}),
        .date(.utc(2015, 10, 21, 7, 28)),
        .etagStrong('12345'),
        .expect(const .continue100()),
        .expires(.utc(2015, 10, 21, 7, 28)),
        const .from('webmaster@example.com'),
        .ifMatch(.etag(const .strong('12345'))),
        .ifModifiedSince(.utc(2015, 10, 21, 7, 28)),
        .ifNoneMatch(.etag(const .strong('12345'))),
        .ifRange(.etag(.strong('12345'))),
        .ifUnmodifiedSince(.utc(2015, 10, 21, 7, 28)),
        const TestCustomHeader('keep-alive', 'timeout=5'),
        .lastModified(.utc(2015, 10, 21, 7, 28)),
        const .location('https://example.com'),
        const .maxForwards(10),
        .origin(.parts('https', 'example.com')),
        const .pragmaNoCache(),
        const .proxyAuthenticate([.basic(realm: 'Access')]),
        .proxyAuthorization(.basic('user', 'pass')),
        const .range('bytes=0-499'),
        const .referer('https://example.com/page'),
        .retryAfter(const .delay(Duration(seconds: 120))),
        const .secWebSocketAccept('s3pPLMBiTxaQ9kYGzzhZRbK+xOo='),
        const .secWebSocketKey('dGhl IHNhbXBsZSBub25jZQ=='),
        const .secWebSocketProtocol(['chat']),
        const .secWebSocketVersionV13(),
        const .server('Ion/1.0'),
        .setCookieFromCookie(Cookie('id', 'a3fWa')),
        const .trailer(['Expires']),
        const .upgradeWebsocket(),
        const .userAgent('IonTest/1.0'),
        const TestCustomHeader('via', '1.0 fred'),
        const TestCustomHeader('warning', '199 Miscellaneous warning'),
        const .wwwAuthenticate([.basic(realm: 'Access')]),
        .referrerPolicy(const .noReferrer()),
        const .strictTransportSecurityIncludingSubdomains(
          Duration(seconds: 31536000),
        ),
        const .teTrailers(),
        const .vary(['Accept-Encoding']),
        const .xContentTypeOptionsNosniff(),
      ]);

      expect(headers.acceptRanges, isNotNull);
      expect(headers.accessControlAllowCredentials, isNotNull);
      expect(headers.accessControlAllowHeaders, isNotNull);
      expect(headers.accessControlAllowMethods, isNotNull);
      expect(headers.accessControlAllowOrigin, isNotNull);
      expect(headers.accessControlExposeHeaders, isNotNull);
      expect(headers.accessControlMaxAge, isNotNull);
      expect(headers.accessControlRequestHeaders, isNotNull);
      expect(headers.accessControlRequestMethod, isNotNull);
      expect(headers.age, isNotNull);
      expect(headers.allow, isNotNull);
      expect(headers.authorization, isNotNull);
      expect(headers.contentDisposition, isNotNull);
      expect(headers.contentEncoding, isNotNull);
      expect(headers.contentLocation, isNotNull);
      expect(headers.contentRange, isNotNull);
      expect(headers.cookie, isNotNull);
      expect(headers.date, isNotNull);
      expect(headers.etag, isNotNull);
      expect(headers.expect, isNotNull);
      expect(headers.expires, isNotNull);
      expect(headers.from, isNotNull);
      expect(headers.ifMatch, isNotNull);
      expect(headers.ifModifiedSince, isNotNull);
      expect(headers.ifNoneMatch, isNotNull);
      expect(headers.ifRange, isNotNull);
      expect(headers.ifUnmodifiedSince, isNotNull);
      expect(headers.lastModified, isNotNull);
      expect(headers.location, isNotNull);
      expect(headers.maxForwards, isNotNull);
      expect(headers.origin, isNotNull);
      expect(headers.pragma, isNotNull);
      expect(headers.proxyAuthenticate, isNotNull);
      expect(headers.proxyAuthorization, isNotNull);
      expect(headers.range, isNotNull);
      expect(headers.referer, isNotNull);
      expect(headers.referrerPolicy, isNotNull);
      expect(headers.retryAfter, isNotNull);
      expect(headers.secWebSocketAccept, isNotNull);
      expect(headers.secWebSocketKey, isNotNull);
      expect(headers.secWebSocketProtocol, isNotNull);
      expect(headers.secWebSocketVersion, isNotNull);
      expect(headers.server, isNotNull);
      expect(headers.setCookie, isNotNull);
      expect(headers.strictTransportSecurity, isNotNull);
      expect(headers.te, isNotNull);
      expect(headers.trailer, isNotNull);
      expect(headers.upgrade, isNotNull);
      expect(headers.userAgent, isNotNull);
      expect(headers.vary, isNotNull);
      expect(headers.wwwAuthenticate, isNotNull);
      expect(headers.xContentTypeOptions, isNotNull);
    });

    test('raw() returns raw values and caches result', () {
      final headers = TypedHeaders.fromList([
        const TestCustomHeader('x-custom-header', 'val1, val2'),
      ]);

      final firstCall = headers.raw(const HttpHeader('x-custom-header'));
      expect(firstCall, equals(['val1, val2']));

      final secondCall = headers.raw(const HttpHeader('x-custom-header'));
      expect(identical(firstCall, secondCall), isTrue);

      final missingCall = headers.raw(const HttpHeader('x-missing'));
      expect(missingCall, isEmpty);
      final missingCallCached = headers.raw(const HttpHeader('x-missing'));
      expect(identical(missingCall, missingCallCached), isTrue);
    });

    test('detects empty or invalid Transfer-Encoding header', () {
      final invalidHeaders = TypedHeaders.fromList([
        const TestCustomHeader('transfer-encoding', ''),
      ]);

      expect(invalidHeaders.isTransferEncodingInvalid, isTrue);
    });
  });
}
