import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

/// Windows provider. M1 probes with dart:io and registers no native
/// backends; the C++ plugin is a skeleton until M8.
final class TinglangNativeWindows extends NativeBackendProvider {
  /// Called by Flutter's generated plugin registrant before `main`.
  static void registerWith() {
    NativeBackendProvider.current = TinglangNativeWindows();
  }

  @override
  String get name => 'windows-skeleton';

  @override
  Future<PlatformProbe> probe() async => PlatformProbe(
    os: HostOs.windows,
    version: parseWindowsVersion(Platform.operatingSystemVersion),
    arch: Abi.current() == Abi.windowsArm64 ? CpuArch.arm64 : CpuArch.x64,
  );

  @override
  void registerBackends(TinglangPlatform platform) {}
}

/// `"Windows 10 Pro" 10.0 (Build 19045)` → 10.0.19045.
OsVersion parseWindowsVersion(String text) {
  final base = OsVersion.parse(text.replaceFirst(RegExp(r'^"[^"]*"\s*'), ''));
  final build = RegExp(r'Build (\d+)').firstMatch(text)?.group(1);
  return build == null ? base : OsVersion(base.major, base.minor, int.parse(build));
}
