import 'package:ion_web/src/http/http.dart';
import 'package:test/test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('HttpParser', () {
    late HttpParser parser;

    setUp(() {
      parser = HttpParser();
    });

    group('HTTP Methods', () {
      final methods = <String, HttpMethod>{
        'GET': .get,
        'PUT': .put,
        'POST': .post,
        'HEAD': .head,
        'PATCH': .patch,
        'TRACE': .trace,
        'DELETE': .delete,
        'OPTIONS': .options,
        'CONNECT': .connect,
        'QUERY': const HttpMethod('QUERY'),
      };

      methods.forEach((name, expectedMethod) {
        test('parses method $name', () {
          final raw = stringToBytes(
            '$name / HTTP/1.1\r\nHost: example.com\r\n\r\n',
          );
          final result = parser.feed(raw);
          expect(result, isNotNull);
          expect(result!.method, expectedMethod);
        });
      });

      test('throws HttpParserException on invalid character in method', () {
        final raw = stringToBytes(
          'GE\nT / HTTP/1.1\r\nHost: example.com\r\n\r\n',
        );
        expect(
          () => parser.feed(raw),
          throwsA(
            isA<HttpParserException>().having(
              (e) => e.message,
              'message',
              contains('Invalid character in method'),
            ),
          ),
        );
      });
    });

    group('HTTP Versions', () {
      test('parses HTTP/1.0', () {
        final raw = stringToBytes(
          'GET / HTTP/1.0\r\nHost: example.com\r\n\r\n',
        );
        final result = parser.feed(raw);
        expect(result, isNotNull);
        expect(result!.version, HttpVersion.http10);
      });

      test('parses HTTP/1.1', () {
        final raw = stringToBytes(
          'GET / HTTP/1.1\r\nHost: example.com\r\n\r\n',
        );
        final result = parser.feed(raw);
        expect(result, isNotNull);
        expect(result!.version, HttpVersion.http11);
      });

      test('parses custom major/minor version HTTP/2.0', () {
        final raw = stringToBytes(
          'GET / HTTP/2.0\r\nHost: example.com\r\n\r\n',
        );
        final result = parser.feed(raw);
        expect(result, isNotNull);
        expect(result!.version, HttpVersion.http20);
      });

      test('throws for invalid HTTP version length', () {
        final raw = stringToBytes('GET / HTTP/1\r\nHost: example.com\r\n\r\n');
        expect(
          () => parser.feed(raw),
          throwsA(
            isA<HttpParserException>().having(
              (e) => e.message,
              'message',
              contains('Invalid HTTP version length'),
            ),
          ),
        );
      });

      test('throws for invalid HTTP version prefix', () {
        final raw = stringToBytes(
          'GET / HXXX/1.1\r\nHost: example.com\r\n\r\n',
        );
        expect(
          () => parser.feed(raw),
          throwsA(
            isA<HttpParserException>().having(
              (e) => e.message,
              'message',
              contains('Invalid HTTP version prefix'),
            ),
          ),
        );
      });

      test('throws for invalid HTTP version separator', () {
        final raw = stringToBytes(
          'GET / HTTP/1_1\r\nHost: example.com\r\n\r\n',
        );
        expect(
          () => parser.feed(raw),
          throwsA(
            isA<HttpParserException>().having(
              (e) => e.message,
              'message',
              contains('Invalid HTTP version separator'),
            ),
          ),
        );
      });

      test('throws for invalid HTTP version digits', () {
        final raw = stringToBytes(
          'GET / HTTP/A.B\r\nHost: example.com\r\n\r\n',
        );
        expect(
          () => parser.feed(raw),
          throwsA(
            isA<HttpParserException>().having(
              (e) => e.message,
              'message',
              contains('Invalid HTTP version digits'),
            ),
          ),
        );
      });
    });

    group('URL and URI validation', () {
      test('parses request with query parameters', () {
        final raw = stringToBytes(
          'GET /search?q=dart&lang=en HTTP/1.1\r\n\r\n',
        );
        final result = parser.feed(raw);
        expect(result, isNotNull);
        expect(result!.uri.path, '/search');
        expect(result.uri.queryParameters, {'q': 'dart', 'lang': 'en'});
      });

      test('parses OPTIONS request with asterisk URI', () {
        final raw = stringToBytes('OPTIONS * HTTP/1.1\r\n\r\n');
        final result = parser.feed(raw);
        expect(result, isNotNull);
        expect(result!.method, HttpMethod.options);
        expect(result.uri.toString(), '*');
      });

      test('throws for asterisk URI on non-OPTIONS method', () {
        final raw = stringToBytes('GET * HTTP/1.1\r\n\r\n');
        expect(
          () => parser.feed(raw),
          throwsA(
            isA<HttpParserException>().having(
              (e) => e.message,
              'message',
              contains('Asterisk-form URI is only allowed for OPTIONS'),
            ),
          ),
        );
      });

      test('throws for invalid character in URL', () {
        final raw = stringToBytes('GET /foo\x00bar HTTP/1.1\r\n\r\n');
        expect(
          () => parser.feed(raw),
          throwsA(
            isA<HttpParserException>().having(
              (e) => e.message,
              'message',
              contains('Invalid character in URL'),
            ),
          ),
        );
      });

      test('throws for invalid URI syntax', () {
        final raw = stringToBytes('GET http://[invalid-ipv6/ HTTP/1.1\r\n\r\n');
        expect(
          () => parser.feed(raw),
          throwsA(
            isA<HttpParserException>().having(
              (e) => e.message,
              'message',
              contains('Invalid URI'),
            ),
          ),
        );
      });
    });

    group('Header parsing and normalization', () {
      test('normalizes header keys to lower case', () {
        final raw = stringToBytes(
          'GET / HTTP/1.1\r\n'
          'Host: example.com\r\n'
          'X-Custom-Header: Value\r\n'
          'CONTENT-TYPE: text/plain\r\n'
          '\r\n',
        );

        final result = parser.feed(raw);

        expect(result, isNotNull);
        final headers = TypedHeaders(result!.headerSlices);
        expect(headers.host?.host, 'example.com');
        expect(
          headers
              .decode(
                const HttpHeader('x-custom-header'),
                TestCustomHeader.decode,
              )
              ?.value,
          'Value',
        );
        expect(headers.contentType?.mediaType, 'text/plain');
      });

      test('combines duplicate headers with comma', () {
        final raw = stringToBytes(
          'GET / HTTP/1.1\r\n'
          'Accept: text/html\r\n'
          'ACCEPT: application/json\r\n'
          'accept: text/plain\r\n'
          '\r\n',
        );

        final result = parser.feed(raw);

        expect(result, isNotNull);
        final headers = TypedHeaders(result!.headerSlices);
        final combined = headers.decode(
          HttpHeader.accept,
          TestCustomHeader.decode,
        );
        expect(
          combined?.value,
          'text/html, application/json, text/plain',
        );
      });

      test('throws for invalid character in header key', () {
        final raw = stringToBytes('GET / HTTP/1.1\r\nBad Header: val\r\n\r\n');
        expect(
          () => parser.feed(raw),
          throwsA(
            isA<HttpParserException>().having(
              (e) => e.message,
              'message',
              contains('Invalid character in header key'),
            ),
          ),
        );
      });

      test('throws for invalid character in header value', () {
        final raw = stringToBytes(
          'GET / HTTP/1.1\r\nHeader: val\x01ue\r\n\r\n',
        );
        expect(
          () => parser.feed(raw),
          throwsA(
            isA<HttpParserException>().having(
              (e) => e.message,
              'message',
              contains('Invalid character in header value'),
            ),
          ),
        );
      });

      test('throws for bare CR in header value', () {
        final raw = stringToBytes('GET / HTTP/1.1\r\nX-Test: val\rue\r\n\r\n');
        expect(
          () => parser.feed(raw),
          throwsA(
            isA<HttpParserException>().having(
              (e) => e.message,
              'message',
              contains('Bare CR in header value'),
            ),
          ),
        );
      });

      test('throws for empty header field-name', () {
        final raw = stringToBytes('GET / HTTP/1.1\r\n: value\r\n\r\n');
        expect(
          () => parser.feed(raw),
          throwsA(
            isA<HttpParserException>().having(
              (e) => e.message,
              'message',
              contains('Empty header field-name'),
            ),
          ),
        );
      });

      test('throws for missing colon delimiter', () {
        final raw = stringToBytes(
          'GET / HTTP/1.1\r\nHostHeaderWithoutColon\r\n\r\n',
        );
        expect(
          () => parser.feed(raw),
          throwsA(isA<HttpParserException>()),
        );
      });

      test('throws for bare LF without CR in header value', () {
        final raw = stringToBytes('GET / HTTP/1.1\r\nHost: example.com\n\r\n');
        expect(
          () => parser.feed(raw),
          throwsA(
            isA<HttpParserException>().having(
              (e) => e.message,
              'message',
              contains('Invalid line ending: expected CRLF'),
            ),
          ),
        );
      });
    });

    group('Buffer limits and state management', () {
      test('handles incremental chunk feeding byte by byte', () {
        final raw = stringToBytes(
          'POST /submit HTTP/1.1\r\n'
          'Host: example.com\r\n'
          'Content-Length: 5\r\n'
          '\r\n',
        );

        HttpRequestHead? result;
        for (var i = 0; i < raw.length; i++) {
          final chunk = Uint8List.fromList([raw[i]]);
          result = parser.feed(chunk);
          if (i < raw.length - 1) {
            expect(result, isNull);
          }
        }

        expect(result, isNotNull);
        expect(result!.method, HttpMethod.post);
        expect(TypedHeaders(result.headerSlices).contentLength?.length, 5);
      });

      test('throws when exceeding maxHeaderSize', () {
        final smallParser = HttpParser(maxHeaderSize: 30);
        final raw = stringToBytes(
          'GET /very/long/path/that/exceeds/buffer/size HTTP/1.1\r\n\r\n',
        );

        expect(
          () => smallParser.feed(raw),
          throwsA(
            isA<HttpParserException>().having(
              (e) => e.message,
              'message',
              contains('exceeds size limit'),
            ),
          ),
        );
      });

      test('throws when exceeding maxHeaderCount', () {
        final limitedParser = HttpParser(maxHeaderCount: 3);
        final raw = stringToBytes(
          'GET / HTTP/1.1\r\n'
          'H1: 1\r\n'
          'H2: 2\r\n'
          'H3: 3\r\n'
          'H4: 4\r\n'
          '\r\n',
        );

        expect(
          () => limitedParser.feed(raw),
          throwsA(
            isA<HttpParserException>().having(
              (e) => e.message,
              'message',
              contains('count exceeds limit'),
            ),
          ),
        );
      });

      test('resets parser state correctly', () {
        final rawPartial = stringToBytes('GET /index.html HTTP/1.1\r\nHost: ');
        parser.feed(rawPartial);

        parser.reset();

        final rawFull = stringToBytes(
          'POST /data HTTP/1.1\r\n'
          'Host: example.org\r\n'
          '\r\n',
        );

        final result = parser.feed(rawFull);
        expect(result, isNotNull);
        expect(result!.method, HttpMethod.post);
        expect(result.uri.path, '/data');
        expect(TypedHeaders(result.headerSlices).host?.host, 'example.org');
      });
    });
  });
}
