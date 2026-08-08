import 'package:equatable/equatable.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:meta/meta.dart';

/// The `Expect` request header field,
/// defined in [RFC 7231 Section 5.1.1](https://datatracker.ietf.org/doc/html/rfc7231#section-5.1.1).
///
/// Indicates expectations that need to be supported by the server.
///
/// ```dart
/// const expectContinue = ExpectHeader.continue100();
/// final decoded = ExpectHeader.decode(['100-continue']);
/// ```
@immutable
final class ExpectHeader extends Equatable implements TypedHeader {
  /// Creates an `Expect: 100-continue` header.
  const ExpectHeader.continue100();

  /// Decodes this header type from raw header values.
  static ExpectHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw.toLowerCase() == '100-continue') {
      return const ExpectHeader.continue100();
    }
    return null;
  }

  @override
  Iterable<String> encode() => const ['100-continue'];

  @override
  String get name => HttpHeader.expect.name;

  @override
  String toString() => 'ExpectHeader.continue100()';

  @override
  List<Object?> get props => [name];
}
