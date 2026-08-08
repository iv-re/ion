import 'package:equatable/equatable.dart';
import 'package:http_headers/src/entity_tag.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/headers/etag.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:http_headers/src/util.dart';

/// The `If-None-Match` request header field,
/// defined in [RFC 7232 Section 3.2](https://datatracker.ietf.org/doc/html/rfc7232#section-3.2).
///
/// Makes request conditional on server NOT having matching entity tags.
///
/// ```dart
/// const anyMatch = IfNoneMatchHeader.any();
/// final tagMatch = IfNoneMatchHeader.etag(EntityTag('xyzzy'));
/// final decoded = IfNoneMatchHeader.decode(['"xyzzy"']);
/// ```
sealed class IfNoneMatchHeader implements TypedHeader {
  /// Creates an `If-None-Match: *` wildcard header.
  const factory IfNoneMatchHeader.any() = IfNoneMatchAny;

  /// Creates an `If-None-Match` header with a single entity tag.
  factory IfNoneMatchHeader.etag(EntityTag tag) = IfNoneMatchItems.single;

  /// Creates an `If-None-Match` header with a list of entity tags.
  const factory IfNoneMatchHeader.tags(List<EntityTag> tags) = IfNoneMatchItems;

  /// Decodes this header type from raw header values.
  static IfNoneMatchHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw == '*') {
      return const IfNoneMatchAny();
    }
    final parsedTags = <EntityTag>[];
    for (final item in parseCsv(values)) {
      final tag = EntityTag.parse(item);
      if (tag != null) {
        parsedTags.add(tag);
      }
    }
    if (parsedTags.isEmpty) return null;
    return IfNoneMatchItems(parsedTags);
  }

  @override
  String get name => HttpHeader.ifNoneMatch.name;

  /// Returns `true` if wildcard `*` matching is used.
  bool get isAny;

  /// Checks whether the precondition passes for the provided [ETagHeader] using
  /// weak comparison.
  bool preconditionPasses(ETagHeader etag);
}

/// Wildcard `If-None-Match: *`.
final class IfNoneMatchAny extends Equatable implements IfNoneMatchHeader {
  /// Creates a wildcard `If-None-Match` header.
  const IfNoneMatchAny();

  @override
  String get name => HttpHeader.ifNoneMatch.name;

  @override
  bool get isAny => true;

  @override
  List<Object?> get props => [];

  @override
  Iterable<String> encode() => ['*'];

  @override
  @override
  bool preconditionPasses(ETagHeader etag) => false;
}

/// `If-None-Match` with a list of entity tags.
final class IfNoneMatchItems extends Equatable implements IfNoneMatchHeader {
  /// Creates an `If-None-Match` header with the given tags.
  const IfNoneMatchItems(this.tags);

  /// Creates an `If-None-Match` header with a single tag.
  IfNoneMatchItems.single(EntityTag tag) : tags = [tag];

  /// The list of entity tags.
  final List<EntityTag> tags;

  @override
  String get name => HttpHeader.ifNoneMatch.name;

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
    return !tags.any((t) => t.tag == etag.tag.tag);
  }
}
