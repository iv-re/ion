# stream_web_socket_channel

A pure Dart `WebSocketChannel` implementation operating over arbitrary byte stream channels (`StreamChannel<List<int>>`).

## Usage

```dart
import 'package:stream_channel/stream_channel.dart';
import 'package:stream_web_socket_channel/stream_web_socket_channel.dart';

void main() {
  // Wrap any byte StreamChannel (e.g. Socket, WebRTC, custom transport)
  final StreamChannel<List<int>> byteChannel = ...;

  final wsChannel = StreamWebSocketChannel(
    byteChannel,
    deflateOptions: const WebSocketDeflateOptions(),
  );

  // Use as standard WebSocketChannel
  wsChannel.stream.listen((message) {
    print('Received: $message');
    wsChannel.sink.add('echo: $message');
  });
}
```
