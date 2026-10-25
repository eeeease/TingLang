# tinglang_native

App-facing package. `TinglangNative.install()` builds `TinglangPlatform.instance`
from the OS provider endorsed below (`tinglang_native_macos`,
`tinglang_native_windows`) plus backends implemented once in Dart
(`lib/src/shared/`: sherpa-onnx worker isolate, model downloader, cloud
adapters). In M1 the shared implementations are stubs and are not registered.
