import 'dart:io';

import 'package:ctx/ctx.dart';
import 'package:ion_router/src/middleware.dart';
import 'package:ion_web/ion_web.dart';

const _clientIpCtxKey = #clientIp;

/// Sealed hierarchy defining client IP extraction sources for
/// [clientIpMiddleware].
sealed class ClientIpSource {
  const ClientIpSource();

  /// Extracts the client IP from a single-IP header set by your reverse proxy
  /// (e.g. `X-Real-IP`, `X-Client-IP`, `CF-Connecting-IP`).
  ///
  /// Only safe with headers your proxy unconditionally OVERWRITES on every
  /// request. If multiple header values reach the server, the LAST (rightmost)
  /// value wins.
  ///
  /// ```dart
  /// ClientIpSource.header(headerName: 'CF-Connecting-IP')
  /// ```
  const factory ClientIpSource.header({
    String headerName,
  }) = _ClientIpSourceHeader;

  /// Extracts the client IP read from the `X-Forwarded-For` header, walking
  /// the chain right-to-left and skipping any IP that falls within one of the
  /// given trusted CIDR [trustedPrefixes].
  ///
  /// The first IP that is not trusted is identified as the client IP. An
  /// unparseable entry mid-chain aborts the walk and sets no client IP
  /// (fail-closed).
  ///
  /// ```dart
  /// ClientIpSource.xff(trustedPrefixes: ['10.0.0.0/8', '2606:4700::/32'])
  /// ```
  factory ClientIpSource.xff({
    List<String> trustedPrefixes,
  }) = _ClientIpSourceXff;

  /// Extracts the client IP read from the `X-Forwarded-For` header given the
  /// exact number of trusted reverse proxies ([numTrustedProxies]) between
  /// this server and the public internet.
  ///
  /// Returns the IP at position `len(xff) - numTrustedProxies` in the merged
  /// `X-Forwarded-For` list.
  ///
  /// ```dart
  /// ClientIpSource.xffTrustedProxies(2)
  /// ```
  factory ClientIpSource.xffTrustedProxies(
    int numTrustedProxies,
  ) = _ClientIpSourceXffTrustedProxies;

  /// Extracts the client IP directly from the TCP connection `remoteAddress`.
  ///
  /// Use this when this server is directly connected to the public internet
  /// with NO reverse proxy in front of it.
  ///
  /// ```dart
  /// ClientIpSource.remoteAddr()
  /// ```
  const factory ClientIpSource.remoteAddr() = _ClientIpSourceRemoteAddr;
}

final class _ClientIpSourceHeader extends ClientIpSource {
  const _ClientIpSourceHeader({this.headerName = 'X-Real-IP'});

  final String headerName;
}

final class _ClientIpSourceXff extends ClientIpSource {
  _ClientIpSourceXff({this.trustedPrefixes = const []}) {
    for (final prefix in trustedPrefixes) {
      _CidrPrefix.parse(prefix);
    }
  }

  final List<String> trustedPrefixes;
}

final class _ClientIpSourceXffTrustedProxies extends ClientIpSource {
  _ClientIpSourceXffTrustedProxies(this.numTrustedProxies)
    : assert(
        numTrustedProxies >= 1,
        'ClientIpSource.xffTrustedProxies: numTrustedProxies must be >= 1',
      );

  final int numTrustedProxies;
}

final class _ClientIpSourceRemoteAddr extends ClientIpSource {
  const _ClientIpSourceRemoteAddr();
}

/// Extension on [Context] to conveniently access the extracted client IP.
extension ClientIpContext on Context {
  /// Gets the client [InternetAddress] set by [clientIpMiddleware], or `null`
  /// if no valid client IP was identified.
  InternetAddress? get clientIp => value(_clientIpCtxKey) as InternetAddress?;
}

final class _CidrPrefix {
  const _CidrPrefix._(this.prefixIp, this.prefixLength, this._bytes);

  /// Parses a CIDR string (e.g. `"198.51.100.0/24"`, `"2606:4700::/32"`).
  ///
  /// Throws [AssertionError] if the format or prefix length is invalid.
  factory _CidrPrefix.parse(String input) {
    final parts = input.split('/');
    assert(parts.length <= 2, 'Invalid CIDR format: $input');

    final parsedIp = _parseAddr(parts[0]);
    assert(parsedIp != null, 'Invalid IP address in CIDR prefix: ${parts[0]}');

    final maxBits =
        (parsedIp?.type ?? InternetAddressType.IPv4) == InternetAddressType.IPv4
        ? 32
        : 128;
    int prefixLength;
    if (parts.length == 2) {
      final parsedLength = int.tryParse(parts[1]);
      assert(
        parsedLength != null && parsedLength >= 0 && parsedLength <= maxBits,
        'Invalid CIDR prefix length ${parts[1]} for ${parsedIp?.type.name}',
      );
      prefixLength = parsedLength ?? maxBits;
    } else {
      prefixLength = maxBits;
    }

    return _CidrPrefix._(parsedIp!, prefixLength, parsedIp.rawAddress);
  }

  /// The base network address of the CIDR prefix.
  final InternetAddress prefixIp;

  /// The length of the network mask in bits.
  final int prefixLength;

  final List<int> _bytes;

  /// Returns `true` if [address] falls within this CIDR network prefix.
  bool contains(InternetAddress address) {
    final normalizedAddress = (address.type == InternetAddressType.IPv6)
        ? (_parseAddr(address.address) ?? address)
        : address;
    if (normalizedAddress.type != prefixIp.type) {
      return false;
    }

    final addressBytes = normalizedAddress.rawAddress;
    final fullBytes = prefixLength ~/ 8;
    for (var i = 0; i < fullBytes; i++) {
      if (addressBytes[i] != _bytes[i]) return false;
    }

    final remainder = prefixLength % 8;
    if (remainder > 0) {
      final mask = (0xFF << (8 - remainder)) & 0xFF;
      if ((addressBytes[fullBytes] & mask) != (_bytes[fullBytes] & mask)) {
        return false;
      }
    }

    return true;
  }

  @override
  String toString() => '${prefixIp.address}/$prefixLength';
}

/// Parses [input] as an [InternetAddress] and normalizes it for security
/// storage:
/// - Strips IPv6 zone IDs (e.g. `%eth0`).
/// - Converts IPv4-mapped IPv6 addresses (`::ffff:a.b.c.d`) to plain IPv4.
///
/// Returns `null` if [input] is unparseable or empty.
InternetAddress? _parseAddr(String input) {
  var trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  final zoneIndex = trimmed.indexOf('%');
  if (zoneIndex >= 0) {
    trimmed = trimmed.substring(0, zoneIndex);
  }

  final parsedAddress = InternetAddress.tryParse(trimmed);
  if (parsedAddress == null) return null;

  if (parsedAddress.type == InternetAddressType.IPv6) {
    final rawBytes = parsedAddress.rawAddress;
    if (rawBytes.length == 16) {
      var isV4Mapped = true;
      for (var i = 0; i < 10; i++) {
        if (rawBytes[i] != 0) {
          isV4Mapped = false;
          break;
        }
      }
      if (isV4Mapped && rawBytes[10] == 255 && rawBytes[11] == 255) {
        return InternetAddress.fromRawAddress(rawBytes.sublist(12));
      }
    }
  }

  return parsedAddress;
}

/// Walks entries of merged `X-Forwarded-For` header strings right-to-left,
/// invoking [visit] on each trimmed non-empty entry.
///
/// Stops iteration when [visit] returns `true`.
void _walkXff(Iterable<String> headers, bool Function(String entry) visit) {
  final headerList = headers is List<String> ? headers : headers.toList();
  for (
    var headerIndex = headerList.length - 1;
    headerIndex >= 0;
    headerIndex--
  ) {
    var headerValue = headerList[headerIndex];
    while (headerValue.isNotEmpty) {
      String entry;
      final commaIndex = headerValue.lastIndexOf(',');
      if (commaIndex >= 0) {
        entry = headerValue.substring(commaIndex + 1);
        headerValue = headerValue.substring(0, commaIndex);
      } else {
        entry = headerValue;
        headerValue = '';
      }
      entry = entry.trim();
      if (entry.isEmpty) continue;
      if (visit(entry)) return;
    }
  }
}

/// Creates a [Middleware] that extracts and stores the client IP in request
/// [Context].
///
/// The extraction strategy is determined by [source]:
/// - [ClientIpSource.header]: Single header set by reverse proxy.
/// - [ClientIpSource.xff]: `X-Forwarded-For` header with trusted CIDR
///   filtering.
/// - [ClientIpSource.xffTrustedProxies]: `X-Forwarded-For` header with count
///   of trusted proxies.
/// - [ClientIpSource.remoteAddr]: Direct TCP peer address.
Middleware clientIpMiddleware({
  ClientIpSource source = const ClientIpSource.header(),
}) {
  switch (source) {
    case _ClientIpSourceHeader(:final headerName):
      return _clientIpFromHeader(headerName);
    case _ClientIpSourceXff(:final trustedPrefixes):
      return _clientIpFromXff(trustedPrefixes);
    case _ClientIpSourceXffTrustedProxies(:final numTrustedProxies):
      return _clientIpFromXffTrustedProxies(numTrustedProxies);
    case _ClientIpSourceRemoteAddr():
      return _clientIpFromRemoteAddr();
  }
}

Middleware _clientIpFromHeader(String headerName) {
  final httpHeader = HttpHeader(headerName);
  return (Handler next) {
    return (Request req) async {
      final values = req.headers.raw(httpHeader);
      if (values.isNotEmpty) {
        final lastValue = values.last;
        final parsedIp = _parseAddr(lastValue);
        if (parsedIp != null) {
          final updatedReq = req.copyWith(
            ctx: req.ctx.withValue(_clientIpCtxKey, parsedIp),
          );
          return next(updatedReq);
        }
      }
      return next(req);
    };
  };
}

Middleware _clientIpFromXff(List<String> trustedPrefixes) {
  final prefixes = trustedPrefixes.map(_CidrPrefix.parse).toList();
  const httpHeader = HttpHeader('X-Forwarded-For');

  return (Handler next) {
    return (Request req) async {
      final headers = req.headers.raw(httpHeader);
      InternetAddress? foundClientIp;

      _walkXff(headers, (entry) {
        final parsedIp = _parseAddr(entry);
        if (parsedIp == null) {
          // Fail-closed on garbage/unparseable entry.
          return true;
        }
        for (final prefix in prefixes) {
          if (prefix.contains(parsedIp)) {
            // Trusted hop; continue walking left.
            return false;
          }
        }
        foundClientIp = parsedIp;
        return true;
      });

      if (foundClientIp case final clientIp?) {
        final updatedReq = req.copyWith(
          ctx: req.ctx.withValue(_clientIpCtxKey, clientIp),
        );
        return next(updatedReq);
      }
      return next(req);
    };
  };
}

Middleware _clientIpFromXffTrustedProxies(int numTrustedProxies) {
  const httpHeader = HttpHeader('X-Forwarded-For');

  return (Handler next) {
    return (Request req) async {
      final headers = req.headers.raw(httpHeader);
      var remainingProxies = numTrustedProxies;
      String? matchedEntry;

      _walkXff(headers, (entry) {
        remainingProxies--;
        if (remainingProxies == 0) {
          matchedEntry = entry;
          return true;
        }
        return false;
      });

      if (matchedEntry != null) {
        final parsedIp = _parseAddr(matchedEntry!);
        if (parsedIp != null) {
          final updatedReq = req.copyWith(
            ctx: req.ctx.withValue(_clientIpCtxKey, parsedIp),
          );
          return next(updatedReq);
        }
      }
      return next(req);
    };
  };
}

Middleware _clientIpFromRemoteAddr() {
  return (Handler next) {
    return (Request req) async {
      final remoteAddress = req.connectionInfo?.remoteAddress;
      if (remoteAddress != null) {
        final normalizedIp = _parseAddr(remoteAddress.address) ?? remoteAddress;
        final updatedReq = req.copyWith(
          ctx: req.ctx.withValue(_clientIpCtxKey, normalizedIp),
        );
        return next(updatedReq);
      }
      return next(req);
    };
  };
}
