import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/headers/etag.dart';
import 'package:http_headers/src/headers/last_modified.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `If-Range` request header field,
/// defined in [RFC 7233 Section 3.2](https://datatracker.ietf.org/doc/html/rfc7233#section-3.2).
///
/// Allows client to short-circuit conditional range requests.
///
/// ```dart
/// final ifRangeEtag = IfRangeHeader.etag(ETagHeader.strong('xyzzy'));
/// final ifRangeDate = IfRangeHeader.date(DateTime.now());
/// final decoded = IfRangeHeader.decode(['"xyzzy"']);
/// ```
sealed class IfRangeHeader implements TypedHeader {
  /// Creates an `If-Range` header with an ETag.
  const factory IfRangeHeader.etag(ETagHeader etag) = IfRangeETag;

  /// Creates an `If-Range` header with a date.
  const factory IfRangeHeader.date(DateTime date) = IfRangeDate;

  /// Decodes this header type from raw header values.
  static IfRangeHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw.isEmpty) return null;

    final etag = ETagHeader.decode(values);
    if (etag != null) {
      return IfRangeETag(etag);
    }
    try {
      final dt = HttpDate.parse(raw);
      return IfRangeDate(dt);
    } catch (_) {
      return null;
    }
  }

  @override
  String get name => HttpHeader.ifRange.name;

  /// Checks if resource has been modified for this condition.
  bool isModified({ETagHeader? etag, LastModifiedHeader? lastModified});
}

/// `If-Range` header containing an [ETagHeader].
final class IfRangeETag extends Equatable implements IfRangeHeader {
  /// Creates an `If-Range` header with the given ETag.
  const IfRangeETag(this.etag);

  /// The entity tag.
  final ETagHeader etag;

  @override
  String get name => HttpHeader.ifRange.name;

  @override
  List<Object?> get props => [etag];

  @override
  Iterable<String> encode() => etag.encode();

  @override
  bool isModified({ETagHeader? etag, LastModifiedHeader? lastModified}) {
    if (etag == null || etag.isWeak || this.etag.isWeak) return true;
    return etag.tag.tag != this.etag.tag.tag;
  }
}

/// `If-Range` header containing a timestamp [date].
final class IfRangeDate extends Equatable implements IfRangeHeader {
  /// Creates an `If-Range` header with the given date.
  const IfRangeDate(this.date);

  /// The timestamp date.
  final DateTime date;

  @override
  String get name => HttpHeader.ifRange.name;

  @override
  List<Object?> get props => [date];

  @override
  Iterable<String> encode() => [HttpDate.format(date)];

  @override
  bool isModified({ETagHeader? etag, LastModifiedHeader? lastModified}) {
    if (lastModified == null) return true;
    final rangeSec = date.millisecondsSinceEpoch ~/ 1000;
    final modSec = lastModified.date.millisecondsSinceEpoch ~/ 1000;
    return rangeSec != modSec;
  }
}
