import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ion_web/src/http/http.dart';
import 'package:ion_web/src/request.dart';

export 'package:ion_web/src/http/multipart.dart'
    show
        MissingBoundaryException,
        MultipartException,
        MultipartPart,
        NotMultipartException;

/// Represents a file received in a multipart request.
///
/// It can be stored either in memory ([InMemoryMultipartFile]) or on disk
/// ([DiskMultipartFile]).
sealed class MultipartFile {
  const MultipartFile({
    required this.name,
    required this.filename,
    required this.contentType,
    required this.size,
  });

  /// The field name associated with the file.
  final String? name;

  /// The original filename of the file.
  final String? filename;

  /// The Content-Type header value of the file, if provided.
  final String? contentType;

  /// The size of the file in bytes.
  final int size;

  /// Returns true if the file is kept in memory.
  bool get isInMemory => this is InMemoryMultipartFile;

  /// Returns true if the file is stored as a temporary file on disk.
  bool get isOnDisk => this is DiskMultipartFile;

  /// Opens a stream to read the file's contents.
  Stream<Uint8List> openRead();

  /// Reads the entire file's bytes.
  Future<Uint8List> bytes();

  /// Cleans up any resources held by the file (e.g. deletes the temporary
  /// file).
  Future<void> clean();

  /// Decodes the file's content into a [String] using the given [decoder]
  /// (defaults to UTF-8).
  Future<String> text({Converter<List<int>, String>? decoder}) async {
    final allBytes = await bytes();
    return (decoder ?? utf8.decoder).convert(allBytes);
  }
}

/// A multipart file implementation that stores the file data in memory.
class InMemoryMultipartFile extends MultipartFile {
  InMemoryMultipartFile({
    required super.name,
    required super.filename,
    required super.contentType,
    required Uint8List bytes,
  }) : _bytes = bytes,
       super(size: bytes.length);

  final Uint8List _bytes;

  @override
  Stream<Uint8List> openRead() => Stream.value(_bytes);

  @override
  Future<Uint8List> bytes() async => _bytes;

  @override
  Future<void> clean() async {}
}

/// A multipart file implementation that stores the file data as a temporary
/// file on disk.
class DiskMultipartFile extends MultipartFile {
  const DiskMultipartFile({
    required super.name,
    required super.filename,
    required super.contentType,
    required super.size,

    /// The absolute path to the temporary file on disk.
    required this.tempPath,

    /// The absolute path to the parent temporary directory.
    required this.tempDirPath,
  });

  final String tempPath;
  final String tempDirPath;

  @override
  Stream<Uint8List> openRead() {
    return File(tempPath).openRead().cast<Uint8List>();
  }

  @override
  Future<Uint8List> bytes() => File(tempPath).readAsBytes();

  @override
  Future<void> clean() async {
    try {
      final dir = Directory(tempDirPath);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }
}

/// Represents a parsed multipart form containing fields and files.
class MultipartForm {
  MultipartForm({
    required Map<String, List<String>> fields,
    required Map<String, List<MultipartFile>> files,
  }) : fields = _unmodifiable(fields),
       files = _unmodifiable(files);

  /// An unmodifiable map of form field names to their values.
  final Map<String, List<String>> fields;

  /// An unmodifiable map of form field names to their uploaded files.
  final Map<String, List<MultipartFile>> files;

  /// Returns the first form field value with the given [name], or null.
  String? field(String name) => fields[name]?.firstOrNull;

  /// Returns the first uploaded file with the given [name], or null.
  MultipartFile? file(String name) => files[name]?.firstOrNull;

  /// Deletes all temporary files stored on disk for this form.
  Future<void> clean() async {
    for (final fileList in files.values) {
      for (final file in fileList) {
        await file.clean();
      }
    }
  }
}

Map<K, List<V>> _unmodifiable<K, V>(Map<K, List<V>> source) {
  return Map.unmodifiable(
    source.map((k, v) => MapEntry(k, List<V>.unmodifiable(v))),
  );
}

/// Extension on [Request] to provide multipart parsing capabilities.
extension RequestMultipartExtension on Request {
  /// Returns true if the request contains 'multipart/form-data' or 'multipart/mixed'.
  bool get isMultipart {
    final mediaType = headers.contentType?.mediaType;
    return mediaType == 'multipart/form-data' || mediaType == 'multipart/mixed';
  }

  String? get _multipartBoundary {
    return headers.contentType?.boundary;
  }

  /// Parses the request body as a stream of [MultipartPart]s.
  ///
  /// Throws [NotMultipartException] if the request is not multipart.
  /// Throws [MissingBoundaryException] if the boundary parameter is missing.
  Stream<MultipartPart> multipartStream() {
    if (!isMultipart) {
      throw const NotMultipartException();
    }

    final boundary = _multipartBoundary;
    if (boundary == null || boundary.isEmpty) {
      throw const MissingBoundaryException();
    }

    final transformer = MultipartStreamTransformer(boundary);

    return cast<List<int>>().transform(transformer).handleError((Object error) {
      if (error is MultipartException) {
        throw error;
      }
      throw MultipartException(error.toString());
    });
  }

  /// Parses the entire request body into a [MultipartForm].
  ///
  /// Uploaded files are kept in memory as [InMemoryMultipartFile] up to
  /// [maxMemory] bytes. Subsequent files exceeding this limit are spooled
  /// to disk as temporary [DiskMultipartFile]s.
  ///
  /// [maxParts] limits the total number of parts (fields and files) in the
  /// request to prevent CPU and descriptor exhaustion.
  ///
  /// [maxFieldsMemory] limits the total memory used by text fields to
  /// prevent memory exhaustion DoS attacks.
  ///
  /// It is highly recommended to call [MultipartForm.clean] once processing
  /// is done to delete any spooled temporary files.
  Future<MultipartForm> multipart({
    int maxMemory = 32 * 1024 * 1024,
    int maxParts = 1000,
    int maxFieldsMemory = 8 * 1024 * 1024,
  }) async {
    final fields = <String, List<String>>{};
    final files = <String, List<MultipartFile>>{};
    var allocatedMemory = 0;
    var allocatedFieldsMemory = 0;
    var partsCount = 0;

    Future<void> cleanupAll() async {
      for (final fileList in files.values) {
        for (final file in fileList) {
          await file.clean();
        }
      }
    }

    try {
      await for (final part in multipartStream()) {
        partsCount++;
        if (partsCount > maxParts) {
          throw const MultipartException('Max parts limit exceeded');
        }

        final name = part.name ?? '';

        if (part.filename == null) {
          final builder = BytesBuilder(copy: false);
          var fieldSize = 0;
          await for (final chunk in part) {
            fieldSize += chunk.length;
            if (allocatedFieldsMemory + fieldSize > maxFieldsMemory) {
              throw const MultipartException('Fields memory limit exceeded');
            }
            builder.add(chunk);
          }

          allocatedFieldsMemory += fieldSize;
          final textValue = utf8.decode(
            builder.takeBytes(),
            allowMalformed: true,
          );
          (fields[name] ??= []).add(textValue);
        } else {
          final parsedFile = await _parseFile(
            part,
            maxMemory - allocatedMemory,
          );

          if (parsedFile is InMemoryMultipartFile) {
            allocatedMemory += parsedFile.size;
          }

          (files[name] ??= []).add(parsedFile);
        }
      }

      return MultipartForm(fields: fields, files: files);
    } catch (e) {
      await cleanupAll();
      if (e is MultipartException) {
        rethrow;
      }
      throw MultipartException(e.toString());
    }
  }
}

Future<MultipartFile> _parseFile(
  MultipartPart part,
  int maxMemoryAvailable,
) async {
  final fileBytesBuilder = BytesBuilder(copy: false);
  String? tempDirPath;
  File? tempFile;
  IOSink? diskSink;
  var isSpoolingToDisk = false;

  var isSuccess = false;
  try {
    await for (final chunk in part) {
      if (!isSpoolingToDisk) {
        if (fileBytesBuilder.length + chunk.length > maxMemoryAvailable) {
          isSpoolingToDisk = true;
          final tempDir = await Directory.systemTemp.createTemp('ion_upload_');
          tempDirPath = tempDir.path;
          final file = File('${tempDir.path}/upload.tmp');
          tempFile = file;
          diskSink = file.openWrite();

          if (fileBytesBuilder.isNotEmpty) {
            diskSink.add(fileBytesBuilder.takeBytes());
          }
          diskSink.add(chunk);
        } else {
          fileBytesBuilder.add(chunk);
        }
      } else {
        diskSink!.add(chunk);
      }
    }

    if (isSpoolingToDisk) {
      await diskSink!.close();
      diskSink = null;

      final size = await tempFile!.length();
      isSuccess = true;
      return DiskMultipartFile(
        name: part.name,
        filename: part.filename,
        contentType: part.contentType,
        size: size,
        tempPath: tempFile.path,
        tempDirPath: tempDirPath!,
      );
    } else {
      final bytes = fileBytesBuilder.takeBytes();
      isSuccess = true;
      return InMemoryMultipartFile(
        name: part.name,
        filename: part.filename,
        contentType: part.contentType,
        bytes: bytes,
      );
    }
  } finally {
    if (!isSuccess) {
      try {
        await diskSink?.close();
      } catch (_) {}
      if (tempDirPath != null) {
        try {
          final dir = Directory(tempDirPath);
          if (dir.existsSync()) {
            await dir.delete(recursive: true);
          }
        } catch (_) {}
      }
    }
  }
}
