## 0.2.0

- **Breaking:** `Response.withHeaders` replaces headers of the same name,
  including `Set-Cookie`. Use the new `withAppendedHeaders` to add one.
- **Breaking:** response headers are written as given; duplicates are no longer
  collapsed. Use `List<TypedHeader>.replacing` to override defaults.
- **Breaking:** custom `ResolvableResponse` subclasses implement
  `copyWithHeaders` instead of `withHeaders`.
- **Breaking:** `Content-Length`, `Transfer-Encoding` and `Connection` set by the
  handler are ignored; framing comes from the body. `Connection: close` still
  closes the connection.
- **Breaking:** `multipart()` and `multipartStream()` pass request body errors
  through instead of wrapping them in `MultipartException`.
- **Breaking:** the default WebSocket origin check requires the `Origin` and
  `Host` ports to match.
- Fix a response being sent to another client when the socket was slow to drain.
- Fix request bodies over 256 KB being truncated when read after an `await`.
- Fix the connection closing after a keep-alive response to a request whose body
  was not read. Unread or abandoned bodies are drained up to 256 KB; past that
  the response gets `Connection: close`.
- Fix `GET //a/b` being routed as `/b`.
- Fix a 500 being written into the body when a response stream fails, and stream
  bodies not matching `contentLength`; both now abort the connection.
- Fix `Content-Length` on 1xx, 204 and 304 responses, and chunked bodies sent to
  HTTP/1.0 clients.
- Fix the process staying alive after `IonServer.close()`, and `close()` not
  interrupting `shutdown()`.
- Fix multipart parts over 64 KB failing when received in one chunk.
- Fix finished WebSocket sessions never releasing the connection: it stayed
  counted in `maxConnections` and `shutdown()` waited forever.
- `shutdown()` no longer waits for or closes upgraded (WebSocket) connections,
  as in Go; `close()` still destroys them.
- Add multipart backpressure; spooled uploads wait for the disk.
- Add WebSocket backpressure: a paused `channel.stream` stops reading the socket.
- Document that the TLS handshake cannot be timed out; terminate TLS in a proxy.
- Respond 414 or 431 to oversized request heads instead of 400; reject methods
  that are not tokens; ignore empty lines before the request-line.
- Close WebSocket connections with 1011 when the handler throws, and log the
  error.
- Keep `Content-Location` and `Expires` on 304 responses.
- Allocate the request head buffer on demand instead of 64 KB per connection.

## 0.1.2

- Add error handling to `Response.sse`.

## 0.1.1

- Preserve `ResolvableResponse` type when calling `withHeaders`.

## 0.1.0

- Initial version.
