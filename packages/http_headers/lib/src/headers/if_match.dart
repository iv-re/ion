import 'package:equatable/equatable.dart';
import 'package:http_headers/src/entity_tag.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/headers/etag.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:http_headers/src/util.dart';

/// The `If-Match` request header field,
/// defined in [RFC 7232 Section 3.1](https://datatracker.ietf.org/doc/html/rfc7232#section-3.1).
///
/// Makes the request method conditional on server having matching entity tags.
///
/// ```dart
/// const anyMatch = IfMatchHeader.any();
/// final tagMatch = IfMatchHeader.etag(EntityTag('xyzzy'));
/// final decoded = IfMatchHeader.decode(['"xyzzy"']);
/// ```
sealed class IfMatchHeader implements TypedHeader {
  /// Creates an `If-Match: *` wildcard header.
  const factory IfMatchHeader.any() = IfMatchAny;

  /// Creates an `If-Match` header with a single entity tag.
  factory IfMatchHeader.etag(EntityTag tag) = IfMatchItems.single;

  /// Creates an `If-Match` header with a list of entity tags.
  const factory IfMatchHeader.tags(List<EntityTag> tags) = IfMatchItems;

  /// Decodes this header type from raw header values.
  static IfMatchHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw == '*') {
      return const IfMatchAny();
    }
    final parsedTags = <EntityTag>[];
    for (final item in parseCsv(values)) {
      final tag = EntityTag.parse(item);
      if (tag != null) {
        parsedTags.add(tag);
      }
    }
    if (parsedTags.isEmpty) return null;
    return IfMatchItems(parsedTags);
  }

  @override
  String get name => HttpHeader.ifMatch.name;

  /// Returns `true` if wildcard `*` matching is used.
  bool get isAny;

  /// Checks whether the precondition passes for the provided [ETagHeader] using
  /// strong comparison.
  bool preconditionPasses(ETagHeader etag);
}

/// Wildcard `If-Match: *`.
final class IfMatchAny extends Equatable implements IfMatchHeader {
  /// Creates a wildcard `If-Match` header.
  const IfMatchAny();

  @override
  String get name => HttpHeader.ifMatch.name;

  @override
  bool get isAny => true;

  @override
  List<Object?> get props => [];

  @override
  Iterable<String> encode() => ['*'];

  @override
  bool preconditionPasses(ETagHeader etag) => true;
}

/// `If-Match` with a list of entity tags.
final class IfMatchItems extends Equatable implements IfMatchHeader {
  /// Creates an `If-Match` header with the given tags.
  const IfMatchItems(this.tags);

  /// Creates an `If-Match` header with a single tag.
  IfMatchItems.single(EntityTag tag) : tags = [tag];

  /// The list of entity tags.
  final List<EntityTag> tags;

  @override
  String get name => HttpHeader.ifMatch.name;

  @override
  bool get isAny => false;

  @override
  List<Object?> get props => [tags];

  @override
  Iterable<String> encode() {
    if (tags.isEmpty) return [];
    return [tags.map((t) => t.toString()).join(', ')];
  }

  @override
  bool preconditionPasses(ETagHeader etag) {
    if (etag.isWeak) return false;
    return tags.any((t) => !t.isWeak && t.tag == etag.tag.tag);
  }
}
