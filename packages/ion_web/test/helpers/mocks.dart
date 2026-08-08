import 'dart:convert';
import 'dart:io';

import 'package:ctx/ctx.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sl/sl.dart';

export 'package:mocktail/mocktail.dart';

/// Mock log handler for test assertions.
class MockLogHandler extends Mock implements LogHandler {}

/// Fake context object for mocktail fallback.
class FakeContext extends Fake implements Context {}

/// Mock socket object for test assertions.
class MockSocket extends Mock implements Socket {}

/// Helper to get all captured calls to [MockSocket.add].
List<List<int>> getCapturedSocketCalls(MockSocket socket) {
  final captured = verify(() => socket.add(captureAny())).captured;
  return captured.cast<List<int>>();
}

/// Helper to get single or concatenated captured string sent to
/// [MockSocket.add].
String getCapturedSocketString(MockSocket socket, {int? index}) {
  final calls = getCapturedSocketCalls(socket);
  if (index != null) {
    return utf8.decode(calls[index]);
  }
  return calls.map(utf8.decode).join();
}

/// Registers standard mocktail fallback values required across test suites.
void registerTestFallbacks() {
  registerFallbackValue(FakeContext());
  registerFallbackValue(
    LogRecord(
      level: .info,
      message: '',
      time: .now(),
      attrs: const [],
    ),
  );
  registerFallbackValue(LogLevel.debug);
}
