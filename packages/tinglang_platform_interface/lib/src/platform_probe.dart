import 'package:meta/meta.dart';

/// Host operating system family.
enum HostOs { macos, windows, linux, other }

/// CPU architecture of the running process.
enum CpuArch { arm64, x64, other }

/// A dotted OS version. Windows uses `10.0.<build>` (Windows 11 24H2 is
/// `10.0.26100`), so comparisons always include the third component.
@immutable
final class OsVersion implements Comparable<OsVersion> {
  const OsVersion(this.major, [this.minor = 0, this.patch = 0]);

  /// Parses `14`, `14.2`, `26.0.1` or `10.0.19041`; extra components and
  /// suffixes such as ` (Build 23C64)` are ignored.
  factory OsVersion.parse(String text) {
    final match = RegExp(r'(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(text);
    if (match == null) throw FormatException('Not an OS version: $text');
    int part(int group) => int.parse(match.group(group) ?? '0');
    return OsVersion(part(1), part(2), part(3));
  }

  final int major, minor, patch;

  bool operator >=(OsVersion other) => compareTo(other) >= 0;
  bool operator <(OsVersion other) => compareTo(other) < 0;

  @override
  int compareTo(OsVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  bool operator ==(Object other) => other is OsVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// Runtime permissions a backend may need before it can be used.
enum PermissionKind {
  /// macOS "System Audio Recording Only" (Core Audio tap) or Screen
  /// Recording (ScreenCaptureKit fallback).
  systemAudio,
  microphone,
  screenCapture,
}

enum PermissionState { granted, denied, notDetermined, restricted }

/// A source/target language pair such as `en→zh-Hans`.
@immutable
final class LanguagePair {
  const LanguagePair(this.source, this.target);
  final String source, target;

  @override
  bool operator ==(Object other) =>
      other is LanguagePair && other.source == source && other.target == target;

  @override
  int get hashCode => Object.hash(source, target);

  @override
  String toString() => '$source→$target';
}

/// A snapshot of what the host can do. Taken by the native side (Pigeon on
/// macOS) or synthesised in tests; re-probe after permission changes.
@immutable
final class PlatformProbe {
  const PlatformProbe({
    required this.os,
    required this.version,
    required this.arch,
    this.hasNeuralEngine = false,
    this.speechLocales = const {},
    this.translationPairs = const {},
    this.permissions = const {},
    this.installedAssets = const {},
    this.enabledCloudBackends = const {},
  });

  final HostOs os;
  final OsVersion version;
  final CpuArch arch;
  final bool hasNeuralEngine;

  /// Locales supported by the OS speech recogniser (e.g. SpeechTranscriber).
  final Set<String> speechLocales;

  /// Language pairs the OS translator has installed.
  final Set<LanguagePair> translationPairs;

  /// Known permission states; a missing entry means not yet determined.
  final Map<PermissionKind, PermissionState> permissions;

  /// Downloaded model packs / assets by id.
  final Set<String> installedAssets;

  /// Cloud backends the user has explicitly enabled (and been shown the
  /// privacy label for). Cloud backends are never usable otherwise.
  final Set<String> enabledCloudBackends;

  PermissionState permission(PermissionKind kind) =>
      permissions[kind] ?? PermissionState.notDetermined;

  bool isAtLeast(OsVersion minimum) => version >= minimum;

  PlatformProbe copyWith({
    Map<PermissionKind, PermissionState>? permissions,
    Set<String>? installedAssets,
    Set<String>? enabledCloudBackends,
    Set<LanguagePair>? translationPairs,
  }) => PlatformProbe(
    os: os,
    version: version,
    arch: arch,
    hasNeuralEngine: hasNeuralEngine,
    speechLocales: speechLocales,
    translationPairs: translationPairs ?? this.translationPairs,
    permissions: permissions ?? this.permissions,
    installedAssets: installedAssets ?? this.installedAssets,
    enabledCloudBackends: enabledCloudBackends ?? this.enabledCloudBackends,
  );

  @override
  String toString() => 'PlatformProbe(${os.name} $version ${arch.name})';
}

/// Produces a fresh [PlatformProbe]; implemented natively per OS.
abstract interface class PlatformProbeSource {
  Future<PlatformProbe> probe();
}
