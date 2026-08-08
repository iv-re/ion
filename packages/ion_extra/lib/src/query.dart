import 'dart:collection';

import 'package:ion_web/ion_web.dart';
import 'package:json_codable/json_codable.dart';

/// Extension on [Request] for extracting and parsing URL query parameters into
/// domain models.
extension RequestQueryExtractor on Request {
  /// If set to `true` (the default), query parameter extraction will accumulate
  /// all validation errors across the entire query map.
  ///
  /// If set to `false`, it will throw immediately on the first validation
  /// error encountered.
  static bool accumulateValidationErrors = true;

  /// Extracts and decodes the URL query parameters and maps them using
  /// [fromJson] callback.
  ///
  /// Collects and throws [ValidationErrors] if any validation errors occur.
  R query<R>(R Function(JsonObject json) fromJson) {
    final queryMap = _LazyQueryMap(uri.queryParametersAll);
    final jsonObj = JsonObject(queryMap);
    return accumulateValidationErrors
        ? jsonObj.parse(fromJson)
        : fromJson(jsonObj);
  }
}

class _LazyQueryMap extends MapBase<String, Object?> {
  _LazyQueryMap(this._raw);

  final Map<String, List<String>> _raw;
  final Map<String, Object?> _cache = {};

  @override
  bool containsKey(Object? key) {
    if (key is! String) return false;
    if (_cache.containsKey(key)) return true;
    if (_raw.containsKey(key)) return true;
    if (_raw.containsKey('$key[]')) return true;

    final keyLen = key.length;
    for (final k in _raw.keys) {
      if (k.length > keyLen && k.startsWith(key)) {
        final ch = k.codeUnitAt(keyLen);
        if (ch == 46 || ch == 91) return true; // '.' (46) or '[' (91)
      }
    }
    return false;
  }

  @override
  Object? operator [](Object? key) {
    if (key is! String) return null;
    if (_cache.containsKey(key)) return _cache[key];

    final directValues = _raw[key];
    if (directValues != null && directValues.isNotEmpty) {
      final decoded = directValues.length == 1
          ? _parseValue(directValues[0])
          : directValues.map(_parseValue).toList();
      _cache[key] = decoded;
      return decoded;
    }

    final bracketValues = _raw['$key[]'];
    if (bracketValues != null && bracketValues.isNotEmpty) {
      final decoded = bracketValues.map(_parseValue).toList();
      _cache[key] = decoded;
      return decoded;
    }

    final keyLen = key.length;
    Map<String, List<String>>? nestedRaw;

    for (final entry in _raw.entries) {
      final k = entry.key;
      if (k.length > keyLen && k.startsWith(key)) {
        final ch = k.codeUnitAt(keyLen);
        if (ch == 46) {
          // '.'
          (nestedRaw ??= {})[k.substring(keyLen + 1)] = entry.value;
        } else if (ch == 91) {
          // '['
          final closeIdx = k.indexOf(']', keyLen + 1);
          if (closeIdx != -1) {
            final subKey =
                k.substring(keyLen + 1, closeIdx) + k.substring(closeIdx + 1);
            (nestedRaw ??= {})[subKey] = entry.value;
          }
        }
      }
    }

    if (nestedRaw != null && nestedRaw.isNotEmpty) {
      final isIndexedArray = nestedRaw.keys.every((k) {
        final idx = int.tryParse(k);
        return idx != null && idx >= 0;
      });

      if (isIndexedArray) {
        final entries = nestedRaw.entries.toList()
          ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
        final list = entries.map((e) {
          final vals = e.value;
          return vals.length == 1
              ? _parseValue(vals[0])
              : vals.map(_parseValue).toList();
        }).toList();
        _cache[key] = list;
        return list;
      }

      final nestedMap = _LazyQueryMap(nestedRaw);
      _cache[key] = nestedMap;
      return nestedMap;
    }

    return null;
  }

  @override
  Iterable<String> get keys => _raw.keys;

  @override
  void operator []=(String key, Object? value) => _cache[key] = value;

  @override
  Object? remove(Object? key) {
    throw UnsupportedError('Read-only query map');
  }

  @override
  void clear() => _cache.clear();
}

Object _parseValue(String value) {
  if (value.isEmpty) return value;

  final len = value.length;
  if (len == 4) {
    if (value.equalsIgnoreAsciiCase('true')) return true;
  } else if (len == 5) {
    if (value.equalsIgnoreAsciiCase('false')) return false;
  }

  final first = value.codeUnitAt(0);
  final isPossibleNumber =
      (first >= 48 && first <= 57) || // '0'-'9'
      first == 45 || // '-'
      first == 43 || // '+'
      first == 46; // '.'

  if (!isPossibleNumber) return value;

  final intVal = int.tryParse(value);
  if (intVal != null) return intVal;

  final doubleVal = double.tryParse(value);
  if (doubleVal != null) return doubleVal;

  return value;
}
