import 'package:ion_web/ion_web.dart';
import 'package:json_codable/json_codable.dart';

/// Extension on [Request] for extracting and parsing URL query parameters into
/// domain models.
extension RequestQueryExtractor on Request {
  /// Extracts the URL query parameters and maps them using [fromJson]
  /// callback.
  ///
  /// Values stay strings until a getter reads them, so `json.string('zip')`
  /// keeps `007` and `json.int('page')` converts `2`. Keys nest with dot and
  /// bracket notation: `filter.page`, `filter[page]`, `tags[]` and
  /// `items[0][id]`.
  ///
  /// Collects all validation errors and throws them as [ValidationErrors].
  /// With [failFast], throws on the first error instead.
  R query<R>(R Function(JsonObject json) fromJson, {bool failFast = false}) {
    final json = JsonObject(
      _decodeQuery(uri.query),
      source: .text,
    );
    return failFast ? fromJson(json) : json.parse(fromJson);
  }
}

/// Builds a read-only tree from [query], a URL query string.
///
/// A key splits into segments at `.` and `[...]`. Values that share a path are
/// joined in order, so `ids=1&ids[]=2` gives `['1', '2']`. A path with one
/// value holds a string, and an object whose keys are all indices becomes a
/// list ordered by index. When a path has both values and nested keys, the
/// nested keys win.
Map<String, Object?> _decodeQuery(String query) {
  final root = _QueryNode();
  for (final pair in query.split('&')) {
    if (pair.isEmpty) continue;
    final equals = pair.indexOf('=');
    final key = Uri.decodeQueryComponent(
      equals == -1 ? pair : pair.substring(0, equals),
    );
    final value = equals == -1
        ? ''
        : Uri.decodeQueryComponent(pair.substring(equals + 1));

    final segments = _segments(key);
    if (segments == null) continue;

    var node = root;
    for (final segment in segments) {
      node = node.children.putIfAbsent(segment, _QueryNode.new);
    }
    node.values.add(value);
  }
  return root.toObject();
}

final class _QueryNode {
  final List<String> values = [];
  final Map<String, _QueryNode> children = {};

  Object? toValue() {
    if (children.isEmpty) {
      return values.length == 1 ? values[0] : List<String>.unmodifiable(values);
    }

    final indices = <(int, _QueryNode)>[];
    for (final MapEntry(:key, :value) in children.entries) {
      final index = _index(key);
      if (index == null) return toObject();
      indices.add((index, value));
    }
    indices.sort((a, b) => a.$1.compareTo(b.$1));
    return List<Object?>.unmodifiable([
      for (final (_, node) in indices) node.toValue(),
    ]);
  }

  Map<String, Object?> toObject() => Map.unmodifiable({
    for (final MapEntry(:key, :value) in children.entries) key: value.toValue(),
  });
}

/// Splits [key] into path segments, dropping empty `[]` segments, or returns
/// `null` when [key] has no name. Text after an unclosed `[` is kept as is.
List<String>? _segments(String key) {
  final segments = <String>[];
  var start = 0;
  for (var i = 0; i < key.length; i++) {
    final char = key.codeUnitAt(i);
    if (char == _dot) {
      if (i > start) segments.add(key.substring(start, i));
      start = i + 1;
    } else if (char == _open) {
      final close = key.indexOf(']', i + 1);
      if (close == -1) break;
      if (i > start) segments.add(key.substring(start, i));
      if (close > i + 1) segments.add(key.substring(i + 1, close));
      start = close + 1;
      i = close;
    }
  }
  if (start < key.length) segments.add(key.substring(start));
  return segments.isEmpty ? null : segments;
}

/// Parses [key] as a list index: digits with no leading zeros.
int? _index(String key) {
  if (key.isEmpty || key.length > 9) return null;
  if (key.length > 1 && key.codeUnitAt(0) == _zero) return null;
  for (var i = 0; i < key.length; i++) {
    final char = key.codeUnitAt(i);
    if (char < _zero || char > _nine) return null;
  }
  return int.parse(key);
}

const _dot = 0x2E;
const _open = 0x5B;
const _zero = 0x30;
const _nine = 0x39;
