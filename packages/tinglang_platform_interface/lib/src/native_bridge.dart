import 'platform_probe.dart';
import 'tinglang_platform.dart';

/// Implemented once per OS by `tinglang_native_macos` / `_windows`.
///
/// Each implementation's Flutter `dartPluginClass.registerWith()` assigns
/// [current] before `main` runs; `TinglangNative.install()` then asks it for
/// the probe and to register its native backends.
abstract class NativeBackendProvider implements PlatformProbeSource {
  static NativeBackendProvider? current;

  /// Short name for diagnostics, e.g. `macos-swift`.
  String get name;

  /// Adds this OS's native backends to [platform]'s registries.
  void registerBackends(TinglangPlatform platform);
}
