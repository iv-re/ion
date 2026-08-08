import 'package:equatable/equatable.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Strict-Transport-Security` response header field,
/// defined in [RFC 6797](https://datatracker.ietf.org/doc/html/rfc6797).
///
/// Declares that website is accessible only via secure connections (HSTS).
///
/// ```dart
/// final hsts = StrictTransportSecurityHeader.includingSubdomains(
///   Duration(days: 365),
/// );
/// final decoded = StrictTransportSecurityHeader.decode(
///   ['max-age=31536000; includeSubdomains'],
/// );
/// ```
final class StrictTransportSecurityHeader extends Equatable
    implements TypedHeader {
  /// Creates a `Strict-Transport-Security` header.
  const StrictTransportSecurityHeader({
    required this.maxAge,
    this.includeSubdomains = false,
  });

  /// Creates an HSTS header that includes subdomains.
  const StrictTransportSecurityHeader.includingSubdomains(this.maxAge)
    : includeSubdomains = true;

  /// Creates an HSTS header that excludes subdomains.
  const StrictTransportSecurityHeader.excludingSubdomains(this.maxAge)
    : includeSubdomains = false;

  /// Decodes this header type from raw header values.
  static StrictTransportSecurityHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first;

    int? maxAgeSecs;
    var includeSubdomains = false;
    var maxAgeCount = 0;
    var subdomainsCount = 0;

    final parts = raw.split(';');
    for (final part in parts) {
      final sub = part.trim();
      if (sub.isEmpty) continue;
      if (sub.toLowerCase() == 'includesubdomains') {
        subdomainsCount++;
        includeSubdomains = true;
      } else {
        final eqIdx = sub.indexOf('=');
        if (eqIdx != -1) {
          final left = sub.substring(0, eqIdx).trim().toLowerCase();
          final right = sub.substring(eqIdx + 1).trim().replaceAll('"', '');
          if (left == 'max-age') {
            maxAgeCount++;
            final parsed = int.tryParse(right);
            if (parsed == null || parsed < 0) return null;
            maxAgeSecs = parsed;
          }
        }
      }
    }

    if (maxAgeSecs == null || maxAgeCount > 1 || subdomainsCount > 1) {
      return null;
    }

    return StrictTransportSecurityHeader(
      maxAge: Duration(seconds: maxAgeSecs),
      includeSubdomains: includeSubdomains,
    );
  }

  /// The max-age duration.
  final Duration maxAge;

  /// Whether HSTS policy includes subdomains.
  final bool includeSubdomains;

  @override
  String get name => HttpHeader.strictTransportSecurity.name;

  @override
  Iterable<String> encode() {
    if (includeSubdomains) {
      return ['max-age=${maxAge.inSeconds}; includeSubdomains'];
    }
    return ['max-age=${maxAge.inSeconds}'];
  }

  @override
  List<Object?> get props => [maxAge, includeSubdomains];
}
