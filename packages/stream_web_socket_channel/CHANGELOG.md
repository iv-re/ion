## 0.2.0

- **Breaking:** the channel closes the underlying sink once the close handshake
  completes, the peer goes away, or a protocol error occurs. If the peer does
  not answer `sink.close()`, the sink is closed after 5 seconds.
- Add backpressure. A paused `stream` pauses the input; with no listener,
  input pauses after 1 MiB of buffered messages. `sink.addStream` waits for an
  `IOSink` (such as a `Socket`) to drain.

## 0.1.0

- Initial release.
