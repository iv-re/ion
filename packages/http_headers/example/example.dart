import 'package:http_headers/http_headers.dart';

void main() {
  // Using standard headers with factory constructors
  const contentType = TypedHeader.contentTypeJson();
  const cacheControl = TypedHeader.cacheControl(
    maxAge: Duration(hours: 1),
  );
  const userAgent = TypedHeader.userAgent('ion/1.0.0');

  print('${contentType.name}: ${contentType.value}');
  print('${cacheControl.name}: ${cacheControl.value}');
  print('${userAgent.name}: ${userAgent.value}');

  // Decoding raw header values
  final decodedAge = AgeHeader.decode(['3600']);
  if (decodedAge != null) {
    print('Decoded Age: ${decodedAge.duration.inSeconds} seconds');
  }

  // Using a custom header
  const customHeader = CustomHeader('secret_key_123');
  print('${customHeader.name}: ${customHeader.value}');

  final decodedCustom = CustomHeader.decode(['secret_key_123']);
  print('Decoded Custom Header: ${decodedCustom?.value}');
}

/// Custom header implementation
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
