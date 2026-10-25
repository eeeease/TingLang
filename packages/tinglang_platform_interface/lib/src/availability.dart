import 'platform_probe.dart';

/// Whether a backend can be used right now on this host, and if not, what the
/// user (or the app) must do first. UI renders each case differently.
sealed class Availability {
  const Availability();

  bool get isAvailable => this is Available;
}

final class Available extends Availability {
  const Available();

  @override
  String toString() => 'Available';
}

/// Usable after the user grants [permission] in System Settings.
final class NeedsPermission extends Availability {
  const NeedsPermission(this.permission, {this.denied = false});
  final PermissionKind permission;

  /// True when the user already declined: the app must link to Settings
  /// instead of triggering the system prompt again.
  final bool denied;

  @override
  String toString() => 'NeedsPermission(${permission.name}${denied ? ', denied' : ''})';
}

/// Usable after downloading [assetId] (a model pack). Downloads always ask
/// for consent first.
final class NeedsDownload extends Availability {
  const NeedsDownload(this.assetId, {this.bytes});
  final String assetId;
  final int? bytes;

  @override
  String toString() => 'NeedsDownload($assetId)';
}

/// A cloud backend the user has not explicitly enabled. Never auto-selected.
final class NeedsOptIn extends Availability {
  const NeedsOptIn(this.backendId);
  final String backendId;

  @override
  String toString() => 'NeedsOptIn($backendId)';
}

/// Cannot work on this host (wrong OS, OS too old, missing hardware…).
final class Unsupported extends Availability {
  const Unsupported(this.reason);
  final String reason;

  @override
  String toString() => 'Unsupported($reason)';
}
