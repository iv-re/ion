import 'package:ion_web/ion_web.dart';

/// Test custom header implementation for header parser and decoder tests.
class TestCustomHeader implements TypedHeader {
  const TestCustomHeader(this.name, this.value);

  @override
  final String name;
  final String value;

  @override
  Iterable<String> encode() => [value];

  static TestCustomHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    return TestCustomHeader('custom', values.join(', '));
  }
}
