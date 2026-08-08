import 'dart:convert';
import 'dart:typed_data';

import 'package:ion_extra/ion_extra.dart';
import 'package:ion_web/ion_web.dart';

/// Represents a field or file entry inside [TestBody.formData].
sealed class FormDataPart {
  const FormDataPart();

  /// A plain text form field.
  const factory FormDataPart.field(String value) = _FieldFormDataPart;

  /// A file form field with binary bytes.
  const factory FormDataPart.file(
    Uint8List bytes, {
    required String filename,
    String? contentType,
  }) = _FileFormDataPart;
}

final class _FieldFormDataPart extends FormDataPart {
  const _FieldFormDataPart(this.value);

  final String value;
}

final class _FileFormDataPart extends FormDataPart {
  const _FileFormDataPart(
    this.bytes, {
    required this.filename,
    this.contentType,
  });

  final Uint8List bytes;
  final String filename;
  final String? contentType;
}

/// Represents a payload body for a request in `IonTestClient`.
sealed class TestBody {
  const TestBody();

  /// An empty request body.
  const factory TestBody.empty() = _EmptyTestBody;

  /// A plain text request body encoded as UTF-8.
  factory TestBody.text(String text) = _TextTestBody;

  /// A raw byte payload request body.
  factory TestBody.bytes(Uint8List bytes) = _BytesTestBody;

  /// A raw JSON request body serialized via [jsonEncode].
  factory TestBody.rawJson(Object? data) = _RawJsonTestBody;

  /// A JSON request body serialized from a [ToJson] instance.
  factory TestBody.json(ToJson data) = _JsonTestBody;

  /// A JSON array request body serialized from an iterable of [ToJson]
  /// instances.
  factory TestBody.jsonList(Iterable<ToJson> data) = _JsonListTestBody;

  /// A URL-encoded form request body (`application/x-www-form-urlencoded`).
  factory TestBody.formUrlEncoded(
    Map<String, String> fields,
  ) = _FormUrlEncodedTestBody;

  /// A multipart form-data request body (`multipart/form-data`).
  factory TestBody.formData(
    Map<String, FormDataPart> fields, {
    String boundary,
  }) = _FormDataTestBody;

  /// Builds the byte payload and default headers for this body.
  (Uint8List bytes, List<TypedHeader> headers) build();
}

final class _EmptyTestBody extends TestBody {
  const _EmptyTestBody();

  @override
  (Uint8List, List<TypedHeader>) build() => (Uint8List(0), const []);
}

final class _TextTestBody extends TestBody {
  _TextTestBody(this.text);

  final String text;

  @override
  (Uint8List, List<TypedHeader>) build() => (
    Uint8List.fromList(utf8.encode(text)),
    const [.contentTypeTextUtf8()],
  );
}

final class _BytesTestBody extends TestBody {
  _BytesTestBody(this.bytes);

  final Uint8List bytes;

  @override
  (Uint8List, List<TypedHeader>) build() => (bytes, const []);
}

final class _RawJsonTestBody extends TestBody {
  _RawJsonTestBody(this.data);

  final Object? data;

  @override
  (Uint8List, List<TypedHeader>) build() => (
    Uint8List.fromList(utf8.encode(jsonEncode(data))),
    const [.contentTypeJson()],
  );
}

final class _JsonTestBody extends TestBody {
  _JsonTestBody(this.data);

  final ToJson data;

  @override
  (Uint8List, List<TypedHeader>) build() => (
    Uint8List.fromList(utf8.encode(jsonEncode(data.toJson()))),
    const [.contentTypeJson()],
  );
}

final class _JsonListTestBody extends TestBody {
  _JsonListTestBody(this.data);

  final Iterable<ToJson> data;

  @override
  (Uint8List, List<TypedHeader>) build() => (
    Uint8List.fromList(
      utf8.encode(jsonEncode([for (final item in data) item.toJson()])),
    ),
    const [.contentTypeJson()],
  );
}

final class _FormUrlEncodedTestBody extends TestBody {
  _FormUrlEncodedTestBody(this.fields);

  final Map<String, String> fields;

  @override
  (Uint8List, List<TypedHeader>) build() {
    final payload = fields.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}='
              '${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    return (
      Uint8List.fromList(utf8.encode(payload)),
      const [.contentTypeFormUrlEncoded()],
    );
  }
}

final class _FormDataTestBody extends TestBody {
  _FormDataTestBody(
    this.fields, {
    this.boundary = '----IonTestBoundary',
  });

  final Map<String, FormDataPart> fields;
  final String boundary;

  @override
  (Uint8List, List<TypedHeader>) build() {
    final buffer = BytesBuilder();
    for (final entry in fields.entries) {
      buffer.add(utf8.encode('--$boundary\r\n'));
      switch (entry.value) {
        case _FieldFormDataPart(:final value):
          buffer.add(
            utf8.encode(
              'Content-Disposition: form-data; name="${entry.key}"\r\n\r\n'
              '$value',
            ),
          );
        case _FileFormDataPart(
          :final bytes,
          :final filename,
          :final contentType,
        ):
          buffer.add(
            utf8.encode(
              'Content-Disposition: form-data; name="${entry.key}"; '
              'filename="$filename"\r\n',
            ),
          );
          if (contentType != null) {
            buffer.add(utf8.encode('Content-Type: $contentType\r\n'));
          }
          buffer.add(utf8.encode('\r\n'));
          buffer.add(bytes);
      }
      buffer.add(utf8.encode('\r\n'));
    }
    buffer.add(utf8.encode('--$boundary--\r\n'));

    return (
      buffer.takeBytes(),
      [.contentTypeMultipartFormData(boundary: boundary)],
    );
  }
}
