import 'package:http_sse/http_sse.dart';

void main() async {
  // Encoding SSE events
  final events = Stream.fromIterable([
    const SseEvent.text('Hello World', event: 'greeting'),
    const SseEvent.json({'user': 'Alice'}, id: '1'),
  ]);

  final bytes = events.transform(const SseEncoder());

  // Decoding SSE stream
  final decoded = await bytes.transform(const SseDecoder()).toList();
  print(decoded);
}
