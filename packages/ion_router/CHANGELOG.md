## 0.2.0

- **Breaking:** require `ion_web` `^0.2.0`.
- Fix `bodyLimit` for bodies without `Content-Length`: reading them with `cast`
  (as `json()` does) ignored the limit, and `drain()` hung.
- Fix CORS replacing the handler's `Vary` header; `Vary` is now appended.

## 0.1.1

- Removed unused `ion_extra` dependency.

## 0.1.0

- Initial version.
