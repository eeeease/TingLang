import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

import 'shared/shared_backends.dart';

abstract final class TinglangNative {
  /// Builds the platform with shared Dart backends plus the OS provider's
  /// native ones and assigns [TinglangPlatform.instance]. Safe to call again
  /// (e.g. in tests): the newest instance wins.
  static TinglangPlatform install({NativeBackendProvider? provider}) {
    final native = provider ?? NativeBackendProvider.current ?? DartIoProvider();
    final platform = TinglangPlatform(probeSource: native);
    registerSharedBackends(platform);
    // Native registrations come last so they replace shared stubs by id.
    native.registerBackends(platform);
    TinglangPlatform.instance = platform;
    return platform;
  }
}

/// Fallback when no native plugin registered itself (unit tests, Linux):
/// probes with dart:io only and registers nothing.
final class DartIoProvider extends NativeBackendProvider {
  @override
  String get name => 'dart-io';

  @override
  Future<PlatformProbe> probe() async => PlatformProbe(
    os: switch (Platform.operatingSystem) {
      'macos' => HostOs.macos,
      'windows' => HostOs.windows,
      'linux' => HostOs.linux,
      _ => HostOs.other,
    },
    version: _version(Platform.operatingSystemVersion),
    arch: switch (Abi.current()) {
      Abi.macosArm64 || Abi.windowsArm64 || Abi.linuxArm64 => CpuArch.arm64,
      Abi.macosX64 || Abi.windowsX64 || Abi.linuxX64 => CpuArch.x64,
      _ => CpuArch.other,
    },
  );

  @override
  void registerBackends(TinglangPlatform platform) {}

  static OsVersion _version(String text) {
    try {
      // macOS: "Version 26.0.1 (Build 25A354)"; Windows: "\"Windows 10 Pro\" 10.0 (Build 19045)".
      final build = RegExp(r'Build (\d+)\)').firstMatch(text)?.group(1);
      final base = OsVersion.parse(text.replaceFirst(RegExp(r'^"[^"]*"\s*'), ''));
      return Platform.isWindows && build != null
          ? OsVersion(base.major, base.minor, int.parse(build))
          : base;
    } on FormatException {
      return const OsVersion(0);
    }
  }
}
