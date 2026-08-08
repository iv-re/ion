import 'dart:io';

import 'package:http_headers/src/authentication_challenge.dart';
import 'package:http_headers/src/entity_tag.dart';
import 'package:http_headers/src/headers/headers.dart';

abstract interface class TypedHeader {
  // --- Accept-Ranges ---
  const factory TypedHeader.acceptRanges(String rangeUnit) = AcceptRangesHeader;
  const factory TypedHeader.acceptRangesBytes() = AcceptRangesHeader.bytes;
  const factory TypedHeader.acceptRangesNone() = AcceptRangesHeader.none;

  // --- Access-Control-Allow-Credentials ---
  const factory TypedHeader.accessControlAllowCredentials() =
      AccessControlAllowCredentialsHeader;

  // --- Access-Control-Allow-Headers ---
  const factory TypedHeader.accessControlAllowHeaders(
    List<String> headers,
  ) = AccessControlAllowHeadersHeader;

  // --- Access-Control-Allow-Methods ---
  const factory TypedHeader.accessControlAllowMethods(
    List<String> methods,
  ) = AccessControlAllowMethodsHeader;

  // --- Access-Control-Allow-Origin ---
  factory TypedHeader.accessControlAllowOrigin(
    AccessControlAllowOriginHeader header,
  ) => header;

  // --- Access-Control-Expose-Headers ---
  const factory TypedHeader.accessControlExposeHeaders(
    List<String> headers,
  ) = AccessControlExposeHeadersHeader;

  // --- Access-Control-Max-Age ---
  const factory TypedHeader.accessControlMaxAge(
    Duration duration,
  ) = AccessControlMaxAgeHeader;

  // --- Access-Control-Request-Headers ---
  const factory TypedHeader.accessControlRequestHeaders(
    List<String> headers,
  ) = AccessControlRequestHeadersHeader;

  // --- Access-Control-Request-Method ---
  const factory TypedHeader.accessControlRequestMethod(
    String method,
  ) = AccessControlRequestMethodHeader;

  // --- Age ---
  const factory TypedHeader.age(Duration duration) = AgeHeader;
  factory TypedHeader.ageFromSeconds(int seconds) = AgeHeader.fromSeconds;

  // --- Allow ---
  const factory TypedHeader.allow(List<String> methods) = AllowHeader;

  // --- Authorization ---
  factory TypedHeader.authorization(AuthorizationHeader header) => header;

  // --- Cache-Control ---
  const factory TypedHeader.cacheControl({
    bool noCache,
    bool noStore,
    bool noTransform,
    bool onlyIfCached,
    bool mustRevalidate,
    bool isPublic,
    bool isPrivate,
    bool isImmutable,
    bool mustUnderstand,
    bool proxyRevalidate,
    Duration? maxAge,
    Duration? maxStale,
    Duration? minFresh,
    Duration? sMaxAge,
  }) = CacheControlHeader;

  // --- Connection ---
  const factory TypedHeader.connection(List<String> options) = ConnectionHeader;
  const factory TypedHeader.connectionClose() = ConnectionHeader.close;
  const factory TypedHeader.connectionKeepAlive() = ConnectionHeader.keepAlive;
  const factory TypedHeader.connectionUpgrade() = ConnectionHeader.upgrade;

  // --- Content-Disposition ---
  const factory TypedHeader.contentDisposition(String value) =
      ContentDispositionHeader;
  const factory TypedHeader.contentDispositionInline() =
      ContentDispositionHeader.inline;
  const factory TypedHeader.contentDispositionAttachment() =
      ContentDispositionHeader.attachment;

  // --- Content-Encoding ---
  const factory TypedHeader.contentEncoding(
    List<String> codings,
  ) = ContentEncodingHeader;
  const factory TypedHeader.contentEncodingGzip() = ContentEncodingHeader.gzip;
  const factory TypedHeader.contentEncodingBrotli() =
      ContentEncodingHeader.brotli;
  const factory TypedHeader.contentEncodingZstd() = ContentEncodingHeader.zstd;

  // --- Content-Length ---
  const factory TypedHeader.contentLength(int bytes) = ContentLengthHeader;

  // --- Content-Location ---
  const factory TypedHeader.contentLocation(String uri) = ContentLocationHeader;

  // --- Content-Range ---
  const factory TypedHeader.contentRange(
    int? start,
    int? end, [
    int? completeLength,
  ]) = ContentRangeHeader;
  const factory TypedHeader.contentRangeBytes(
    int start,
    int end,
    int completeLength,
  ) = ContentRangeHeader.bytes;
  const factory TypedHeader.contentRangeUnsatisfiedBytes(
    int completeLength,
  ) = ContentRangeHeader.unsatisfiedBytes;

  // --- Content-Type ---
  const factory TypedHeader.contentType(
    String mediaType, {
    String? charset,
    String? boundary,
  }) = ContentTypeHeader;
  const factory TypedHeader.contentTypeJson() = ContentTypeHeader.json;
  const factory TypedHeader.contentTypeJsonUtf8() = ContentTypeHeader.jsonUtf8;
  const factory TypedHeader.contentTypeJsonProblem() =
      ContentTypeHeader.jsonProblem;
  const factory TypedHeader.contentTypeEventStream() =
      ContentTypeHeader.eventStream;
  const factory TypedHeader.contentTypeNdjson() = ContentTypeHeader.ndjson;
  const factory TypedHeader.contentTypeText() = ContentTypeHeader.text;
  const factory TypedHeader.contentTypeTextUtf8() = ContentTypeHeader.textUtf8;
  const factory TypedHeader.contentTypeHtml() = ContentTypeHeader.html;
  const factory TypedHeader.contentTypeXml() = ContentTypeHeader.xml;
  const factory TypedHeader.contentTypeFormUrlEncoded() =
      ContentTypeHeader.formUrlEncoded;
  const factory TypedHeader.contentTypeMultipartFormData({String? boundary}) =
      ContentTypeHeader.multipartFormData;
  const factory TypedHeader.contentTypeJpeg() = ContentTypeHeader.jpeg;
  const factory TypedHeader.contentTypePng() = ContentTypeHeader.png;
  const factory TypedHeader.contentTypeWebp() = ContentTypeHeader.webp;
  const factory TypedHeader.contentTypeSvg() = ContentTypeHeader.svg;
  const factory TypedHeader.contentTypePdf() = ContentTypeHeader.pdf;
  const factory TypedHeader.contentTypeOctetStream() =
      ContentTypeHeader.octetStream;
  const factory TypedHeader.contentTypeProtobuf() = ContentTypeHeader.protobuf;

  // --- Cookie ---
  const factory TypedHeader.cookie(Map<String, String> cookies) = CookieHeader;

  // --- Date ---
  const factory TypedHeader.date(DateTime date) = DateHeader;

  // --- ETag ---
  const factory TypedHeader.etag(EntityTag tag) = ETagHeader;
  factory TypedHeader.etagWeak(String tag) = ETagHeader.weak;
  factory TypedHeader.etagStrong(String tag) = ETagHeader.strong;

  // --- Expect ---
  factory TypedHeader.expect(ExpectHeader header) => header;

  // --- Expires ---
  const factory TypedHeader.expires(DateTime date) = ExpiresHeader;

  // --- From ---
  const factory TypedHeader.from(String email) = FromHeader;

  // --- Host ---
  const factory TypedHeader.host(String value) = HostHeader;

  // --- If-Match ---
  factory TypedHeader.ifMatch(IfMatchHeader header) => header;

  // --- If-Modified-Since ---
  const factory TypedHeader.ifModifiedSince(
    DateTime date,
  ) = IfModifiedSinceHeader;

  // --- If-None-Match ---
  factory TypedHeader.ifNoneMatch(IfNoneMatchHeader header) => header;

  // --- If-Range ---
  factory TypedHeader.ifRange(IfRangeHeader header) => header;

  // --- If-Unmodified-Since ---
  const factory TypedHeader.ifUnmodifiedSince(
    DateTime date,
  ) = IfUnmodifiedSinceHeader;

  // --- Last-Modified ---
  const factory TypedHeader.lastModified(DateTime date) = LastModifiedHeader;

  // --- Location ---
  const factory TypedHeader.location(String uri) = LocationHeader;

  // --- Max-Forwards ---
  const factory TypedHeader.maxForwards(int count) = MaxForwardsHeader;

  // --- Origin ---
  factory TypedHeader.origin(OriginHeader header) => header;

  // --- Pragma ---
  const factory TypedHeader.pragma(String value) = PragmaHeader;
  const factory TypedHeader.pragmaNoCache() = PragmaHeader.noCache;

  // --- Proxy-Authenticate ---
  const factory TypedHeader.proxyAuthenticate(
    List<AuthenticationChallenge> challenges,
  ) = ProxyAuthenticateHeader;

  // --- Proxy-Authorization ---
  factory TypedHeader.proxyAuthorization(
    ProxyAuthorizationHeader header,
  ) => header;

  // --- Range ---
  const factory TypedHeader.range(String rawValue) = RangeHeader;
  factory TypedHeader.rangeBytes(int start, [int? end]) = RangeHeader.bytes;

  // --- Referer ---
  const factory TypedHeader.referer(String uri) = RefererHeader;

  // --- Referrer-Policy ---
  factory TypedHeader.referrerPolicy(ReferrerPolicyHeader header) => header;

  // --- Retry-After ---
  factory TypedHeader.retryAfter(RetryAfterHeader header) => header;

  // --- Sec-WebSocket-Accept ---
  const factory TypedHeader.secWebSocketAccept(String value) =
      SecWebSocketAcceptHeader;

  // --- Sec-WebSocket-Extensions ---
  const factory TypedHeader.secWebSocketExtensions({
    bool perMessageDeflate,
    bool clientNoContextTakeover,
    bool serverNoContextTakeover,
    List<String> customExtensions,
  }) = SecWebSocketExtensionsHeader;

  // --- Sec-WebSocket-Key ---
  const factory TypedHeader.secWebSocketKey(
    String value,
  ) = SecWebSocketKeyHeader;
  factory TypedHeader.secWebSocketKeyFromBytes(
    List<int> bytes,
  ) = SecWebSocketKeyHeader.fromBytes;

  // --- Sec-WebSocket-Protocol ---
  const factory TypedHeader.secWebSocketProtocol(
    List<String> protocols,
  ) = SecWebSocketProtocolHeader;
  factory TypedHeader.secWebSocketProtocolSingle(
    String protocol,
  ) = SecWebSocketProtocolHeader.single;

  // --- Sec-WebSocket-Version ---
  const factory TypedHeader.secWebSocketVersion(
    int version,
  ) = SecWebSocketVersionHeader;
  const factory TypedHeader.secWebSocketVersionV13() =
      SecWebSocketVersionHeader.v13;

  // --- Server ---
  const factory TypedHeader.server(String value) = ServerHeader;

  // --- Set-Cookie ---
  const factory TypedHeader.setCookie(
    List<Cookie> cookies,
  ) = SetCookieHeader;
  factory TypedHeader.setCookieFromCookie(
    Cookie cookie,
  ) = SetCookieHeader.fromCookie;

  // --- Strict-Transport-Security ---
  const factory TypedHeader.strictTransportSecurity({
    required Duration maxAge,
    bool includeSubdomains,
  }) = StrictTransportSecurityHeader;
  const factory TypedHeader.strictTransportSecurityIncludingSubdomains(
    Duration maxAge,
  ) = StrictTransportSecurityHeader.includingSubdomains;
  const factory TypedHeader.strictTransportSecurityExcludingSubdomains(
    Duration maxAge,
  ) = StrictTransportSecurityHeader.excludingSubdomains;

  // --- Trailer ---
  const factory TypedHeader.trailer(List<String> fieldNames) = TrailerHeader;

  // --- TE ---
  const factory TypedHeader.te(List<String> codings) = TeHeader;
  const factory TypedHeader.teTrailers() = TeHeader.trailers;

  // --- Transfer-Encoding ---
  const factory TypedHeader.transferEncoding(
    List<TransferCoding> codings,
  ) = TransferEncodingHeader;
  const factory TypedHeader.transferEncodingChunked() =
      TransferEncodingHeader.chunked;

  // --- Upgrade ---
  const factory TypedHeader.upgrade(List<String> protocols) = UpgradeHeader;
  const factory TypedHeader.upgradeWebsocket() = UpgradeHeader.websocket;

  // --- User-Agent ---
  const factory TypedHeader.userAgent(String value) = UserAgentHeader;

  // --- Vary ---
  const factory TypedHeader.vary(List<String> headers) = VaryHeader;
  const factory TypedHeader.varyAny() = VaryHeader.any;

  // --- WWW-Authenticate ---
  const factory TypedHeader.wwwAuthenticate(
    List<AuthenticationChallenge> challenges,
  ) = WwwAuthenticateHeader;

  // --- X-Content-Type-Options ---
  const factory TypedHeader.xContentTypeOptions(String options) =
      XContentTypeOptionsHeader;
  const factory TypedHeader.xContentTypeOptionsNosniff() =
      XContentTypeOptionsHeader.nosniff;

  String get name;

  Iterable<String> encode();
}

extension HeaderExtension on TypedHeader {
  /// Formatted single header value string (comma-separated if multiple values).
  String get value => encode().join(', ');
}
