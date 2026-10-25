# tinglang_cloud_asr

Cloud speech recognition for Tinglang, for Macs that cannot run the local models (or users who prefer a service). Every service implements one interface, `CloudAsrProvider` (`lib/src/provider.dart`):

- `openStream` — live captions: 16 kHz mono 16-bit PCM in, partial and final `CloudSegment`s out;
- `transcribeFile` — one WAV (the caller splits files longer than `CloudAsrInfo.maxFileMs`);
- `verify` — "Test connection" with the cheapest call the service has;
- `hosts` — where audio goes, for the consent line in Settings.

The app never talks to a service directly: `tinglang_native` wraps each provider as the `cloud.<id>` live and file backends (worker isolates; PCM never crosses the root isolate), and the backend registry only uses one the user has chosen and enabled. Keys are the user's own (BYOK) and stay in the platform secret store.

Pure Dart (`dart:io`, `crypto`). No `HttpClient` or socket exists before a call. Errors are `CloudAsrError` with a kind the app maps to a message; they never contain credentials.

Each service's endpoints, authentication, limits and language mapping, with links to the official documentation and what the tests cover, are in `doc/<id>.md`. Tests talk only to a loopback server (`test/support/fake_server.dart`); they check the documented protocol and signatures, not the live services.

```bash
fvm dart test
```
