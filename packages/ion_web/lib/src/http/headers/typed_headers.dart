import 'dart:typed_data';

import 'package:http_headers/http_headers.dart';
import 'package:ion_web/src/http/headers/slices.dart';
import 'package:ion_web/src/http/utils.dart';
import 'package:meta/meta.dart';

export 'package:http_headers/http_headers.dart';

class TypedHeaders with _FramingHeaders {
  TypedHeaders(this._slices) {
    _parseFramingHeaders(_slices, _typedCache);
  }

  factory TypedHeaders.fromList(Iterable<TypedHeader> headers) {
    final slices = <HeaderEntrySlices>[];
    final token = SliceBufferToken();

    for (final header in headers) {
      for (final value in header.encode()) {
        final keyBytes = Uint8List.fromList(header.name.codeUnits);
        final valBytes = Uint8List.fromList(value.codeUnits);
        final keySlice = HeaderByteSlice(keyBytes, 0, keyBytes.length, token);
        final valSlice = HeaderByteSlice(valBytes, 0, valBytes.length, token);

        slices.add(HeaderEntrySlices(keySlice, valSlice));
      }
    }

    return TypedHeaders(slices);
  }

  final List<HeaderEntrySlices> _slices;
  final Map<String, TypedHeader?> _typedCache = {};
  final Map<String, List<String>> _rawCache = {};

  /// Returns all raw key-value entries as strings.
  Iterable<MapEntry<String, String>> get entries {
    return _slices.map(
      (s) => MapEntry(s.key.asString(), s.value.asString()),
    );
  }

  /// Checks whether a header with the given name is present.
  bool has(HttpHeader header) {
    return _slices.any((s) => s.key.matchesKey(header.name));
  }

  /// Decodes and caches a typed header for [header] using [decode].
  ///
  /// Returns `null` if the header is not present or if [decode] returns `null`.
  T? decode<T extends TypedHeader>(
    HttpHeader header,
    T? Function(Iterable<String> values) decode,
  ) {
    final key = header.name;
    if (_typedCache.containsKey(key)) {
      return _typedCache[key] as T?;
    }

    final matchingSlices = _slices.where((s) => s.key.matchesKey(key));
    if (matchingSlices.isEmpty) {
      _typedCache[key] = null;
      return null;
    }

    final values = matchingSlices.map((s) => s.value.asString());
    final decoded = decode(values);
    _typedCache[key] = decoded;
    return decoded;
  }

  /// Returns all raw string values for [header].
  ///
  /// Returns an empty list if the header is not present.
  List<String> raw(HttpHeader header) {
    final key = header.name;
    if (_rawCache[key] case final value?) {
      return value;
    }

    final matchingSlices = _slices.where((s) => s.key.matchesKey(key));
    if (matchingSlices.isEmpty) {
      _rawCache[key] = const [];
      return const [];
    }

    final values = matchingSlices.map((s) => s.value.asString()).toList();
    _rawCache[key] = values;
    return values;
  }
}

extension DefaultTypedHeaders on TypedHeaders {
  /// The `Accept-Ranges` header, if present.
  AcceptRangesHeader? get acceptRanges {
    return decode(.acceptRanges, AcceptRangesHeader.decode);
  }

  /// The `Access-Control-Allow-Credentials` header, if present.
  AccessControlAllowCredentialsHeader? get accessControlAllowCredentials {
    return decode(
      .accessControlAllowCredentials,
      AccessControlAllowCredentialsHeader.decode,
    );
  }

  /// The `Access-Control-Allow-Headers` header, if present.
  AccessControlAllowHeadersHeader? get accessControlAllowHeaders {
    return decode(
      .accessControlAllowHeaders,
      AccessControlAllowHeadersHeader.decode,
    );
  }

  /// The `Access-Control-Allow-Methods` header, if present.
  AccessControlAllowMethodsHeader? get accessControlAllowMethods {
    return decode(
      .accessControlAllowMethods,
      AccessControlAllowMethodsHeader.decode,
    );
  }

  /// The `Access-Control-Allow-Origin` header, if present.
  AccessControlAllowOriginHeader? get accessControlAllowOrigin {
    return decode(
      .accessControlAllowOrigin,
      AccessControlAllowOriginHeader.decode,
    );
  }

  /// The `Access-Control-Expose-Headers` header, if present.
  AccessControlExposeHeadersHeader? get accessControlExposeHeaders {
    return decode(
      .accessControlExposeHeaders,
      AccessControlExposeHeadersHeader.decode,
    );
  }

  /// The `Access-Control-Max-Age` header, if present.
  AccessControlMaxAgeHeader? get accessControlMaxAge {
    return decode(.accessControlMaxAge, AccessControlMaxAgeHeader.decode);
  }

  /// The `Access-Control-Request-Headers` header, if present.
  AccessControlRequestHeadersHeader? get accessControlRequestHeaders {
    return decode(
      .accessControlRequestHeaders,
      AccessControlRequestHeadersHeader.decode,
    );
  }

  /// The `Access-Control-Request-Method` header, if present.
  AccessControlRequestMethodHeader? get accessControlRequestMethod {
    return decode(
      .accessControlRequestMethod,
      AccessControlRequestMethodHeader.decode,
    );
  }

  /// The `Age` header, if present.
  AgeHeader? get age {
    return decode(.age, AgeHeader.decode);
  }

  /// The `Allow` header, if present.
  AllowHeader? get allow {
    return decode(.allow, AllowHeader.decode);
  }

  /// The `Authorization` header, if present.
  AuthorizationHeader? get authorization {
    return decode(.authorization, AuthorizationHeader.decode);
  }

  /// The `Cache-Control` header, if present.
  CacheControlHeader? get cacheControl {
    return decode(.cacheControl, CacheControlHeader.decode);
  }

  /// The `Connection` header, if present.
  ConnectionHeader? get connection {
    return decode(.connection, ConnectionHeader.decode);
  }

  /// The `Content-Disposition` header, if present.
  ContentDispositionHeader? get contentDisposition {
    return decode(.contentDisposition, ContentDispositionHeader.decode);
  }

  /// The `Content-Encoding` header, if present.
  ContentEncodingHeader? get contentEncoding {
    return decode(.contentEncoding, ContentEncodingHeader.decode);
  }

  /// The `Content-Length` header, if present.
  ContentLengthHeader? get contentLength {
    return decode(.contentLength, ContentLengthHeader.decode);
  }

  /// The `Content-Location` header, if present.
  ContentLocationHeader? get contentLocation {
    return decode(.contentLocation, ContentLocationHeader.decode);
  }

  /// The `Content-Range` header, if present.
  ContentRangeHeader? get contentRange {
    return decode(.contentRange, ContentRangeHeader.decode);
  }

  /// The `Content-Type` header, if present.
  ContentTypeHeader? get contentType {
    return decode(.contentType, ContentTypeHeader.decode);
  }

  /// The `Cookie` header, if present.
  CookieHeader? get cookie {
    return decode(.cookie, CookieHeader.decode);
  }

  /// The `Date` header, if present.
  DateHeader? get date {
    return decode(.date, DateHeader.decode);
  }

  /// The `ETag` header, if present.
  ETagHeader? get etag {
    return decode(.etag, ETagHeader.decode);
  }

  /// The `Expect` header, if present.
  ExpectHeader? get expect {
    return decode(.expect, ExpectHeader.decode);
  }

  /// The `Expires` header, if present.
  ExpiresHeader? get expires {
    return decode(.expires, ExpiresHeader.decode);
  }

  /// The `From` header, if present.
  FromHeader? get from {
    return decode(.from, FromHeader.decode);
  }

  /// The `Host` header, if present.
  HostHeader? get host {
    return decode(.host, HostHeader.decode);
  }

  /// The `If-Match` header, if present.
  IfMatchHeader? get ifMatch {
    return decode(.ifMatch, IfMatchHeader.decode);
  }

  /// The `If-Modified-Since` header, if present.
  IfModifiedSinceHeader? get ifModifiedSince {
    return decode(.ifModifiedSince, IfModifiedSinceHeader.decode);
  }

  /// The `If-None-Match` header, if present.
  IfNoneMatchHeader? get ifNoneMatch {
    return decode(.ifNoneMatch, IfNoneMatchHeader.decode);
  }

  /// The `If-Range` header, if present.
  IfRangeHeader? get ifRange {
    return decode(.ifRange, IfRangeHeader.decode);
  }

  /// The `If-Unmodified-Since` header, if present.
  IfUnmodifiedSinceHeader? get ifUnmodifiedSince {
    return decode(.ifUnmodifiedSince, IfUnmodifiedSinceHeader.decode);
  }

  /// The `Last-Modified` header, if present.
  LastModifiedHeader? get lastModified {
    return decode(.lastModified, LastModifiedHeader.decode);
  }

  /// The `Location` header, if present.
  LocationHeader? get location {
    return decode(.location, LocationHeader.decode);
  }

  /// The `Max-Forwards` header, if present.
  MaxForwardsHeader? get maxForwards {
    return decode(.maxForwards, MaxForwardsHeader.decode);
  }

  /// The `Origin` header, if present.
  OriginHeader? get origin {
    return decode(.origin, OriginHeader.decode);
  }

  /// The `Pragma` header, if present.
  PragmaHeader? get pragma {
    return decode(.pragma, PragmaHeader.decode);
  }

  /// The `Proxy-Authenticate` header, if present.
  ProxyAuthenticateHeader? get proxyAuthenticate {
    return decode(.proxyAuthenticate, ProxyAuthenticateHeader.decode);
  }

  /// The `Proxy-Authorization` header, if present.
  ProxyAuthorizationHeader? get proxyAuthorization {
    return decode(.proxyAuthorization, ProxyAuthorizationHeader.decode);
  }

  /// The `Range` header, if present.
  RangeHeader? get range {
    return decode(.range, RangeHeader.decode);
  }

  /// The `Referer` header, if present.
  RefererHeader? get referer {
    return decode(.referer, RefererHeader.decode);
  }

  /// The `Referrer-Policy` header, if present.
  ReferrerPolicyHeader? get referrerPolicy {
    return decode(.referrerPolicy, ReferrerPolicyHeader.decode);
  }

  /// The `Retry-After` header, if present.
  RetryAfterHeader? get retryAfter {
    return decode(.retryAfter, RetryAfterHeader.decode);
  }

  /// The `Sec-WebSocket-Accept` header, if present.
  SecWebSocketAcceptHeader? get secWebSocketAccept {
    return decode(.secWebSocketAccept, SecWebSocketAcceptHeader.decode);
  }

  /// The `Sec-WebSocket-Extensions` header, if present.
  SecWebSocketExtensionsHeader? get secWebSocketExtensions {
    return decode(.secWebSocketExtensions, SecWebSocketExtensionsHeader.decode);
  }

  /// The `Sec-WebSocket-Key` header, if present.
  SecWebSocketKeyHeader? get secWebSocketKey {
    return decode(.secWebSocketKey, SecWebSocketKeyHeader.decode);
  }

  /// The `Sec-WebSocket-Protocol` header, if present.
  SecWebSocketProtocolHeader? get secWebSocketProtocol {
    return decode(.secWebSocketProtocol, SecWebSocketProtocolHeader.decode);
  }

  /// The `Sec-WebSocket-Version` header, if present.
  SecWebSocketVersionHeader? get secWebSocketVersion {
    return decode(.secWebSocketVersion, SecWebSocketVersionHeader.decode);
  }

  /// The `Server` header, if present.
  ServerHeader? get server {
    return decode(.server, ServerHeader.decode);
  }

  /// The `Set-Cookie` header, if present.
  SetCookieHeader? get setCookie {
    return decode(.setCookie, SetCookieHeader.decode);
  }

  /// The `Strict-Transport-Security` header, if present.
  StrictTransportSecurityHeader? get strictTransportSecurity {
    return decode(
      .strictTransportSecurity,
      StrictTransportSecurityHeader.decode,
    );
  }

  /// The `TE` header, if present.
  TeHeader? get te {
    return decode(.te, TeHeader.decode);
  }

  /// The `Trailer` header, if present.
  TrailerHeader? get trailer {
    return decode(.trailer, TrailerHeader.decode);
  }

  /// The `Transfer-Encoding` header, if present.
  TransferEncodingHeader? get transferEncoding {
    return decode(.transferEncoding, TransferEncodingHeader.decode);
  }

  /// The `Upgrade` header, if present.
  UpgradeHeader? get upgrade {
    return decode(.upgrade, UpgradeHeader.decode);
  }

  /// The `User-Agent` header, if present.
  UserAgentHeader? get userAgent {
    return decode(.userAgent, UserAgentHeader.decode);
  }

  /// The `Vary` header, if present.
  VaryHeader? get vary {
    return decode(.vary, VaryHeader.decode);
  }

  /// The `WWW-Authenticate` header, if present.
  WwwAuthenticateHeader? get wwwAuthenticate {
    return decode(.wwwAuthenticate, WwwAuthenticateHeader.decode);
  }

  /// The `X-Content-Type-Options` header, if present.
  XContentTypeOptionsHeader? get xContentTypeOptions {
    return decode(.xContentTypeOptions, XContentTypeOptionsHeader.decode);
  }
}

extension TypedHeaderIterableExtension on Iterable<TypedHeader> {
  /// Checks whether a header of type [T] or matching [name] is present.
  bool has<T extends TypedHeader>([String? name]) {
    if (name != null) {
      return any((h) => h is T && h.name.equalsIgnoreAsciiCase(name));
    }
    return any((h) => h is T);
  }

  /// Returns the first header of type [T] (optionally matching [name]).
  T? get<T extends TypedHeader>([String? name]) {
    for (final h in this) {
      if (h is T && (name == null || h.name.equalsIgnoreAsciiCase(name))) {
        return h;
      }
    }
    return null;
  }
}

extension TypedHeaderListExtension on List<TypedHeader> {
  /// Adds [header] to the list if no header with the same name is already
  /// present.
  void addIfAbsent(TypedHeader header) {
    if (!has(header.name)) {
      add(header);
    }
  }
}

mixin _FramingHeaders {
  int _contentLengthCount = 0;
  int? _contentLengthValue;
  bool _contentLengthDigitsValid = true;

  int _hostCount = 0;

  bool _hasTransferEncoding = false;
  bool _isChunked = false;
  bool _hasChunked = false;
  bool _isTransferEncodingInvalid = false;

  void _parseFramingHeaders(
    List<HeaderEntrySlices> slices,
    Map<String, TypedHeader?> cache,
  ) {
    for (var i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final key = slice.key;

      if (key.matchesKey(HttpHeader.contentLength.name)) {
        _contentLengthCount++;
        if (_contentLengthCount > 1) {
          cache[HttpHeader.contentLength.name] = null;
          continue;
        }

        final val = slice.value.asString();
        final parsed = val.isAsciiDigits ? int.tryParse(val) : null;

        if (parsed != null && parsed >= 0) {
          _contentLengthValue = parsed;
          cache[HttpHeader.contentLength.name] = ContentLengthHeader(parsed);
        } else {
          _contentLengthDigitsValid = false;
          cache[HttpHeader.contentLength.name] = null;
        }
      } else if (key.matchesKey(HttpHeader.host.name)) {
        _hostCount++;
        if (_hostCount == 1) {
          cache[HttpHeader.host.name] = HostHeader(
            slice.value.asString().trim(),
          );
        } else {
          cache[HttpHeader.host.name] = null;
        }
      } else if (key.matchesKey(HttpHeader.transferEncoding.name)) {
        _hasTransferEncoding = true;
        if (slice.value.matches('chunked')) {
          _isChunked = true;
          _hasChunked = true;
          cache[HttpHeader.transferEncoding.name] =
              const TransferEncodingHeader.chunked();
        } else {
          final val = slice.value.asString();
          if (val.isEmpty) {
            _isTransferEncodingInvalid = true;
            cache[HttpHeader.transferEncoding.name] = null;
          } else {
            final parsedTe = TransferEncodingHeader.decode([val]);
            if (parsedTe == null || parsedTe.codings.isEmpty) {
              _isTransferEncodingInvalid = true;
              cache[HttpHeader.transferEncoding.name] = null;
            } else {
              cache[HttpHeader.transferEncoding.name] = parsedTe;
              _isChunked = parsedTe.isChunked;
              _hasChunked = parsedTe.codings.any((c) => c.isChunked);
            }
          }
        }
      }
    }
  }

  @internal
  int? get parsedContentLength {
    return (_contentLengthCount == 1 && _contentLengthDigitsValid)
        ? _contentLengthValue
        : null;
  }

  @internal
  bool get hasContentLengthConflict {
    return _contentLengthCount > 1 || !_contentLengthDigitsValid;
  }

  @internal
  bool get hasHostConflict => _hostCount > 1;

  @internal
  bool get hasTransferEncoding => _hasTransferEncoding;

  @internal
  bool get isChunkedTransferEncoding => _isChunked;

  @internal
  bool get hasNonFinalChunkedConflict => _hasChunked && !_isChunked;

  @internal
  bool get isTransferEncodingInvalid => _isTransferEncodingInvalid;
}
