import 'dart:convert';
import 'dart:typed_data';

import 'package:ion_extra/src/utils.dart';
import 'package:ion_web/ion_web.dart';
import 'package:json_codable/json_codable.dart';

final Converter<Object?, List<int>> _jsonEncoder = json.encoder.fuse(
  utf8.encoder,
);

final Converter<List<int>, Object?> _jsonDecoder = utf8.decoder.fuse(
  json.decoder,
);

/// An HTTP response containing raw JSON data.
class RawJson extends Response {
  /// Creates a raw JSON response with status [status] and optional [headers].
  RawJson(
    Object? data, {
    super.status = .ok,
    List<TypedHeader> headers = const [],
  }) : super.bytes(
         _jsonEncoder.convert(data) as Uint8List,
         headers: _defaultHeaders.replacing(headers),
       );

  static const List<TypedHeader> _defaultHeaders = [
    .contentType('application/json'),
  ];
}

/// An HTTP response containing JSON data serialized from a [ToJson] instance.
class Json extends RawJson {
  /// Creates a JSON response with status [status] and optional [headers].
  Json(ToJson data, {super.status, super.headers}) : super(data.toJson());
}

/// An HTTP response containing a JSON array serialized from a list of [ToJson]
/// instances.
class JsonList extends RawJson {
  /// Creates a JSON list response with status [status] and optional [headers].
  JsonList(Iterable<ToJson> data, {super.status, super.headers})
    : super([for (final item in data) item.toJson()]);
}

/// Extension on [Request] for extracting and parsing JSON payloads into domain
/// models.
extension RequestJsonExtractor on Request {
  /// Decodes the JSON request body and returns the raw decoded JSON value as
  /// [T].
  ///
  /// Throws [ValidationErrors] if the request body is not valid JSON or if
  /// the decoded JSON is not of type [T].
  Future<T> rawJson<T extends Object?>() async {
    List<Object?> elements;
    try {
      elements = await cast<List<int>>().transform(_jsonDecoder).toList();
    } on FormatException catch (_) {
      throw ValidationErrors()..add(
        r'$',
        const ValidationError(code: 'invalid_json'),
      );
    }

    final value = elements[0];

    if (value is! T) {
      throw ValidationErrors()
        ..add(r'$', .type(expected: typeNameOf<T>(), actual: value));
    }

    return value;
  }

  /// Decodes the JSON request body and maps it using [fromJson] callback.
  ///
  /// Collects all validation errors and throws them as [ValidationErrors].
  /// With [failFast], throws on the first error instead.
  Future<R> json<R>(
    R Function(JsonObject json) fromJson, {
    bool failFast = false,
  }) async {
    final json = JsonObject(await rawJson<Map<String, Object?>>());
    return failFast ? fromJson(json) : json.parse(fromJson);
  }

  /// Decodes a top-level JSON array request body and decodes each element
  /// with [items], such as `.string` or `.object(ItemDto.fromJson)`.
  ///
  /// Collects all validation errors and throws them as [ValidationErrors].
  /// With [failFast], throws on the first error instead.
  Future<List<R>> jsonList<R>(
    JsonType<R> items, {
    bool failFast = false,
  }) async {
    final json = JsonObject({r'$': await rawJson<List<Object?>>()});
    List<R> read(JsonObject json) => json.list(r'$', items);
    return failFast ? read(json) : json.parse(read);
  }
}
