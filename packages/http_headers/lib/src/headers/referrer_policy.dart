import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:http_headers/src/util.dart';

/// The `Referrer-Policy` header field,
/// defined in [W3C Referrer Policy](https://www.w3.org/TR/referrer-policy/#referrer-policy-header).
///
/// Specifies referrer policy applied when determining referrer info.
///
/// ```dart
/// const noRef = ReferrerPolicyHeader.noReferrer();
/// const sameOrig = ReferrerPolicyHeader.sameOrigin();
/// final decoded = ReferrerPolicyHeader.decode(['same-origin, origin']);
/// ```
sealed class ReferrerPolicyHeader implements TypedHeader {
  /// `no-referrer`
  const factory ReferrerPolicyHeader.noReferrer() = ReferrerPolicyNoReferrer;

  /// `no-referrer-when-downgrade`
  const factory ReferrerPolicyHeader.noReferrerWhenDowngrade() =
      ReferrerPolicyNoReferrerWhenDowngrade;

  /// `same-origin`
  const factory ReferrerPolicyHeader.sameOrigin() = ReferrerPolicySameOrigin;

  /// `origin`
  const factory ReferrerPolicyHeader.origin() = ReferrerPolicyOrigin;

  /// `origin-when-cross-origin`
  const factory ReferrerPolicyHeader.originWhenCrossOrigin() =
      ReferrerPolicyOriginWhenCrossOrigin;

  /// `strict-origin`
  const factory ReferrerPolicyHeader.strictOrigin() =
      ReferrerPolicyStrictOrigin;

  /// `strict-origin-when-cross-origin`
  const factory ReferrerPolicyHeader.strictOriginWhenCrossOrigin() =
      ReferrerPolicyStrictOriginWhenCrossOrigin;

  /// `unsafe-url`
  const factory ReferrerPolicyHeader.unsafeUrl() = ReferrerPolicyUnsafeUrl;

  /// Decodes this header type picking the last known policy token in raw
  /// values.
  static ReferrerPolicyHeader? decode(Iterable<String> values) {
    ReferrerPolicyHeader? known;
    for (final token in parseCsv(values)) {
      final t = token.trim().toLowerCase();
      switch (t) {
        case 'no-referrer':
        case 'never':
          known = const ReferrerPolicyNoReferrer();
        case 'no-referrer-when-downgrade':
        case 'default':
          known = const ReferrerPolicyNoReferrerWhenDowngrade();
        case 'same-origin':
          known = const ReferrerPolicySameOrigin();
        case 'origin':
          known = const ReferrerPolicyOrigin();
        case 'origin-when-cross-origin':
          known = const ReferrerPolicyOriginWhenCrossOrigin();
        case 'strict-origin':
          known = const ReferrerPolicyStrictOrigin();
        case 'strict-origin-when-cross-origin':
          known = const ReferrerPolicyStrictOriginWhenCrossOrigin();
        case 'unsafe-url':
        case 'always':
          known = const ReferrerPolicyUnsafeUrl();
      }
    }
    return known;
  }

  @override
  String get name => HttpHeader.referrerPolicy.name;
}

final class ReferrerPolicyNoReferrer implements ReferrerPolicyHeader {
  const ReferrerPolicyNoReferrer();

  @override
  String get name => HttpHeader.referrerPolicy.name;

  @override
  Iterable<String> encode() => const ['no-referrer'];

  @override
  String toString() => 'ReferrerPolicyHeader.noReferrer()';
}

final class ReferrerPolicyNoReferrerWhenDowngrade
    implements ReferrerPolicyHeader {
  const ReferrerPolicyNoReferrerWhenDowngrade();

  @override
  String get name => HttpHeader.referrerPolicy.name;

  @override
  Iterable<String> encode() => const ['no-referrer-when-downgrade'];

  @override
  String toString() => 'ReferrerPolicyHeader.noReferrerWhenDowngrade()';
}

final class ReferrerPolicySameOrigin implements ReferrerPolicyHeader {
  const ReferrerPolicySameOrigin();

  @override
  String get name => HttpHeader.referrerPolicy.name;

  @override
  Iterable<String> encode() => const ['same-origin'];

  @override
  String toString() => 'ReferrerPolicyHeader.sameOrigin()';
}

final class ReferrerPolicyOrigin implements ReferrerPolicyHeader {
  const ReferrerPolicyOrigin();

  @override
  String get name => HttpHeader.referrerPolicy.name;

  @override
  Iterable<String> encode() => const ['origin'];

  @override
  String toString() => 'ReferrerPolicyHeader.origin()';
}

final class ReferrerPolicyOriginWhenCrossOrigin
    implements ReferrerPolicyHeader {
  const ReferrerPolicyOriginWhenCrossOrigin();

  @override
  String get name => HttpHeader.referrerPolicy.name;

  @override
  Iterable<String> encode() => const ['origin-when-cross-origin'];

  @override
  String toString() => 'ReferrerPolicyHeader.originWhenCrossOrigin()';
}

final class ReferrerPolicyStrictOrigin implements ReferrerPolicyHeader {
  const ReferrerPolicyStrictOrigin();

  @override
  String get name => HttpHeader.referrerPolicy.name;

  @override
  Iterable<String> encode() => const ['strict-origin'];

  @override
  String toString() => 'ReferrerPolicyHeader.strictOrigin()';
}

final class ReferrerPolicyStrictOriginWhenCrossOrigin
    implements ReferrerPolicyHeader {
  const ReferrerPolicyStrictOriginWhenCrossOrigin();

  @override
  String get name => HttpHeader.referrerPolicy.name;

  @override
  Iterable<String> encode() => const ['strict-origin-when-cross-origin'];

  @override
  String toString() => 'ReferrerPolicyHeader.strictOriginWhenCrossOrigin()';
}

final class ReferrerPolicyUnsafeUrl implements ReferrerPolicyHeader {
  const ReferrerPolicyUnsafeUrl();

  @override
  String get name => HttpHeader.referrerPolicy.name;

  @override
  Iterable<String> encode() => const ['unsafe-url'];

  @override
  String toString() => 'ReferrerPolicyHeader.unsafeUrl()';
}
