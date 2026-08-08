import 'package:ion_web/src/http/version.dart';
import 'package:test/test.dart';

void main() {
  group('HttpVersion', () {
    test('extracts major and minor numbers correctly', () {
      const v11 = HttpVersion.http11;
      expect(v11.major, equals(1));
      expect(v11.minor, equals(1));

      const custom = HttpVersion((2, 5));
      expect(custom.major, equals(2));
      expect(custom.minor, equals(5));
    });

    test('value formats version string as HTTP/major.minor', () {
      expect(HttpVersion.http10.value, equals('HTTP/1.0'));
      expect(HttpVersion.http11.value, equals('HTTP/1.1'));
      expect(HttpVersion.http20.value, equals('HTTP/2.0'));
      expect(HttpVersion.http30.value, equals('HTTP/3.0'));
    });
  });
}
