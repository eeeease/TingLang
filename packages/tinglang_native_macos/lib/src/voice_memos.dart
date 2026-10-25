import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart';

/// Reads Apple's Voice Memos index (`CloudRecordings.db`, a Core Data store)
/// from a private copy, so the live library is never locked or written.
final class MacVoiceMemoLibrary implements VoiceMemoLibrary {
  MacVoiceMemoLibrary({String? home}) : _home = home ?? Platform.environment['HOME'] ?? '';

  final String _home;

  /// Where the library lives, newest macOS first (macOS 11 and earlier used
  /// Application Support).
  static const recordingFolders = [
    'Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings',
    'Library/Application Support/com.apple.voicememos/Recordings',
  ];

  static const _index = 'CloudRecordings.db';
  static const _extensions = {'.m4a', '.qta'};

  /// Core Data dates are seconds since 2001-01-01 UTC.
  static const _coreDataEpochSeconds = 978307200;

  @override
  Future<List<VoiceMemo>> list() async {
    for (final relative in recordingFolders) {
      final folder = Directory(p.join(_home, relative));
      if (!await folder.exists()) continue;
      final temp = await Directory.systemTemp.createTemp('tinglang-voice-memos-');
      try {
        final copy = p.join(temp.path, _index);
        try {
          await File(p.join(folder.path, _index)).copy(copy);
        } on FileSystemException catch (e) {
          // Privacy protection refuses to open anything inside the folder.
          if (_denied(e)) throw const VoiceMemoFailure(VoiceMemoProblem.needsFullDiskAccess);
          if (e.osError?.errorCode == 2) continue;
          throw VoiceMemoFailure(VoiceMemoProblem.unreadable, e.message);
        }
        // Recent changes may still be in the write-ahead log.
        for (final suffix in const ['-wal', '-shm']) {
          final side = File(p.join(folder.path, '$_index$suffix'));
          try {
            if (await side.exists()) await side.copy('$copy$suffix');
          } on FileSystemException {
            // Without the log the copy is slightly older; still consistent.
          }
        }
        return readIndex(copy, folder.path);
      } finally {
        await temp.delete(recursive: true);
      }
    }
    throw const VoiceMemoFailure(VoiceMemoProblem.noLibrary);
  }

  static bool _denied(FileSystemException e) => const {1, 13}.contains(e.osError?.errorCode);

  /// Recordings listed in the index at [indexPath] whose audio is inside
  /// [folder], newest first. Only `.m4a`/`.qta` files that exist count; names
  /// that point outside [folder] are ignored.
  static List<VoiceMemo> readIndex(String indexPath, String folder) {
    final Database db;
    try {
      db = sqlite3.open(indexPath);
    } on SqliteException catch (e) {
      throw VoiceMemoFailure(VoiceMemoProblem.unreadable, e.message);
    }
    try {
      final columns = {
        for (final row in db.select('PRAGMA table_info(ZCLOUDRECORDING)')) row['name'] as String,
      };
      if (!columns.containsAll(const {'Z_PK', 'ZPATH', 'ZDATE'})) {
        throw const VoiceMemoFailure(VoiceMemoProblem.unreadable, 'unknown index format');
      }
      // Optional columns differ between macOS versions.
      String optional(String name) => columns.contains(name) ? name : 'NULL';
      final rows = db.select(
        'SELECT Z_PK AS pk, ZPATH AS path, ZDATE AS date, '
        '${optional('ZDURATION')} AS duration, '
        '${optional('ZCUSTOMLABEL')} AS label, '
        '${optional('ZENCRYPTEDTITLE')} AS title, '
        '${optional('ZUNIQUEID')} AS uid, '
        '${optional('ZEVICTIONDATE')} AS evicted '
        'FROM ZCLOUDRECORDING',
      );
      final root = p.normalize(p.absolute(folder));
      final memos = <VoiceMemo>[];
      for (final row in rows) {
        final name = row['path'], date = row['date'];
        // No path: the audio is only in iCloud. An eviction date: recently
        // deleted, waiting to be removed for good.
        if (name is! String || name.isEmpty || date is! num || row['evicted'] != null) continue;
        var file = p.normalize(p.isAbsolute(name) ? name : p.join(root, name));
        // Older libraries stored absolute paths from where they used to live.
        if (p.isAbsolute(name) && !p.isWithin(root, file)) {
          file = p.normalize(p.join(root, p.basename(name)));
        }
        if (!p.isWithin(root, file) || !_extensions.contains(p.extension(file).toLowerCase())) {
          continue;
        }
        if (!File(file).existsSync()) continue;
        final uid = row['uid'], seconds = row['duration'];
        memos.add(
          VoiceMemo(
            id: uid is String && uid.isNotEmpty ? uid : 'pk-${row['pk']}',
            title: [row['label'], row['title']]
                .whereType<String>()
                .map((t) => t.trim())
                .firstWhere((t) => t.isNotEmpty, orElse: () => ''),
            recordedAt: DateTime.fromMillisecondsSinceEpoch(
              ((date + _coreDataEpochSeconds) * 1000).round(),
              isUtc: true,
            ),
            duration: Duration(milliseconds: seconds is num ? (seconds * 1000).round() : 0),
            path: file,
          ),
        );
      }
      memos.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      return memos;
    } on SqliteException catch (e) {
      throw VoiceMemoFailure(VoiceMemoProblem.unreadable, e.message);
    } finally {
      db.close();
    }
  }
}
