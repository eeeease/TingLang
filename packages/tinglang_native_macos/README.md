# tinglang_native_macos

Swift Flutter plugin (Swift Package Manager, CocoaPods fallback) implementing
Tinglang's macOS backends behind Pigeon host APIs.

M1: `TinglangHostApi.probe()` returns OS version, process architecture and
microphone / screen-capture permission state. PCM never travels over Pigeon:
from M2 the Core Audio tap writes into a native ring buffer that the ASR worker
isolate reads via FFI.

Regenerate Pigeon code after editing `pigeons/host_api.dart`:

```bash
cd packages/tinglang_native_macos && fvm dart run pigeon --input pigeons/host_api.dart
```
