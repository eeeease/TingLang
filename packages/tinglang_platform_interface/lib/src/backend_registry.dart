import 'package:meta/meta.dart';

import 'availability.dart';
import 'platform_probe.dart';

/// Static description of one backend: where it runs and what it needs.
/// Shared by real implementations and fakes so tests exercise real gates.
@immutable
final class BackendSpec {
  const BackendSpec({
    required this.id,
    required this.platforms,
    this.minVersions = const {},
    this.permissions = const {},
    this.assets = const {},
    this.cloud = false,
  });

  /// Stable id persisted in user settings, e.g. `coreaudio_tap`.
  final String id;
  final Set<HostOs> platforms;

  /// Minimum OS version per platform; absent means any version.
  final Map<HostOs, OsVersion> minVersions;
  final Set<PermissionKind> permissions;

  /// Model packs that must be downloaded first.
  final Set<String> assets;

  /// Sends user audio/text off the device. Requires explicit opt-in, is never
  /// auto-selected, and must be labelled in the UI.
  final bool cloud;

  /// Evaluates the static requirements against [probe], most fundamental
  /// first: platform, OS version, opt-in, permissions, downloads.
  Availability evaluate(PlatformProbe probe) {
    if (!platforms.contains(probe.os)) {
      return Unsupported('$id is not available on ${probe.os.name}');
    }
    final minimum = minVersions[probe.os];
    if (minimum != null && !probe.isAtLeast(minimum)) {
      return Unsupported('$id requires ${probe.os.name} $minimum or later');
    }
    if (cloud && !probe.enabledCloudBackends.contains(id)) {
      return NeedsOptIn(id);
    }
    for (final permission in permissions) {
      switch (probe.permission(permission)) {
        case PermissionState.granted:
          continue;
        case PermissionState.denied || PermissionState.restricted:
          return NeedsPermission(permission, denied: true);
        case PermissionState.notDetermined:
          return NeedsPermission(permission);
      }
    }
    for (final asset in assets) {
      if (!probe.installedAssets.contains(asset)) return NeedsDownload(asset);
    }
    return const Available();
  }
}

/// A [BackendSpec] plus a lazy constructor. Nothing native is created until
/// the registry has picked this backend and the caller calls [create].
final class BackendFactory<T extends Object> {
  BackendFactory(this.spec, this._create, {this.check});

  final BackendSpec spec;
  final T Function() _create;

  /// Extra runtime gate evaluated after the spec's requirements pass, e.g.
  /// "SpeechTranscriber supports this locale".
  final Availability Function(PlatformProbe probe)? check;

  String get id => spec.id;

  Availability availability(PlatformProbe probe) {
    final base = spec.evaluate(probe);
    if (base is! Available) return base;
    return check?.call(probe) ?? base;
  }

  T create() => _create();
}

/// One considered backend and why it was or was not usable.
@immutable
final class BackendCandidate<T extends Object> {
  const BackendCandidate(this.factory, this.availability);
  final BackendFactory<T> factory;
  final Availability availability;

  @override
  String toString() => '${factory.id}: $availability';
}

/// The result of [BackendRegistry.pick].
@immutable
final class BackendChoice<T extends Object> {
  const BackendChoice({
    required this.capability,
    required this.selected,
    required this.candidates,
    this.preferredId,
    this.preferredAvailability,
  });

  final String capability;
  final BackendFactory<T>? selected;

  /// Every backend registered for the host OS, in preference order.
  final List<BackendCandidate<T>> candidates;
  final String? preferredId;

  /// Why the user's preferred backend was not used (null when it was used or
  /// no preference was given). UI shows this instead of silently switching.
  final Availability? preferredAvailability;

  bool get hasSelection => selected != null;
  String? get id => selected?.id;
  bool get usedPreference => preferredId != null && preferredId == id;

  /// The most actionable reason nothing was selected: the first candidate
  /// that is blocked on something the user can fix (permission, download,
  /// opt-in), else the first unsupported reason.
  Availability? get blocker {
    if (hasSelection) return null;
    for (final candidate in candidates) {
      if (candidate.availability is! Unsupported) return candidate.availability;
    }
    return candidates.isEmpty
        ? Unsupported('no $capability backend registered')
        : candidates.first.availability;
  }

  T create() {
    final factory = selected;
    if (factory == null) {
      throw StateError('No usable $capability backend: $blocker');
    }
    return factory.create();
  }

  @override
  String toString() =>
      'BackendChoice($capability → ${id ?? 'none'}; '
      '${candidates.join(', ')})';
}

/// Factory registry for one capability (system audio, live ASR, …).
///
/// [preferences] is the platform's default order. An entry ending in `*` is
/// a prefix wildcard (`sherpa.*`) matching backends in registration order.
/// Backends supporting the OS but not named in the order come last.
final class BackendRegistry<T extends Object> {
  BackendRegistry(this.capability, {Map<HostOs, List<String>>? preferences})
    : preferences = Map.unmodifiable(preferences ?? const {});

  final String capability;
  final Map<HostOs, List<String>> preferences;
  final List<BackendFactory<T>> _factories = [];

  List<BackendFactory<T>> get all => List.unmodifiable(_factories);

  /// Registers [factory]; a later registration with the same id replaces the
  /// earlier one in place (e.g. a native backend replacing a stub).
  void register(BackendFactory<T> factory) {
    final index = _factories.indexWhere((f) => f.id == factory.id);
    if (index < 0) {
      _factories.add(factory);
    } else {
      _factories[index] = factory;
    }
  }

  BackendFactory<T>? byId(String id) {
    for (final factory in _factories) {
      if (factory.id == id) return factory;
    }
    return null;
  }

  /// Backends that can run on [os], in preference order.
  List<BackendFactory<T>> ordered(HostOs os) {
    final supported = _factories.where((f) => f.spec.platforms.contains(os)).toList();
    final result = <BackendFactory<T>>[];
    for (final entry in preferences[os] ?? const <String>[]) {
      final wildcard = entry.endsWith('*');
      final prefix = wildcard ? entry.substring(0, entry.length - 1) : entry;
      for (final factory in supported) {
        final matches = wildcard ? factory.id.startsWith(prefix) : factory.id == entry;
        if (matches && !result.contains(factory)) result.add(factory);
      }
    }
    for (final factory in supported) {
      if (!result.contains(factory)) result.add(factory);
    }
    return result;
  }

  /// Picks the backend to use.
  ///
  /// 1. The user's preferred backend, if it is registered and [Available]
  ///    (this is the only way a cloud backend is ever chosen).
  /// 2. Otherwise the first [Available] local backend in platform order.
  /// 3. Otherwise nothing; [BackendChoice.blocker] says what to fix.
  BackendChoice<T> pick(PlatformProbe probe, [String? userPreferredId]) {
    final candidates = [
      for (final factory in ordered(probe.os))
        BackendCandidate(factory, factory.availability(probe)),
    ];
    Availability? preferredAvailability;
    if (userPreferredId != null) {
      final preferred = byId(userPreferredId);
      final availability =
          preferred?.availability(probe) ??
          Unsupported('unknown $capability backend $userPreferredId');
      if (preferred != null && availability is Available) {
        return BackendChoice(
          capability: capability,
          selected: preferred,
          candidates: candidates,
          preferredId: userPreferredId,
        );
      }
      preferredAvailability = availability;
    }
    for (final candidate in candidates) {
      if (candidate.factory.spec.cloud) continue;
      if (candidate.availability is Available) {
        return BackendChoice(
          capability: capability,
          selected: candidate.factory,
          candidates: candidates,
          preferredId: userPreferredId,
          preferredAvailability: preferredAvailability,
        );
      }
    }
    return BackendChoice(
      capability: capability,
      selected: null,
      candidates: candidates,
      preferredId: userPreferredId,
      preferredAvailability: preferredAvailability,
    );
  }
}

/// The capture backend [registry] would use with [probe]. A permission that
/// was never asked for does not stop a backend: macOS asks when capture
/// opens, and for system audio it cannot be asked about beforehand at all.
/// Only a refusal does ([CapturePermissionDenied]).
BackendFactory<T> pickCapture<T extends Object>(BackendRegistry<T> registry, PlatformProbe probe) {
  final choice = registry.pick(probe);
  if (choice.selected case final selected?) return selected;
  NeedsPermission? refused;
  for (final candidate in choice.candidates) {
    final availability = candidate.availability;
    if (availability is! NeedsPermission) continue;
    if (!availability.denied) return candidate.factory;
    refused ??= availability;
  }
  if (refused != null) throw CapturePermissionDenied(refused.permission);
  throw StateError('No usable ${registry.capability} backend: ${choice.blocker}');
}
