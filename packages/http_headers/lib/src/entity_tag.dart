import 'package:equatable/equatable.dart';

/// Represents an HTTP Entity-Tag (ETag),
/// defined in [RFC 7232 Section 2.3](https://datatracker.ietf.org/doc/html/rfc7232#section-2.3).
///
/// Examples:
/// - `"xyzzy"` -> `EntityTag('xyzzy', isWeak: false)`
/// - `W/"xyzzy"` -> `EntityTag('xyzzy', isWeak: true)`
final class EntityTag extends Equatable {
  /// Creates an [EntityTag] with weak indicator flag and tag string.
  const EntityTag(this.tag, {this.isWeak = false});

  /// Creates a weak [EntityTag].
  const EntityTag.weak(this.tag) : isWeak = true;

  /// Creates a strong [EntityTag].
  const EntityTag.strong(this.tag) : isWeak = false;

  /// Parses an [EntityTag] from raw string format.
  ///
  /// Examples:
  /// - `"xyzzy"` -> `EntityTag('xyzzy', isWeak: false)`
  /// - `W/"xyzzy"` -> `EntityTag('xyzzy', isWeak: true)`
  static EntityTag? parse(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    var isWeak = false;
    var tagPart = s;

    if (s.startsWith('W/"')) {
      isWeak = true;
      tagPart = s.substring(2);
    } else if (!s.startsWith('"')) {
      return null;
    }

    if (!tagPart.startsWith('"') ||
        !tagPart.endsWith('"') ||
        tagPart.length < 2) {
      return null;
    }

    final inner = tagPart.substring(1, tagPart.length - 1);
    if (inner.contains('"')) return null;

    return EntityTag(inner, isWeak: isWeak);
  }

  /// Opaque tag string without quotes.
  final String tag;

  /// Whether this is a weak entity tag (`W/`).
  final bool isWeak;

  @override
  String toString() => isWeak ? 'W/"$tag"' : '"$tag"';

  @override
  List<Object?> get props => [tag, isWeak];
}
