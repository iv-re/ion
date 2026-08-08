extension type const HttpVersion((int major, int minor) _v) {
  int get major => _v.$1;
  int get minor => _v.$2;

  String get value => 'HTTP/$major.$minor';

  static const HttpVersion http10 = HttpVersion((1, 0));
  static const HttpVersion http11 = HttpVersion((1, 1));
  static const HttpVersion http20 = HttpVersion((2, 0));
  static const HttpVersion http30 = HttpVersion((3, 0));
}
