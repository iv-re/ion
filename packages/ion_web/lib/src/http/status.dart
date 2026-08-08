enum HttpStatusCode implements Comparable<HttpStatusCode> {
  // 1xx Informational
  continue_(100, 'Continue'),
  switchingProtocols(101, 'Switching Protocols'),
  processing(102, 'Processing'),
  earlyHints(103, 'Early Hints'),

  // 2xx Success
  ok(200, 'OK'),
  created(201, 'Created'),
  accepted(202, 'Accepted'),
  nonAuthoritativeInformation(203, 'Non-Authoritative Information'),
  noContent(204, 'No Content'),
  resetContent(205, 'Reset Content'),
  partialContent(206, 'Partial Content'),
  multiStatus(207, 'Multi-Status'),
  alreadyReported(208, 'Already Reported'),
  imUsed(226, 'IM Used'),

  // 3xx Redirection
  multipleChoices(300, 'Multiple Choices'),
  movedPermanently(301, 'Moved Permanently'),
  found(302, 'Found'),
  seeOther(303, 'See Other'),
  notModified(304, 'Not Modified'),
  useProxy(305, 'Use Proxy'),
  temporaryRedirect(307, 'Temporary Redirect'),
  permanentRedirect(308, 'Permanent Redirect'),

  // 4xx Client Errors
  badRequest(400, 'Bad Request'),
  unauthorized(401, 'Unauthorized'),
  paymentRequired(402, 'Payment Required'),
  forbidden(403, 'Forbidden'),
  notFound(404, 'Not Found'),
  methodNotAllowed(405, 'Method Not Allowed'),
  notAcceptable(406, 'Not Acceptable'),
  proxyAuthenticationRequired(407, 'Proxy Authentication Required'),
  requestTimeout(408, 'Request Timeout'),
  conflict(409, 'Conflict'),
  gone(410, 'Gone'),
  lengthRequired(411, 'Length Required'),
  preconditionFailed(412, 'Precondition Failed'),
  contentTooLarge(413, 'Content Too Large'),
  uriTooLong(414, 'URI Too Long'),
  unsupportedMediaType(415, 'Unsupported Media Type'),
  rangeNotSatisfiable(416, 'Range Not Satisfiable'),
  expectationFailed(417, 'Expectation Failed'),
  imATeapot(418, "I'm a teapot"),
  misdirectedRequest(421, 'Misdirected Request'),
  unprocessableEntity(422, 'Unprocessable Entity'),
  locked(423, 'Locked'),
  failedDependency(424, 'Failed Dependency'),
  tooEarly(425, 'Too Early'),
  upgradeRequired(426, 'Upgrade Required'),
  preconditionRequired(428, 'Precondition Required'),
  tooManyRequests(429, 'Too Many Requests'),
  requestHeaderFieldsTooLarge(431, 'Request Header Fields Too Large'),
  unavailableForLegalReasons(451, 'Unavailable For Legal Reasons'),

  // 5xx Server Errors
  internalServerError(500, 'Internal Server Error'),
  notImplemented(501, 'Not Implemented'),
  badGateway(502, 'Bad Gateway'),
  serviceUnavailable(503, 'Service Unavailable'),
  gatewayTimeout(504, 'Gateway Timeout'),
  httpVersionNotSupported(505, 'HTTP Version Not Supported'),
  variantAlsoNegotiates(506, 'Variant Also Negotiates'),
  insufficientStorage(507, 'Insufficient Storage'),
  loopDetected(508, 'Loop Detected'),
  notExtended(510, 'Not Extended'),
  networkAuthenticationRequired(511, 'Network Authentication Required');

  const HttpStatusCode(this.value, this.reasonPhrase);

  final int value;
  final String reasonPhrase;

  @override
  int compareTo(HttpStatusCode other) => value.compareTo(other.value);

  bool operator <(HttpStatusCode other) => value < other.value;
  bool operator <=(HttpStatusCode other) => value <= other.value;
  bool operator >(HttpStatusCode other) => value > other.value;
  bool operator >=(HttpStatusCode other) => value >= other.value;
}
