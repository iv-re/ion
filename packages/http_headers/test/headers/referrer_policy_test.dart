import 'package:http_headers/src/headers/referrer_policy.dart';
import 'package:test/test.dart';

void main() {
  group('ReferrerPolicyHeader', () {
    test('decodes strict-origin-when-cross-origin correctly', () {
      final header = ReferrerPolicyHeader.decode([
        'strict-origin-when-cross-origin',
      ]);
      expect(header, isA<ReferrerPolicyStrictOriginWhenCrossOrigin>());
      expect(
        header?.encode(),
        equals(['strict-origin-when-cross-origin']),
      );
    });

    test('picks the last recognized policy token in CSV values', () {
      final header = ReferrerPolicyHeader.decode([
        'no-referrer, same-origin',
      ]);
      expect(header, isA<ReferrerPolicySameOrigin>());
      expect(header?.encode(), equals(['same-origin']));
    });

    test('returns null for empty or unknown values', () {
      expect(ReferrerPolicyHeader.decode(['unknown-policy']), isNull);
      expect(ReferrerPolicyHeader.decode([]), isNull);
    });
  });
}
