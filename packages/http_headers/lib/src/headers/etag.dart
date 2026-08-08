import 'package:equatable/equatable.dart';
import 'package:http_headers/src/entity_tag.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `ETag` response header field,
/// defined in [RFC 7232 Section 2.3](https://datatracker.ietf.org/doc/html/rfc7232#section-2.3).
///
/// Provides an opaque validator for differentiating representations of the
/// same resource.
///
/// ```dart
/// final etag = ETagHeader(EntityTag('xyzzy'));
/// final weakEtag = ETagHeader.weak('xyzzy');
/// final decoded = ETagHeader.decode(['"xyzzy"']);
/// ```
final class ETagHeader extends Equatable implements TypedHeader {
  /// Creates an `ETag` header with the given [EntityTag].
  const ETagHeader(this.tag);

  /// Creates a weak `ETag` header.
  ETagHeader.weak(String tag) : tag = EntityTag.weak(tag);

  /// Creates a strong `ETag` header.
  ETagHeader.strong(String tag) : tag = EntityTag.strong(tag);

  /// Decodes this header type from raw header values.
  static ETagHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final entityTag = EntityTag.parse(values.first);
    if (entityTag == null) return null;
    return ETagHeader(entityTag);
  }

  /// The entity tag.
  final EntityTag tag;

  @override
  String get name => HttpHeader.etag.name;

  /// Returns `true` if etag is weak.
  bool get isWeak => tag.isWeak;

  @override
  Iterable<String> encode() => [tag.toString()];

  @override
  List<Object?> get props => [tag];
}
