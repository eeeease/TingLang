import 'package:meta/meta.dart';

/// One recording in Apple Voice Memos: recorded on this Mac, or on an
/// iPhone and synced through iCloud.
@immutable
final class VoiceMemo {
  const VoiceMemo({
    required this.id,
    required this.title,
    required this.recordedAt,
    required this.duration,
    required this.path,
  });

  /// Stable across listings; the app stores it to avoid importing twice.
  final String id;

  /// The title shown in Voice Memos (empty when it has none).
  final String title;

  /// When recording started, in UTC.
  final DateTime recordedAt;
  final Duration duration;

  /// Absolute path of the audio (`.m4a` or `.qta`) inside the library. Read
  /// it, never write it: the app copies recordings on import.
  final String path;

  @override
  bool operator ==(Object other) =>
      other is VoiceMemo &&
      other.id == id &&
      other.title == title &&
      other.recordedAt == recordedAt &&
      other.duration == duration &&
      other.path == path;

  @override
  int get hashCode => Object.hash(id, title, recordedAt, duration, path);

  @override
  String toString() => 'VoiceMemo($id, $title, $recordedAt)';
}

enum VoiceMemoProblem {
  /// macOS protects the library; the app needs Full Disk Access. There is no
  /// API to ask ahead of time, so this shows up when listing.
  needsFullDiskAccess,

  /// No Voice Memos library on this computer (never opened, or iCloud sync
  /// for Voice Memos is off).
  noLibrary,

  /// The library is there but its index could not be read (a format this
  /// version does not know).
  unreadable,
}

final class VoiceMemoFailure implements Exception {
  const VoiceMemoFailure(this.problem, [this.detail]);
  final VoiceMemoProblem problem;
  final String? detail;

  @override
  String toString() => 'Voice Memos: ${problem.name}${detail == null ? '' : ' ($detail)'}';
}

/// Read-only access to the user's Voice Memos library.
abstract interface class VoiceMemoLibrary {
  /// Recordings whose audio is on this computer, newest first. Recordings
  /// that live only in iCloud or were recently deleted are left out.
  /// Throws [VoiceMemoFailure].
  Future<List<VoiceMemo>> list();
}
