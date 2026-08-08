/// Standard HTTP header names
extension type const HttpHeader(String name) {
  // Representation & Content
  static const allow = HttpHeader('Allow');
  static const contentDisposition = HttpHeader('Content-Disposition');
  static const contentEncoding = HttpHeader('Content-Encoding');
  static const contentLanguage = HttpHeader('Content-Language');
  static const contentLength = HttpHeader('Content-Length');
  static const contentLocation = HttpHeader('Content-Location');
  static const contentRange = HttpHeader('Content-Range');
  static const contentType = HttpHeader('Content-Type');

  // Controls & General
  static const connection = HttpHeader('Connection');
  static const date = HttpHeader('Date');
  static const expect = HttpHeader('Expect');
  static const from = HttpHeader('From');
  static const host = HttpHeader('Host');
  static const location = HttpHeader('Location');
  static const maxForwards = HttpHeader('Max-Forwards');
  static const referer = HttpHeader('Referer');
  static const retryAfter = HttpHeader('Retry-After');
  static const server = HttpHeader('Server');
  static const trailer = HttpHeader('Trailer');
  static const transferEncoding = HttpHeader('Transfer-Encoding');
  static const upgrade = HttpHeader('Upgrade');
  static const userAgent = HttpHeader('User-Agent');
  static const vary = HttpHeader('Vary');
  static const via = HttpHeader('Via');

  // Request Headers
  static const accept = HttpHeader('Accept');
  static const acceptCharset = HttpHeader('Accept-Charset');
  static const acceptEncoding = HttpHeader('Accept-Encoding');
  static const acceptLanguage = HttpHeader('Accept-Language');
  static const authorization = HttpHeader('Authorization');
  static const cookie = HttpHeader('Cookie');
  static const proxyAuthorization = HttpHeader('Proxy-Authorization');
  static const range = HttpHeader('Range');
  static const te = HttpHeader('TE');

  // Response Headers
  static const acceptRanges = HttpHeader('Accept-Ranges');
  static const age = HttpHeader('Age');
  static const etag = HttpHeader('ETag');
  static const proxyAuthenticate = HttpHeader('Proxy-Authenticate');
  static const setCookie = HttpHeader('Set-Cookie');
  static const wwwAuthenticate = HttpHeader('WWW-Authenticate');

  // Preconditions & Conditional Requests
  static const ifMatch = HttpHeader('If-Match');
  static const ifModifiedSince = HttpHeader('If-Modified-Since');
  static const ifNoneMatch = HttpHeader('If-None-Match');
  static const ifRange = HttpHeader('If-Range');
  static const ifUnmodifiedSince = HttpHeader('If-Unmodified-Since');
  static const lastModified = HttpHeader('Last-Modified');

  // Caching
  static const cacheControl = HttpHeader('Cache-Control');
  static const expires = HttpHeader('Expires');
  static const pragma = HttpHeader('Pragma');

  // CORS
  static const accessControlAllowCredentials = HttpHeader(
    'Access-Control-Allow-Credentials',
  );
  static const accessControlAllowHeaders = HttpHeader(
    'Access-Control-Allow-Headers',
  );
  static const accessControlAllowMethods = HttpHeader(
    'Access-Control-Allow-Methods',
  );
  static const accessControlAllowOrigin = HttpHeader(
    'Access-Control-Allow-Origin',
  );
  static const accessControlExposeHeaders = HttpHeader(
    'Access-Control-Expose-Headers',
  );
  static const accessControlMaxAge = HttpHeader('Access-Control-Max-Age');
  static const accessControlRequestHeaders = HttpHeader(
    'Access-Control-Request-Headers',
  );
  static const accessControlRequestMethod = HttpHeader(
    'Access-Control-Request-Method',
  );
  static const origin = HttpHeader('Origin');

  // Security
  static const contentSecurityPolicy = HttpHeader('Content-Security-Policy');
  static const contentSecurityPolicyReportOnly = HttpHeader(
    'Content-Security-Policy-Report-Only',
  );
  static const referrerPolicy = HttpHeader('Referrer-Policy');
  static const strictTransportSecurity = HttpHeader(
    'Strict-Transport-Security',
  );
  static const xContentTypeOptions = HttpHeader('X-Content-Type-Options');
  static const xFrameOptions = HttpHeader('X-Frame-Options');
  static const xXssProtection = HttpHeader('X-XSS-Protection');

  // WebSocket
  static const secWebSocketAccept = HttpHeader('Sec-WebSocket-Accept');
  static const secWebSocketExtensions = HttpHeader('Sec-WebSocket-Extensions');
  static const secWebSocketKey = HttpHeader('Sec-WebSocket-Key');
  static const secWebSocketProtocol = HttpHeader('Sec-WebSocket-Protocol');
  static const secWebSocketVersion = HttpHeader('Sec-WebSocket-Version');
}
