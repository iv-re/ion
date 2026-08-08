import 'dart:typed_data';

import 'package:ion_web/src/http/utils.dart';
import 'package:test/test.dart';

void main() {
  group('CharUtils', () {
    test('identifies space, cr, lf, colon, semicolon', () {
      expect(32.isSpace, isTrue);
      expect(33.isSpace, isFalse);

      expect(13.isCr, isTrue);
      expect(12.isCr, isFalse);

      expect(10.isLf, isTrue);
      expect(11.isLf, isFalse);

      expect(58.isColon, isTrue);
      expect(59.isColon, isFalse);

      expect(59.isSemicolon, isTrue);
      expect(58.isSemicolon, isFalse);
    });
  });

  group('parseHex', () {
    test('parses digits 0-9', () {
      for (var i = 0; i <= 9; i++) {
        final byte = 0x30 + i; // '0'..'9'
        expect(parseHex(byte), equals(i));
      }
    });

    test('parses hex letters a-f and A-F', () {
      expect(parseHex(0x61), equals(10)); // 'a'
      expect(parseHex(0x66), equals(15)); // 'f'
      expect(parseHex(0x41), equals(10)); // 'A'
      expect(parseHex(0x46), equals(15)); // 'F'
    });

    test('returns negative value for non-hex characters', () {
      expect(parseHex(0x67), lessThan(0)); // 'g'
      expect(parseHex(0x20), lessThan(0)); // space
      expect(parseHex(0x3A), lessThan(0)); // ':'
    });
  });

  group('isTchar', () {
    test('returns true for valid tchar bytes', () {
      expect(isTchar(0x61), isTrue); // 'a'
      expect(isTchar(0x5A), isTrue); // 'Z'
      expect(isTchar(0x35), isTrue); // '5'
      expect(isTchar(0x21), isTrue); // '!'
      expect(isTchar(0x2D), isTrue); // '-'
      expect(isTchar(0x5F), isTrue); // '_'
    });

    test('returns false for delimiters and control chars', () {
      expect(isTchar(0x20), isFalse); // space
      expect(isTchar(0x3A), isFalse); // ':'
      expect(isTchar(0x40), isFalse); // '@'
      expect(isTchar(0x2F), isFalse); // '/'
      expect(isTchar(0x7B), isFalse); // '{'
    });
  });

  group('isInvalidHeaderValueChar and isInvalidUrlChar', () {
    test('isInvalidHeaderValueChar flags control characters', () {
      expect(isInvalidHeaderValueChar(0x00), isTrue);
      expect(isInvalidHeaderValueChar(0x07), isTrue);
      expect(isInvalidHeaderValueChar(0x7F), isTrue);
      expect(isInvalidHeaderValueChar(0x20), isFalse); // space is valid
      expect(isInvalidHeaderValueChar(0x61), isFalse); // 'a' is valid
    });

    test('isInvalidUrlChar flags control characters and non-ASCII', () {
      expect(isInvalidUrlChar(0x00), isTrue);
      expect(isInvalidUrlChar(0x0A), isTrue);
      expect(isInvalidUrlChar(0x0D), isTrue);
      expect(isInvalidUrlChar(0x80), isTrue);
      expect(isInvalidUrlChar(0x20), isFalse); // space handled separately
      expect(isInvalidUrlChar(0x61), isFalse); // 'a'
    });
  });

  group('StringAsciiCaseExtension', () {
    test('equalsIgnoreAsciiCase compares strings case-insensitively', () {
      expect('ETag'.equalsIgnoreAsciiCase('etag'), isTrue);
      expect('content-type'.equalsIgnoreAsciiCase('Content-Type'), isTrue);
      expect('Set-Cookie'.equalsIgnoreAsciiCase('set-cookie'), isTrue);
      expect('foo'.equalsIgnoreAsciiCase('bar'), isFalse);
      expect('short'.equalsIgnoreAsciiCase('longer-string'), isFalse);
    });

    test('isAsciiDigits checks if all characters are 0-9', () {
      expect('1234567890'.isAsciiDigits, isTrue);
      expect('0'.isAsciiDigits, isTrue);
      expect(''.isAsciiDigits, isFalse);
      expect('123a'.isAsciiDigits, isFalse);
      expect('-10'.isAsciiDigits, isFalse);
      expect('+10'.isAsciiDigits, isFalse);
      expect(' 10'.isAsciiDigits, isFalse);
    });
  });

  group('ByteWriter and ByteWriterPool', () {
    test('ByteWriter writes bytes, ints, strings and auto-grows', () {
      final writer = ByteWriter(Uint8List(4));
      writer.addByte(0x48); // 'H'
      writer.addAsciiString('i');
      writer.addBytes(Uint8List.fromList([0x20, 0x23])); // ' #'
      writer.addInt(0);
      writer.addInt(12345);

      final result = String.fromCharCodes(writer.view());
      expect(result, equals('Hi #012345'));
    });

    test('ByteWriter reset clears position', () {
      final writer = ByteWriter(Uint8List(16));
      writer.addAsciiString('hello');
      expect(writer.pos, equals(5));

      writer.reset();
      expect(writer.pos, equals(0));
      expect(writer.view(), isEmpty);
    });

    test('ByteWriterPool acquires and releases buffers up to max capacity', () {
      final pool = ByteWriterPool(initialCapacity: 16, maxPoolCapacity: 2);
      final b1 = pool.acquire();
      expect(b1.bytes.length, equals(16));
      b1.addAsciiString('test');

      final b2 = pool.acquire();
      b2.addAsciiString('test2');

      pool.release(b1);
      pool.release(b2);

      // Re-acquire should reuse pooled buffer
      final b3 = pool.acquire();
      expect(b3.pos, equals(0)); // verify reset was called

      final b4 = pool.acquire();
      expect(b4.pos, equals(0));

      // Releasing when pool is at max capacity ignores extra buffers
      final b5 = ByteWriter(Uint8List(16));
      pool.release(b1);
      pool.release(b2);
      pool.release(b5); // pool already full at capacity=2
    });
  });

  group('BytePatternFinder', () {
    test('finds pattern in source bytes correctly', () {
      final finder = BytePatternFinder(
        Uint8List.fromList([13, 10, 13, 10]),
      ); // \r\n\r\n
      final data = Uint8List.fromList(
        'GET / HTTP/1.1\r\nHost: a\r\n\r\nbody'.codeUnits,
      );

      final idx = finder.indexOf(data, 0);
      expect(idx, equals(23));
      expect(
        String.fromCharCodes(data.sublist(idx, idx + 4)),
        equals('\r\n\r\n'),
      );
    });

    test('returns -1 when pattern is not found or invalid inputs', () {
      final finder = BytePatternFinder(Uint8List.fromList([1, 2, 3]));
      final src = Uint8List.fromList([1, 2, 4, 5]);

      expect(finder.indexOf(src, 0), equals(-1));
      expect(finder.indexOf(src, 3), equals(-1)); // start out of bounds
      expect(finder.indexOf(Uint8List(0), 0), equals(-1));

      final emptyFinder = BytePatternFinder(Uint8List(0));
      expect(emptyFinder.indexOf(src, 0), equals(-1));
    });
  });

  group('formatChunkHeader', () {
    test('formats zero length chunk header', () {
      final buf = Uint8List(10);
      final written = formatChunkHeader(buf, 0);
      expect(written, equals(3));
      expect(String.fromCharCodes(buf.sublist(0, written)), equals('0\r\n'));
    });

    test('formats hex length chunk headers correctly', () {
      final buf = Uint8List(10);

      var written = formatChunkHeader(buf, 15); // 0xf
      expect(written, equals(3));
      expect(String.fromCharCodes(buf.sublist(0, written)), equals('f\r\n'));

      written = formatChunkHeader(buf, 255); // 0xff
      expect(written, equals(4));
      expect(String.fromCharCodes(buf.sublist(0, written)), equals('ff\r\n'));

      written = formatChunkHeader(buf, 4096); // 0x1000
      expect(written, equals(6));
      expect(String.fromCharCodes(buf.sublist(0, written)), equals('1000\r\n'));
    });
  });
}
