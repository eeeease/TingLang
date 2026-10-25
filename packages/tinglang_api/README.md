# tinglang_api

Pure Dart (no Flutter). The client side of the contract in `api/`: models with lenient reading and exact round trips, `TinglangApi` for the `/v1` endpoints, OAuth 2.1 sign-in with PKCE (`signIn`, `OAuthClient`, `AuthSession` with rotating refresh tokens), problem details mapped to `ProblemCode`, and `ServerUrl`, which only accepts https (or this machine during development).

Nothing here sends a request on its own: constructing a client is free, and the app decides when to call it (only after the user signs in or turns a cloud feature on). Transport is `dart:io` `HttpClient`, injectable for tests.

`tool/validate_api.dart` checks `api/` itself (OpenAPI 3.1 schema, JSON Schemas, examples); `test/` covers the checker, a round trip of every example, the client against a local HTTP server and the sign-in flow (RFC 7636 test vector included). Runs with `dart test` on Linux CI.
