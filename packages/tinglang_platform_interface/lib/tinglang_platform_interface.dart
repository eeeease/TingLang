/// Capability interfaces, backend selection and probes for Tinglang.
///
/// Pure Dart: no Flutter, no dart:ffi, no I/O. Fakes live in
/// `package:tinglang_platform_interface/testing.dart`.
library;

export 'src/availability.dart';
export 'src/backend_registry.dart';
export 'src/capabilities/audio_capture.dart';
export 'src/capabilities/cloud_drive.dart';
export 'src/capabilities/live_pipeline.dart';
export 'src/capabilities/media.dart';
export 'src/capabilities/services.dart';
export 'src/capabilities/streaming_asr.dart';
export 'src/capabilities/voice_memos.dart';
export 'src/catalog.dart';
export 'src/native_bridge.dart';
export 'src/platform_probe.dart';
export 'src/speech_models.dart';
export 'src/tinglang_platform.dart';
