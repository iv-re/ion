class _SubtypeOf<T> {
  const _SubtypeOf();

  bool isSubtypeOf<Target>() => this is _SubtypeOf<Target>;
}

/// Returns a human-readable canonical type name for a generic type [T]
/// suitable for validation errors.
String typeNameOf<T>() {
  if (T == String) return 'string';
  if (T == int) return 'int';
  if (T == double) return 'double';
  if (T == num) return 'number';
  if (T == bool) return 'bool';

  final type = _SubtypeOf<T>();
  if (type.isSubtypeOf<Map<Object?, Object?>>()) return 'map';
  if (type.isSubtypeOf<List<Object?>>()) return 'list';

  return T.toString();
}
