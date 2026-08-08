import 'dart:async';
import 'dart:io';

import 'package:ion_web/ion_web.dart';
import 'package:test/test.dart';

import '../helpers/helpers.dart';

void main() {
  group('RequestMultipartExtension basics', () {
    test('isMultipart returns correct status', () {
      final req1 = TestRequestBuilder.multipart(
        boundary: 'abc',
        body: [],
      ).build();
      expect(req1.isMultipart, isTrue);

      final req2 = TestRequestBuilder.post('/upload')
          .headers([
            const .contentType('multipart/mixed; boundary=abc'),
            const .contentLength(0),
          ])
          .bodyBytes([])
          .build();
      expect(req2.isMultipart, isTrue);

      final req3 = TestRequestBuilder.post('/upload')
          .headers([
            const .contentTypeJson(),
            const .contentLength(0),
          ])
          .bodyBytes([])
          .build();
      expect(req3.isMultipart, isFalse);
    });

    test('throws NotMultipartException when content-type is not multipart', () {
      final req = TestRequestBuilder.post('/upload')
          .headers([
            const .contentTypeJson(),
            const .contentLength(0),
          ])
          .bodyBytes([])
          .build();
      expect(
        req.multipartStream,
        throwsA(isA<NotMultipartException>()),
      );
    });

    test('throws MissingBoundaryException when boundary is absent', () {
      final req = TestRequestBuilder.post('/upload')
          .headers([
            const .contentType('multipart/form-data'),
            const .contentLength(0),
          ])
          .bodyBytes([])
          .build();
      expect(
        req.multipartStream,
        throwsA(isA<MissingBoundaryException>()),
      );
    });
  });

  group('RFC 7578 & RFC 2046 Spec Compliance', () {
    test(
      'ignores Preamble before first boundary and Epilogue after last',
      () async {
        const boundary = 'myboundary';
        const bodyText =
            'This is preamble text that should be ignored by the parser.\r\n'
            '--myboundary\r\n'
            'Content-Disposition: form-data; name="field1"\r\n\r\n'
            'value1\r\n'
            '--myboundary--\r\n'
            'This is epilogue text that should also be ignored.';

        final req = TestRequestBuilder.multipart(
          boundary: boundary,
          body: utf8.encode(bodyText),
        ).build();

        final parts = await req.multipartStream().toList();
        expect(parts.length, equals(1));
        expect(parts[0].name, equals('field1'));
        expect(await parts[0].text(), equals('value1'));
      },
    );

    test(
      'handles Transport Padding (spaces and tabs) after boundary',
      () async {
        const boundary = 'padded_boundary';
        const bodyText =
            '--padded_boundary \t \r\n'
            'Content-Disposition: form-data; name="padded"\r\n\r\n'
            'data\r\n'
            '--padded_boundary--\t ';

        final req = TestRequestBuilder.multipart(
          boundary: boundary,
          body: utf8.encode(bodyText),
        ).build();

        final form = await req.multipart();
        expect(form.field('padded'), equals('data'));
      },
    );

    test('handles Mixed-Case Headers and Bare LF Line Endings', () async {
      const boundary = 'lf_boundary';
      const bodyText =
          '--lf_boundary\n'
          'CONTENT-DISPOSITION: FORM-DATA; NAME="mixed_case"\n'
          'CONTENT-TYPE: TEXT/PLAIN\n\n'
          'payload_with_lf\n'
          '--lf_boundary--\n';

      final req = TestRequestBuilder.multipart(
        boundary: boundary,
        body: utf8.encode(bodyText),
      ).build();

      final parts = await req.multipartStream().toList();
      expect(parts.length, equals(1));
      expect(parts[0].name, equals('mixed_case'));
      expect(parts[0].contentType, equals('TEXT/PLAIN'));
      expect(await parts[0].text(), equals('payload_with_lf'));
    });

    test(
      'parses Byte-by-Byte (Split Boundaries and Headers across chunks)',
      () async {
        const boundary = 'split_boundary';
        const bodyText =
            '--split_boundary\r\n'
            'Content-Disposition: form-data; name="split_field"\r\n\r\n'
            'split_data_content\r\n'
            '--split_boundary--\r\n';

        final fullBytes = utf8.encode(bodyText);
        final controller = StreamController<Uint8List>();
        final req = TestRequestBuilder.post('/upload')
            .headers([
              const .contentType(
                'multipart/form-data; boundary=$boundary',
              ),
            ])
            .bodyStream(controller.stream)
            .build();

        final stream = req.multipartStream();

        // Feed bytes 1 by 1 asynchronously to test boundary splitting
        // across chunk boundaries
        scheduleMicrotask(() async {
          for (final b in fullBytes) {
            controller.add(Uint8List.fromList([b]));
            await Future<void>.delayed(Duration.zero);
          }
          await controller.close();
        });

        final parts = await stream.toList();
        expect(parts.length, equals(1));
        expect(parts[0].name, equals('split_field'));
        expect(await parts[0].text(), equals('split_data_content'));
      },
    );

    test('parses Empty Part Payloads correctly', () async {
      const boundary = 'empty_boundary';
      const bodyText =
          '--empty_boundary\r\n'
          'Content-Disposition: form-data; name="empty_file"; '
          'filename="empty.dat"\r\n'
          'Content-Type: application/octet-stream\r\n\r\n'
          '\r\n'
          '--empty_boundary--\r\n';

      final req = TestRequestBuilder.multipart(
        boundary: boundary,
        body: utf8.encode(bodyText),
      ).build();

      final form = await req.multipart();
      final file = form.file('empty_file');
      expect(file, isNotNull);
      expect(file!.filename, equals('empty.dat'));
      expect(file.size, equals(0));
      expect(await file.bytes(), equals(Uint8List(0)));
    });

    test(
      'strips directory paths from filename for Path Traversal Protection',
      () async {
        const boundary = 'security_boundary';
        const bodyText =
            '--security_boundary\r\n'
            'Content-Disposition: form-data; name="f1"; '
            r'filename="C:\\Users\\Admin\\Desktop\\secret.txt"'
            '\r\n\r\n'
            'content1\r\n'
            '--security_boundary\r\n'
            'Content-Disposition: form-data; name="f2"; '
            'filename="/var/log/syslog"'
            '\r\n\r\n'
            'content2\r\n'
            '--security_boundary--\r\n';

        final req = TestRequestBuilder.multipart(
          boundary: boundary,
          body: utf8.encode(bodyText),
        ).build();

        final form = await req.multipart();
        expect(form.file('f1')?.filename, equals('secret.txt'));
        expect(form.file('f2')?.filename, equals('syslog'));
        await form.clean();
      },
    );

    test(
      'supports Multiple Fields and Files with the same field name',
      () async {
        const boundary = 'multi_name_boundary';
        const bodyText =
            '--multi_name_boundary\r\n'
            'Content-Disposition: form-data; name="tags"\r\n\r\n'
            'dart\r\n'
            '--multi_name_boundary\r\n'
            'Content-Disposition: form-data; name="tags"\r\n\r\n'
            'web\r\n'
            '--multi_name_boundary--\r\n';

        final req = TestRequestBuilder.multipart(
          boundary: boundary,
          body: utf8.encode(bodyText),
        ).build();

        final form = await req.multipart();
        expect(form.fields['tags'], equals(['dart', 'web']));
        expect(form.field('tags'), equals('dart'));
      },
    );
  });

  group('multipart buffering into MultipartForm', () {
    test('parses into memory form correctly', () async {
      const boundary = 'boundary123';
      const bodyText =
          '--boundary123\r\n'
          'Content-Disposition: form-data; name="title"\r\n\r\n'
          'My Document\r\n'
          '--boundary123\r\n'
          'Content-Disposition: form-data; name="doc"; filename="notes.txt"\r\n'
          'Content-Type: text/plain\r\n\r\n'
          'File Content Here\r\n'
          '--boundary123--\r\n';

      final req = TestRequestBuilder.multipart(
        boundary: boundary,
        body: utf8.encode(bodyText),
      ).build();

      final form = await req.multipart();
      expect(form.field('title'), equals('My Document'));

      final file = form.file('doc');
      expect(file, isNotNull);
      expect(file!.filename, equals('notes.txt'));
      expect(file.isInMemory, isTrue);
      expect(await file.text(), equals('File Content Here'));

      await form.clean();
    });

    test('spools large files to disk when maxMemory is exceeded', () async {
      const boundary = 'boundary123';
      final fileData = 'A' * 100;
      final bodyText =
          '--boundary123\r\n'
          'Content-Disposition: form-data; name="bigfile"; '
          'filename="big.txt"\r\n'
          'Content-Type: text/plain\r\n\r\n'
          '$fileData\r\n'
          '--boundary123--\r\n';

      final req = TestRequestBuilder.multipart(
        boundary: boundary,
        body: utf8.encode(bodyText),
      ).build();

      // Force maxMemory to 50 bytes so 100 bytes file spools to disk
      final form = await req.multipart(maxMemory: 50);

      final file = form.file('bigfile');
      expect(file, isNotNull);
      expect(file!.isOnDisk, isTrue);
      expect(file.size, equals(100));
      expect(await file.text(), equals(fileData));

      // Clean up disk temp file
      await form.clean();
    });

    test('enforces maxParts limit', () async {
      const boundary = 'boundary123';
      const bodyText =
          '--boundary123\r\n'
          'Content-Disposition: form-data; name="f1"\r\n\r\n'
          'v1\r\n'
          '--boundary123\r\n'
          'Content-Disposition: form-data; name="f2"\r\n\r\n'
          'v2\r\n'
          '--boundary123--\r\n';

      final req = TestRequestBuilder.multipart(
        boundary: boundary,
        body: utf8.encode(bodyText),
      ).build();

      expect(
        () => req.multipart(maxParts: 1),
        throwsA(isA<MultipartException>()),
      );
    });

    test('enforces maxFieldsMemory limit', () async {
      const boundary = 'boundary123';
      const bodyText =
          '--boundary123\r\n'
          'Content-Disposition: form-data; name="large"\r\n\r\n'
          '1234567890\r\n'
          '--boundary123--\r\n';

      final req = TestRequestBuilder.multipart(
        boundary: boundary,
        body: utf8.encode(bodyText),
      ).build();

      expect(
        () => req.multipart(maxFieldsMemory: 5),
        throwsA(isA<MultipartException>()),
      );
    });
  });

  group('Resilience & Premature Stream Termination', () {
    test('does NOT hang when source stream terminates mid-part', () async {
      final controller = StreamController<Uint8List>();
      final req = TestRequestBuilder.post('/upload')
          .headers([
            const .contentType(
              'multipart/form-data; boundary=xxx',
            ),
          ])
          .bodyStream(controller.stream)
          .build();

      final stream = req.multipartStream();

      // Start part but do NOT send ending boundary
      controller.add(
        Uint8List.fromList(
          utf8.encode(
            '--xxx\r\n'
            'Content-Disposition: form-data; name="field"\r\n\r\n'
            'incomplete payload...',
          ),
        ),
      );

      // Prematurely close source stream
      scheduleMicrotask(controller.close);

      var partCount = 0;
      var caughtError = false;

      try {
        await for (final part in stream) {
          partCount++;
          await part.bytes(); // reading part bytes should throw, not hang!
        }
      } catch (e) {
        caughtError = true;
        expect(e, isA<MultipartException>());
      }

      expect(partCount, equals(1));
      expect(caughtError, isTrue);
    });

    test(
      'cleans up temp files when client disconnects or socket errors',
      () async {
        final controller = StreamController<Uint8List>();
        final req = TestRequestBuilder.post('/upload')
            .headers([
              const .contentType(
                'multipart/form-data; boundary=xxx',
              ),
            ])
            .bodyStream(controller.stream)
            .build();

        final tempDirsBefore = Directory.systemTemp
            .listSync()
            .whereType<Directory>()
            .where((d) => d.path.contains('ion_upload_'))
            .map((d) => d.path)
            .toSet();

        // Start large file upload exceeding maxMemory (100 bytes)
        controller.add(
          Uint8List.fromList(
            utf8.encode(
              '--xxx\r\n'
              'Content-Disposition: form-data; name="file"; '
              'filename="test.bin"\r\n\r\n'
              '${'A' * 200}',
            ),
          ),
        );

        // Simulate client socket disconnect / reset mid-transfer
        scheduleMicrotask(() {
          controller.addError(
            const SocketException('Connection reset by peer'),
          );
        });

        Object? caughtError;
        try {
          await req.multipart(maxMemory: 100);
        } catch (e) {
          caughtError = e;
        }

        expect(caughtError, isA<MultipartException>());

        // Verify no temporary ion_upload_ directories were leaked on disk!
        final tempDirsAfter = Directory.systemTemp
            .listSync()
            .whereType<Directory>()
            .where((d) => d.path.contains('ion_upload_'))
            .map((d) => d.path)
            .toSet();
        final leakedDirs = tempDirsAfter.difference(tempDirsBefore);
        expect(leakedDirs, isEmpty);

        await controller.close();
      },
    );

    test(
      'spools file to DiskMultipartFile when size exceeds maxMemory and '
      'supports openRead(), bytes(), and clean()',
      () async {
        const boundary = 'diskboundary';
        final bodyText =
            '--$boundary\r\n'
            'Content-Disposition: form-data; name="largefile"; '
            'filename="large.bin"\r\n'
            'Content-Type: application/octet-stream\r\n\r\n'
            '${'X' * 500}\r\n'
            '--$boundary--\r\n';

        final req = TestRequestBuilder.multipart(
          boundary: boundary,
          body: utf8.encode(bodyText),
        ).build();

        final form = await req.multipart(maxMemory: 100);
        expect(form.files['largefile'], hasLength(1));

        final diskFile = form.files['largefile']!.first as DiskMultipartFile;
        expect(diskFile.size, equals(500));
        expect(diskFile.tempPath, contains('ion_upload_'));

        // Test openRead()
        final chunks = await diskFile.openRead().toList();
        final contentFromStream = utf8.decode(chunks.expand((c) => c).toList());
        expect(contentFromStream, equals('X' * 500));

        // Test bytes()
        final contentFromBytes = utf8.decode(await diskFile.bytes());
        expect(contentFromBytes, equals('X' * 500));

        // Test clean()
        await form.clean();
        expect(File(diskFile.tempPath).existsSync(), isFalse);
      },
    );

    test(
      'transforms non-MultipartException in stream to MultipartException',
      () async {
        final controller = StreamController<Uint8List>();
        final req = TestRequestBuilder.post('/upload')
            .headers([
              const .contentType(
                'multipart/form-data; boundary=myboundary',
              ),
            ])
            .bodyStream(controller.stream)
            .build();

        final stream = req.multipartStream();
        final expectation = expectLater(
          stream.drain<void>(),
          throwsA(isA<MultipartException>()),
        );

        controller.addError(StateError('Unexpected generic stream error'));
        await controller.close();

        await expectation;
      },
    );

    test('InMemoryMultipartFile.openRead emits in-memory file bytes', () async {
      final fileData = Uint8List.fromList(utf8.encode('in-memory data'));
      final memoryFile = InMemoryMultipartFile(
        name: 'field',
        filename: 'file.txt',
        contentType: 'text/plain',
        bytes: fileData,
      );

      final chunks = await memoryFile.openRead().toList();
      expect(utf8.decode(chunks.single), equals('in-memory data'));
      expect(await memoryFile.bytes(), equals(fileData));
    });
  });
}
