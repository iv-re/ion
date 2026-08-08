import 'dart:async';

import 'package:ion_test/src/ion_test_client.dart';
import 'package:ion_test/src/response_comparator.dart';
import 'package:ion_web/ion_web.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart' as test;

/// Creates a new `ion`-specific test case with the given [description].
///
/// [ionTest] will handle executing requests against the handler returned
/// by [build] and asserting that the resulting [Response] matches the expected
/// response returned by [expect].
///
/// ```dart
/// ionTest(
///   'GET /users/1 returns user DTO',
///   build: () => app,
///   act: (client) => client.get('/users/1'),
///   expect: () => Json(UserDto(id: 1, name: 'Alice')),
/// );
/// ```
@isTest
void ionTest(
  String description, {
  required Handler Function() build,
  required FutureOr<Response> Function(IonTestClient client) act,
  FutureOr<void> Function()? setUp,
  Duration? wait,
  dynamic Function()? expect,
  dynamic Function(Handler target, Response response)? verify,
  dynamic Function()? errors,
  FutureOr<void> Function()? tearDown,
  dynamic tags,
  List<ResponseComparator>? comparators,
}) {
  test.test(
    description,
    () async {
      final unhandledErrors = <Object>[];

      try {
        await _runZonedGuarded(() async {
          await setUp?.call();
          final target = build();
          final client = IonTestClient(target);

          Response? actualResponse;
          try {
            actualResponse = await act(client);
          } catch (error) {
            if (errors == null) rethrow;
            unhandledErrors.add(error);
          }

          if (wait != null) await Future<void>.delayed(wait);

          if (expect != null && actualResponse != null) {
            final dynamic expected = await expect();

            if (expected is Response) {
              await _assertResponseEquals(
                actualResponse,
                expected,
                comparators: comparators,
              );
            } else {
              test.expect(actualResponse, test.wrapMatcher(expected));
            }
          }

          if (actualResponse != null) {
            await verify?.call(target, actualResponse);
          }
          await tearDown?.call();
        });
      } catch (error) {
        if (errors == null || !unhandledErrors.contains(error)) {
          rethrow;
        }
      }

      if (errors != null) {
        test.expect(
          unhandledErrors.length == 1 ? unhandledErrors.first : unhandledErrors,
          test.wrapMatcher(errors()),
        );
      }
    },
    tags: tags,
  );
}

/// Compares actual and expected [Response] objects with rich error diffs.
Future<void> _assertResponseEquals(
  Response actual,
  Response expected, {
  List<ResponseComparator>? comparators,
}) async {
  // Status Code assertion
  if (actual.status != expected.status) {
    throw test.TestFailure(
      'Expected Status: ${expected.status.value} '
      '(${expected.status.reasonPhrase})\n'
      '  Actual Status: ${actual.status.value} '
      '(${actual.status.reasonPhrase})',
    );
  }

  // Header assertions (checks expected headers)
  for (final header in expected.headers) {
    final actualVal = actual.headers.get(header.name)?.value;
    if (actualVal == null || !actualVal.contains(header.value)) {
      throw test.TestFailure(
        'Header mismatch for "${header.name}":\n'
        '  Expected: ${header.value}\n'
        '  Actual:   $actualVal',
      );
    }
  }

  // Body assertion using active ResponseComparators
  final activeComparators = getResponseComparators(local: comparators);

  for (final comparator in activeComparators) {
    if (comparator.canCompare(actual, expected)) {
      await comparator.compare(actual, expected);
      return;
    }
  }
}

Future<void> _runZonedGuarded(Future<void> Function() body) {
  final completer = Completer<void>();
  runZonedGuarded(
    () async {
      await body();
      if (!completer.isCompleted) completer.complete();
    },
    (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    },
  );
  return completer.future;
}
