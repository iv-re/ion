# http_headers

Typed HTTP headers for Dart.

## Usage

### Standard Headers

```dart
import 'package:http_headers/http_headers.dart';

// Factory constructors
final header = TypedHeader.contentTypeJson();
final cache = TypedHeader.cacheControl(maxAge: Duration(hours: 1));

print('${header.name}: ${header.value}'); // Content-Type: application/json

// Decode raw header values
final age = AgeHeader.decode(['3600']);
```

### Custom Headers

```dart
final class CustomHeader implements TypedHeader {
  const CustomHeader(this.value);

  static CustomHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    return CustomHeader(values.first);
  }

  @override
  String get name => 'X-Custom-Header';

  final String value;

  @override
  Iterable<String> encode() => [value];
}
```

## Acknowledgements

Inspired by Rust's [`headers`](https://github.com/hyperium/headers) crate (`hyperium/headers`).
