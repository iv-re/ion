/// Represents an authentication challenge from a server or proxy.
sealed class AuthenticationChallenge {
  /// Creates a Basic authentication challenge.
  const factory AuthenticationChallenge.basic({
    required String realm,
    String? charset,
  }) = AuthenticationChallengeBasic;

  /// Creates a Bearer authentication challenge.
  const factory AuthenticationChallenge.bearer({
    String? realm,
    String? error,
    String? errorDescription,
  }) = AuthenticationChallengeBearer;

  /// Creates a custom authentication challenge.
  const factory AuthenticationChallenge.custom(
    String scheme,
    String parameters,
  ) = AuthenticationChallengeCustom;

  /// The authentication scheme (e.g., Basic, Bearer).
  String get scheme;

  /// The authentication parameters.
  String get parameters;

  /// Parses an authentication challenge from a raw string.
  static AuthenticationChallenge? parse(String raw) {
    final spaceIdx = raw.indexOf(' ');
    if (spaceIdx == -1) return null;

    final schemePart = raw.substring(0, spaceIdx).trim();
    final paramsPart = raw.substring(spaceIdx + 1).trimLeft();

    final lowerScheme = schemePart.toLowerCase();
    if (lowerScheme == 'basic' || lowerScheme == 'bearer') {
      final paramsMap = _parseParams(paramsPart);
      if (lowerScheme == 'basic') {
        return AuthenticationChallengeBasic(
          realm: paramsMap['realm'] ?? '',
          charset: paramsMap['charset'],
        );
      } else {
        return AuthenticationChallengeBearer(
          realm: paramsMap['realm'],
          error: paramsMap['error'],
          errorDescription: paramsMap['error_description'],
        );
      }
    }
    return AuthenticationChallengeCustom(schemePart, paramsPart);
  }

  static final _paramRegex = RegExp(
    r'([\w-]+)\s*=\s*(?:"([^"]*)"|([^\s,]+))',
  );

  static Map<String, String> _parseParams(String rawParams) {
    final result = <String, String>{};
    for (final match in _paramRegex.allMatches(rawParams)) {
      final key = match.group(1)!.toLowerCase();
      final value = match.group(2) ?? match.group(3) ?? '';
      result[key] = value;
    }
    return result;
  }
}

/// Public class representing a Basic challenge.
final class AuthenticationChallengeBasic implements AuthenticationChallenge {
  const AuthenticationChallengeBasic({required this.realm, this.charset});

  final String realm;
  final String? charset;

  @override
  String get scheme => 'Basic';

  @override
  String get parameters {
    final params = ['realm="$realm"'];
    if (charset != null) {
      params.add('charset="$charset"');
    }
    return params.join(', ');
  }

  @override
  String toString() => '$scheme $parameters';
}

/// Public class representing a Bearer challenge.
final class AuthenticationChallengeBearer implements AuthenticationChallenge {
  const AuthenticationChallengeBearer({
    this.realm,
    this.error,
    this.errorDescription,
  });

  final String? realm;
  final String? error;
  final String? errorDescription;

  @override
  String get scheme => 'Bearer';

  @override
  String get parameters {
    final params = <String>[];
    if (realm != null) {
      params.add('realm="$realm"');
    }
    if (error != null) {
      params.add('error="$error"');
    }
    if (errorDescription != null) {
      params.add('error_description="$errorDescription"');
    }
    return params.join(', ');
  }

  @override
  String toString() => '$scheme $parameters';
}

/// Public class representing a custom authentication challenge.
final class AuthenticationChallengeCustom implements AuthenticationChallenge {
  const AuthenticationChallengeCustom(this.scheme, this.parameters);

  @override
  final String scheme;

  @override
  final String parameters;

  @override
  String toString() => '$scheme $parameters';
}
