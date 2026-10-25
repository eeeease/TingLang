import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang_native_macos/tinglang_native_macos.dart';
import 'package:tinglang_native_macos/src/host_api.g.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

void main() {
  test('host probe maps version, arch and permissions', () {
    final probe = probeFromHost(
      HostProbe(
        osMajor: 26,
        osMinor: 0,
        osPatch: 1,
        osVersionString: 'Version 26.0.1',
        arch: 'arm64',
        microphone: PermissionStatus.denied,
        screenCapture: PermissionStatus.notDetermined,
        speechLocales: ['en-US', 'zh-CN'],
      ),
    );
    expect(probe.os, HostOs.macos);
    expect(probe.version, const OsVersion(26, 0, 1));
    expect(probe.arch, CpuArch.arm64);
    expect(probe.hasNeuralEngine, isTrue);
    expect(probe.speechLocales, {'en-US', 'zh-CN'});
    expect(probe.permission(PermissionKind.microphone), PermissionState.denied);
    expect(probe.permission(PermissionKind.systemAudio), PermissionState.notDetermined);
  });
}
