class _SubtypeOf<T> {
  const _SubtypeOf();

  bool isSubtypeOf<Target>() => this is _SubtypeOf<Target>;
}

/// Returns the JSON Schema type name for a generic type [T], as used by
/// validation errors.
String typeNameOf<T>() {
  if (T == String) return 'string';
  if (T == int) return 'integer';
  if (T == double || T == num) return 'number';
  if (T == bool) return 'boolean';

  final type = _SubtypeOf<T>();
  if (type.isSubtypeOf<Map<Object?, Object?>>()) return 'object';
  if (type.isSubtypeOf<List<Object?>>()) return 'array';

  return T.toString();
}
