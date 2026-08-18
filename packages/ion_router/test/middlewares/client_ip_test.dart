import 'dart:io';
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:ion_router/ion_router.dart';
import 'package:ion_web/ion_web.dart';
import 'package:ion_web/src/http/connection.dart';
import 'package:test/scaffolding.dart';

Future<InternetAddress?> _run(
  Middleware middleware, {
  Map<String, String>? headers,
  List<MapEntry<String, String>>? multiHeaders,
  InternetAddress? remoteAddress,
}) async {
  InternetAddress? capturedIp;
  final app = IonRouter()
    ..use(middleware)
    ..get('/', (request) {
      capturedIp = request.ctx.clientIp;
      return Response.text('ok');
    });

  final slices = <HeaderEntrySlices>[];
  final token = SliceBufferToken();

  if (multiHeaders != null) {
    for (final entry in multiHeaders) {
      final keyBytes = Uint8List.fromList(entry.key.codeUnits);
      final valBytes = Uint8List.fromList(entry.value.codeUnits);
      slices.add(
        HeaderEntrySlices(
          HeaderByteSlice(keyBytes, 0, keyBytes.length, token),
          HeaderByteSlice(valBytes, 0, valBytes.length, token),
        ),
      );
    }
  } else if (headers != null) {
    for (final entry in headers.entries) {
      final keyBytes = Uint8List.fromList(entry.key.codeUnits);
      final valBytes = Uint8List.fromList(entry.value.codeUnits);
      slices.add(
        HeaderEntrySlices(
          HeaderByteSlice(keyBytes, 0, keyBytes.length, token),
          HeaderByteSlice(valBytes, 0, valBytes.length, token),
        ),
      );
    }
  }

  final request = Request(
    const Stream.empty(),
    method: HttpMethod.get,
    uri: Uri.parse('http://localhost/'),
    version: HttpVersion.http11,
    headers: TypedHeaders(slices),
    connectionInfo: remoteAddress != null
        ? ConnectionInfo(
            remoteAddress: remoteAddress,
            remotePort: 1234,
            localPort: 80,
          )
        : null,
  );

  await app(request);
  return capturedIp;
}

Future<InternetAddress?> _runChain(
  List<Middleware> middlewares, {
  Map<String, String>? headers,
  InternetAddress? remoteAddress,
}) async {
  InternetAddress? capturedIp;
  final app = IonRouter();
  middlewares.forEach(app.use);
  app.get('/', (request) {
    capturedIp = request.ctx.clientIp;
    return Response.text('ok');
  });

  final slices = <HeaderEntrySlices>[];
  final token = SliceBufferToken();

  if (headers != null) {
    for (final entry in headers.entries) {
      final keyBytes = Uint8List.fromList(entry.key.codeUnits);
      final valBytes = Uint8List.fromList(entry.value.codeUnits);
      slices.add(
        HeaderEntrySlices(
          HeaderByteSlice(keyBytes, 0, keyBytes.length, token),
          HeaderByteSlice(valBytes, 0, valBytes.length, token),
        ),
      );
    }
  }

  final request = Request(
    const Stream.empty(),
    method: HttpMethod.get,
    uri: Uri.parse('http://localhost/'),
    version: HttpVersion.http11,
    headers: TypedHeaders(slices),
    connectionInfo: remoteAddress != null
        ? ConnectionInfo(
            remoteAddress: remoteAddress,
            remotePort: 1234,
            localPort: 80,
          )
        : null,
  );

  await app(request);
  return capturedIp;
}

void main() {
  group('ClientIP Middleware - Header Source', () {
    test('header source extractions', () async {
      final cases = [
        ('empty', '', null),
        ('ipv4', '100.100.100.100', '100.100.100.100'),
        (
          'ipv6_canonical',
          '2345:425:2ca1::567:5673:23b5',
          '2345:425:2ca1::567:5673:23b5',
        ),
        (
          'ipv6_uncompressed_normalized',
          '2345:0425:2CA1:0000:0000:0567:5673:23B5',
          '2345:425:2ca1::567:5673:23b5',
        ),
        ('invalid', 'invalid', null),
        ('ipv4_with_port', '100.100.100.100:80', null),
        ('multiple_ips', '100.100.100.100,200.200.200.200', null),
        ('loopback_accepted', '127.0.0.1', '127.0.0.1'),
        ('private_v4_accepted', '10.0.1.10', '10.0.1.10'),
        ('private_v6_accepted', 'fc00::1', 'fc00::1'),
        ('unspecified_accepted', '0.0.0.0', '0.0.0.0'),
        ('v4_mapped_ipv6_folded_to_v4', '::ffff:1.2.3.4', '1.2.3.4'),
        ('ipv6_zone_stripped', '2001:db8::1%eth0', '2001:db8::1'),
      ];

      for (final testCase in cases) {
        final clientIp = await _run(
          Middlewares.clientIp(),
          headers: testCase.$2.isNotEmpty ? {'X-Real-IP': testCase.$2} : null,
        );
        if (testCase.$3 != null) {
          check(
            because: 'Test case: ${testCase.$1}',
            clientIp,
          ).equals(InternetAddress(testCase.$3!));
        } else {
          check(because: 'Test case: ${testCase.$1}', clientIp).isNull();
        }
      }
    });

    test('multi-value header: last value wins', () async {
      final cases = [
        (
          'single_value',
          [const MapEntry('X-Real-IP', '100.1.1.1')],
          '100.1.1.1',
        ),
        (
          'attacker_then_proxy',
          [
            const MapEntry('X-Real-IP', '6.6.6.6'),
            const MapEntry('X-Real-IP', '100.2.2.2'),
          ],
          '100.2.2.2',
        ),
        (
          'three_values_last_wins',
          [
            const MapEntry('X-Real-IP', '6.6.6.6'),
            const MapEntry('X-Real-IP', '5.5.5.5'),
            const MapEntry('X-Real-IP', '100.3.3.3'),
          ],
          '100.3.3.3',
        ),
        (
          'last_unparseable_no_fallback',
          [
            const MapEntry('X-Real-IP', '100.4.4.4'),
            const MapEntry('X-Real-IP', 'garbage'),
          ],
          null,
        ),
        (
          'last_empty_no_fallback',
          [
            const MapEntry('X-Real-IP', '100.5.5.5'),
            const MapEntry('X-Real-IP', ''),
          ],
          null,
        ),
      ];

      for (final testCase in cases) {
        final clientIp = await _run(
          Middlewares.clientIp(),
          multiHeaders: testCase.$2,
        );
        check(
          because: 'Test case: ${testCase.$1}',
          clientIp?.address,
        ).equals(testCase.$3);
      }
    });
  });

  group('ClientIP Middleware - XFF Source No Trusted Prefixes', () {
    test('xff no trusted prefixes', () async {
      final cases = [
        ('missing', <String>[], null),
        ('empty', [''], null),
        ('single', ['100.100.100.100'], '100.100.100.100'),
        ('comma_space', ['1.1.1.1, 2.2.2.2'], '2.2.2.2'),
        ('comma_no_space', ['1.1.1.1,2.2.2.2'], '2.2.2.2'),
        ('multi_header_merged', ['1.1.1.1', '2.2.2.2'], '2.2.2.2'),
        (
          'multi_header_with_commas',
          ['5.5.5.5, 6.6.6.6', '7.7.7.7, 4.4.4.4'],
          '4.4.4.4',
        ),
        ('ipv6', ['2001:db8::1'], '2001:db8::1'),
        (
          'mixed_v4_v6_rightmost_wins',
          ['203.0.113.1, 2001:db8::1'],
          '2001:db8::1',
        ),
        ('v4_mapped_rightmost_folded', ['::ffff:1.2.3.4'], '1.2.3.4'),
        ('zone_stripped_rightmost', ['2001:db8::1%eth0'], '2001:db8::1'),
        (
          'weird_with_empties_then_valid_rightmost',
          ['oh, hi,,127.0.0.1,,,,'],
          '127.0.0.1',
        ),
      ];

      for (final testCase in cases) {
        final multiHeaders = testCase.$2
            .map((v) => MapEntry('X-Forwarded-For', v))
            .toList();
        final clientIp = await _run(
          Middlewares.clientIp(source: ClientIpSource.xff()),
          multiHeaders: multiHeaders,
        );
        check(
          because: 'Test case: ${testCase.$1}',
          clientIp?.address,
        ).equals(testCase.$3);
      }
    });
  });

  group('ClientIP Middleware - XFF Source With Trusted Prefixes', () {
    test('xff with trusted prefixes', () async {
      final cases = [
        (
          'single_trusted_proxy_skipped',
          ['203.0.113.0/24'],
          ['100.100.100.100, 203.0.113.50'],
          '100.100.100.100',
        ),
        (
          'multiple_trusted_proxies_skipped',
          ['203.0.113.0/24', '198.51.100.0/24'],
          ['1.1.1.1, 203.0.113.10, 198.51.100.5'],
          '1.1.1.1',
        ),
        (
          'all_trusted_returns_null',
          ['203.0.113.0/24'],
          ['203.0.113.10, 203.0.113.20'],
          null,
        ),
        (
          'ipv6_trusted_range',
          ['2606:4700::/32'],
          ['2001:db8::1, 2606:4700::1'],
          '2001:db8::1',
        ),
        (
          'mixed_v4_v6_trust_list',
          ['2606:4700::/32', '203.0.113.0/24'],
          ['8.8.8.8, 2606:4700::1, 203.0.113.5'],
          '8.8.8.8',
        ),
        (
          'private_between_trusted_is_client',
          ['10.244.0.0/24'],
          ['10.244.1.50, 10.244.0.10'],
          '10.244.1.50',
        ),
        (
          'boundary_first_addr_in_prefix',
          ['203.0.113.0/24'],
          ['100.100.100.100, 203.0.113.0'],
          '100.100.100.100',
        ),
        (
          'boundary_last_addr_in_prefix',
          ['203.0.113.0/24'],
          ['100.100.100.100, 203.0.113.255'],
          '100.100.100.100',
        ),
        (
          'ip_just_outside_prefix_is_client',
          ['203.0.113.0/24'],
          ['203.0.114.1, 203.0.113.1'],
          '203.0.114.1',
        ),
      ];

      for (final testCase in cases) {
        final multiHeaders = testCase.$3
            .map((v) => MapEntry('X-Forwarded-For', v))
            .toList();
        final clientIp = await _run(
          Middlewares.clientIp(
            source: ClientIpSource.xff(trustedPrefixes: testCase.$2),
          ),
          multiHeaders: multiHeaders,
        );
        check(
          because: 'Test case: ${testCase.$1}',
          clientIp?.address,
        ).equals(testCase.$4);
      }
    });

    test('throws on bad prefix syntax', () {
      check(
        () => ClientIpSource.xff(trustedPrefixes: ['not-a-cidr']),
      ).throws<AssertionError>();
    });

    test('fail closed on unparseable mid-chain entry', () async {
      final cases = [
        (
          'garbage_rightmost_no_prefixes',
          <String>[],
          ['1.1.1.1, garbage'],
          null,
        ),
        (
          'garbage_between_client_and_trusted_proxy',
          ['10.0.0.0/8'],
          ['203.0.113.7, garbage, 10.0.0.1'],
          null,
        ),
        (
          'garbage_past_trusted_chain',
          ['10.0.0.0/8'],
          ['203.0.113.7, garbage, 10.0.0.1, 10.0.0.2'],
          null,
        ),
        (
          'garbage_in_unreachable_left_header',
          ['10.0.0.0/8'],
          ['garbage', '203.0.113.7, 10.0.0.1'],
          '203.0.113.7',
        ),
      ];

      for (final testCase in cases) {
        final multiHeaders = testCase.$3
            .map((v) => MapEntry('X-Forwarded-For', v))
            .toList();
        final clientIp = await _run(
          Middlewares.clientIp(
            source: ClientIpSource.xff(trustedPrefixes: testCase.$2),
          ),
          multiHeaders: multiHeaders,
        );
        check(
          because: 'Test case: ${testCase.$1}',
          clientIp?.address,
        ).equals(testCase.$4);
      }
    });

    test('v4-mapped IPv6 cannot bypass trusted v4 prefix', () async {
      final clientIp = await _run(
        Middlewares.clientIp(
          source: ClientIpSource.xff(trustedPrefixes: ['10.0.0.0/8']),
        ),
        headers: {'X-Forwarded-For': '::ffff:10.0.0.5, 10.0.0.1'},
      );
      check(clientIp).isNull();
    });

    test('zoned IPv6 cannot bypass trusted v6 prefix', () async {
      final clientIp = await _run(
        Middlewares.clientIp(
          source: ClientIpSource.xff(trustedPrefixes: ['2606:4700::/32']),
        ),
        headers: {'X-Forwarded-For': '2606:4700::1%attacker, 2606:4700::5'},
      );
      check(clientIp).isNull();
    });
  });

  group('ClientIP Middleware - XFF Trusted Proxies Count', () {
    test('xff trusted proxies count', () async {
      final cases = [
        (1, ['1.1.1.1, 2.2.2.2'], '2.2.2.2'),
        (2, ['1.1.1.1, 2.2.2.2, 3.3.3.3'], '2.2.2.2'),
        (3, ['1.1.1.1, 2.2.2.2, 3.3.3.3, 4.4.4.4'], '2.2.2.2'),
        (2, ['1.1.1.1, 2.2.2.2'], '1.1.1.1'),
        (3, ['1.1.1.1, 2.2.2.2'], null),
        (1, <String>[], null),
        (2, ['6.6.6.6, 1.1.1.1, 2.2.2.2, 3.3.3.3'], '2.2.2.2'),
        (2, ['garbage, 2.2.2.2'], null),
        (2, ['1.1.1.1', '2.2.2.2', '3.3.3.3'], '2.2.2.2'),
        (2, [',,, 3.3.3.3, 1.1.1.1, 2.2.2.2'], '1.1.1.1'),
        (1, ['::ffff:1.2.3.4'], '1.2.3.4'),
        (1, ['2001:db8::1%eth0'], '2001:db8::1'),
      ];

      for (final testCase in cases) {
        final multiHeaders = testCase.$2
            .map((v) => MapEntry('X-Forwarded-For', v))
            .toList();
        final clientIp = await _run(
          Middlewares.clientIp(
            source: ClientIpSource.xffTrustedProxies(testCase.$1),
          ),
          multiHeaders: multiHeaders,
        );
        check(
          because: 'Count=${testCase.$1}, headers=${testCase.$2}',
          clientIp?.address,
        ).equals(testCase.$3);
      }
    });

    test('throws on numTrustedProxies < 1', () {
      check(
        () => ClientIpSource.xffTrustedProxies(0),
      ).throws<AssertionError>();
    });
  });

  group('ClientIP Middleware - RemoteAddr Source', () {
    test('remote address extraction and unmapping', () async {
      final cases = [
        (InternetAddress('192.0.2.1'), '192.0.2.1'),
        (InternetAddress('2001:db8::1'), '2001:db8::1'),
        (InternetAddress('::ffff:1.2.3.4'), '1.2.3.4'),
      ];

      for (final testCase in cases) {
        final clientIp = await _run(
          Middlewares.clientIp(source: const ClientIpSource.remoteAddr()),
          remoteAddress: testCase.$1,
        );
        check(clientIp?.address).equals(testCase.$2);
      }
    });

    test('returns null when connectionInfo is null', () async {
      final clientIp = await _run(
        Middlewares.clientIp(source: const ClientIpSource.remoteAddr()),
      );
      check(clientIp).isNull();
    });
  });

  group('ClientIP Middleware - Last Write Wins', () {
    test('later middleware overrides earlier if valid IP found', () async {
      final clientIp = await _runChain(
        [
          Middlewares.clientIp(source: ClientIpSource.xff()),
          Middlewares.clientIp(
            source: const ClientIpSource.header(
              headerName: 'CF-Connecting-IP',
            ),
          ),
        ],
        headers: {
          'CF-Connecting-IP': '1.1.1.1',
          'X-Forwarded-For': '2.2.2.2',
        },
      );
      check(clientIp?.address).equals('1.1.1.1');
    });

    test('earlier value persists when later finds nothing', () async {
      final clientIp = await _runChain(
        [
          Middlewares.clientIp(source: ClientIpSource.xff()),
          Middlewares.clientIp(
            source: const ClientIpSource.header(
              headerName: 'CF-Connecting-IP',
            ),
          ),
        ],
        headers: {
          'X-Forwarded-For': '8.8.8.8',
        },
      );
      check(clientIp?.address).equals('8.8.8.8');
    });

    test('earlier persists when later xff finds all trusted', () async {
      final clientIp = await _runChain(
        [
          Middlewares.clientIp(source: const ClientIpSource.remoteAddr()),
          Middlewares.clientIp(
            source: ClientIpSource.xff(trustedPrefixes: ['10.0.0.0/8']),
          ),
        ],
        remoteAddress: InternetAddress('192.0.2.1'),
        headers: {
          'X-Forwarded-For': '10.0.0.1, 10.0.0.2',
        },
      );
      check(clientIp?.address).equals('192.0.2.1');
    });
  });

  group('Security Advisories (GHSA)', () {
    test('GHSA-3fxj-6jh8-hvhx: direct internet uses remoteAddr', () async {
      final clientIp = await _run(
        Middlewares.clientIp(source: const ClientIpSource.remoteAddr()),
        remoteAddress: InternetAddress('99.99.99.99'),
        headers: {'X-Forwarded-For': '1.2.3.4, 5.6.7.8'},
      );
      check(clientIp?.address).equals('99.99.99.99');
    });

    test('GHSA-3fxj-6jh8-hvhx: behind proxy uses xff', () async {
      final clientIp = await _run(
        Middlewares.clientIp(
          source: ClientIpSource.xff(trustedPrefixes: ['10.0.0.0/8']),
        ),
        headers: {'X-Forwarded-For': '1.2.3.4, 99.99.99.99'},
      );
      check(clientIp?.address).equals('99.99.99.99');
    });

    test(
      'GHSA-9g5q-2w5x-hmxf: rightmost untrusted selected from XFF',
      () async {
        final clientIp = await _run(
          Middlewares.clientIp(source: ClientIpSource.xff()),
          headers: {'X-Forwarded-For': '192.0.2.2, 192.0.2.1'},
        );
        check(clientIp?.address).equals('192.0.2.1');
      },
    );

    test('GHSA-rjr7-jggh-pgcp: xff loopback spoof rejected', () async {
      final clientIp = await _run(
        Middlewares.clientIp(
          source: ClientIpSource.xff(trustedPrefixes: ['10.0.0.0/8']),
        ),
        headers: {'X-Forwarded-For': '127.0.0.1, 99.99.99.99'},
      );
      check(clientIp?.address).equals('99.99.99.99');
    });

    test('GHSA-rjr7-jggh-pgcp: only opted-in header is read', () async {
      final clientIp = await _run(
        Middlewares.clientIp(),
        headers: {
          'True-Client-IP': '1.1.1.1',
          'X-Forwarded-For': '2.2.2.2',
          'X-Real-IP': '203.0.113.7',
        },
      );
      check(clientIp?.address).equals('203.0.113.7');
    });
  });
}
