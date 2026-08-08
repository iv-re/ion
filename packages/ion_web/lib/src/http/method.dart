extension type const HttpMethod(String value) {
  static const HttpMethod get = HttpMethod('GET');
  static const HttpMethod put = HttpMethod('PUT');
  static const HttpMethod post = HttpMethod('POST');
  static const HttpMethod head = HttpMethod('HEAD');
  static const HttpMethod patch = HttpMethod('PATCH');
  static const HttpMethod delete = HttpMethod('DELETE');
  static const HttpMethod options = HttpMethod('OPTIONS');
  static const HttpMethod connect = HttpMethod('CONNECT');
  static const HttpMethod trace = HttpMethod('TRACE');
  static const HttpMethod query = HttpMethod('QUERY');
}
