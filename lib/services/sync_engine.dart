import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:path/path.dart' as p;
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

import '../core/db/database.dart';
import '../core/json_helpers.dart';
import '../core/library_store.dart';
import '../core/live_repository.dart';
import '../core/models.dart';
import '../core/review.dart';
import '../core/share_package.dart';
import 'app_controller.dart';

/// What the sync folder holds, one entry per synced thing.
///
/// Items travel as `.tinglang` packages (content + media); learner records
/// travel as JSON values inside each Mac's state file.
enum SyncKind {
  course,
  session,
  progress,
  draft,
  card,
  attempt,
  dictation;

  bool get isItem => this == course || this == session;
  static final byName = values.asNameMap();
}

typedef SyncKey = (SyncKind, String);

/// A version of a record: when it was made (ms since the epoch, UTC) and on
/// which Mac. The newer one wins (time first, then device id), on every Mac.
final class SyncVersion implements Comparable<SyncVersion> {
  const SyncVersion(this.at, this.device);
  final int at;
  final String device;

  @override
  int compareTo(SyncVersion other) =>
      at != other.at ? at.compareTo(other.at) : device.compareTo(other.device);

  bool isNewerThan(SyncVersion? other) => other == null || compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is SyncVersion && other.at == at && other.device == device;

  @override
  int get hashCode => Object.hash(at, device);

  @override
  String toString() => '$at@$device';
}

/// One record in a Mac's state file (`devices/<id>/state.json`).
final class SyncEntry {
  const SyncEntry({
    required this.kind,
    required this.key,
    required this.version,
    this.deleted = false,
    this.hash,
    this.value,
    this.file,
  });
  final SyncKind kind;
  final String key;
  final SyncVersion version;

  /// A tombstone: the record was deleted on [SyncVersion.device].
  final bool deleted;
  final String? hash;

  /// The learner record itself (JSON), for records that are not items.
  final Object? value;

  /// The package (items) or recording (attempts), relative to the device
  /// folder that holds the state file.
  final String? file;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'key': key,
    'at': version.at,
    'device': version.device,
    if (deleted) 'deleted': true,
    if (hash != null) 'hash': hash,
    if (value != null) 'value': value,
    if (file != null) 'file': file,
  };

  /// Null for entries this version does not understand (a newer kind) or
  /// that are malformed; they are skipped, not fatal.
  static SyncEntry? tryParse(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final kind = SyncKind.byName[json['kind']];
    final key = json['key'], at = json['at'], device = json['device'];
    if (kind == null || key is! String || at is! int || device is! String) return null;
    final file = json['file'];
    if (file != null && (file is! String || !_safeRelative(file))) return null;
    return SyncEntry(
      kind: kind,
      key: key,
      version: SyncVersion(at, device),
      deleted: json['deleted'] == true,
      hash: json['hash'] as String?,
      value: json['value'],
      file: file as String?,
    );
  }
}

bool _safeRelative(String path) =>
    path.isNotEmpty &&
    !p.isAbsolute(path) &&
    !path.contains('\\') &&
    p.split(path).every((part) => part != '..' && part != '.');

enum SyncProblemKind {
  /// The folder was set up by a newer Tinglang; nothing is written.
  newerFolder,

  /// Another Mac's state file is from a newer Tinglang; it is skipped.
  newerState,

  /// Another Mac's state file could not be read; it is skipped.
  unreadableState,

  /// A package is from a newer Tinglang; that item is skipped.
  newerPackage,

  /// A package (or a recording) could not be read; that item is skipped.
  unreadablePackage,

  /// Writing to iCloud Drive failed (for example the disk is full).
  writeFailed,
}

final class SyncProblem {
  const SyncProblem(this.kind, {this.name, this.detail});
  final SyncProblemKind kind;

  /// The item's title or the other Mac's name, when known.
  final String? name;

  /// Technical detail, for diagnostics only.
  final String? detail;

  @override
  String toString() => 'SyncProblem(${kind.name}, $name, $detail)';
}

/// The outcome of one pass.
final class SyncReport {
  const SyncReport({
    required this.at,
    this.courses = 0,
    this.sessions = 0,
    this.records = 0,
    this.waiting = 0,
    this.otherDevices = 0,
    this.published = 0,
    this.applied = 0,
    this.problems = const [],
  });
  final DateTime at;

  /// Courses, recordings and learner records in sync on this Mac.
  final int courses, sessions, records;

  /// Things another Mac published that iCloud has not downloaded yet (or
  /// that wait for something else, like a recording for its answers).
  final int waiting;

  /// Other Macs that have written to the folder.
  final int otherDevices;

  /// Versions this pass wrote, and versions from other Macs it applied.
  final int published, applied;
  final List<SyncProblem> problems;
}

/// The current local copy of one synced thing.
final class _Local {
  const _Local(this.hash, {this.time, this.value, this.course, this.session, this.title = ''});
  final String hash;

  /// When the record itself says it was made or last changed, if it does.
  final int? time;
  final Object? value;
  final Course? course;
  final SessionRow? session;
  final String title;
}

/// One sync pass between this library and a folder that macOS syncs
/// through iCloud Drive (`~/Library/Mobile Documents/com~apple~CloudDocs/
/// Tinglang`). The database never goes there; see docs/ARCHITECTURE.md
/// "iCloud Drive sync" for the layout and the rules:
///
/// - each Mac writes only its own folder `devices/<id>/`: a `state.json`
///   with its versions (learner values inline) and the packages and
///   recordings they refer to, so no two Macs ever write the same file;
/// - a record's newest version wins (time, then device id); a change made
///   here gets the time it was noticed;
/// - deletions are tombstones; a missing or not yet downloaded file never
///   deletes anything;
/// - files iCloud has not downloaded are requested and retried later.
///
/// The engine is plain file and database work, testable with temporary
/// folders; it opens no network connection.
class SyncEngine {
  SyncEngine({
    required this.folder,
    required this.app,
    required this.repository,
    required this.deviceId,
    this.deviceName = '',
    this.drive,
    this.appVersion = '',
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  /// The Tinglang folder inside iCloud Drive (created if missing; its parent
  /// must exist).
  final Directory folder;
  final AppController app;
  final LiveRepository repository;
  final String deviceId;
  final String deviceName;

  /// Download states and requests; without it only `.<name>.icloud`
  /// placeholders are recognised.
  final CloudDriveSupport? drive;
  final String appVersion;
  final DateTime Function() clock;

  static const folderFormat = 'tinglang.sync';
  static const stateFormat = 'tinglang.sync.state';
  static const version = 1;
  static const joinedKey = 'sync.joined';

  /// Session origins shown in History (the ones that are synced).
  static const sessionOrigins = ['live_system', 'live_mic', 'file', 'shared', 'voice_memo'];

  TinglangDatabase get db => repository.db;
  LibraryStore get store => app.store;
  Directory get _mine => Directory(p.join(folder.path, 'devices', deviceId));

  final _problems = <SyncProblem>[];
  var _waiting = 0;
  final _toDownload = <String>{};

  /// Packages that could not be read, by path and published hash: reported
  /// again on later passes without reading them again.
  final _failures = <String, SyncProblem>{};

  /// Runs one pass. Never throws for a problem with one item or one other
  /// Mac (those are reported); throws only when this Mac cannot work with
  /// the folder at all.
  Future<SyncReport> run() async {
    _problems.clear();
    _waiting = 0;
    _toDownload.clear();
    var published = 0, applied = 0;
    if (!await _checkFolder()) return _report(0, 0, 0);

    // 1. What the other Macs have.
    final (remote, holders, devices) = await _remoteEntries();

    // 2. What changed here since the last pass: new versions made now.
    final now = clock().toUtc().millisecondsSinceEpoch;
    final joining = await db.meta(joinedKey) == null;
    final local = await _snapshot();
    final ledger = await _ledger();
    final changes = <SyncRecordRow>[];
    for (final MapEntry(:key, value: record) in local.entries) {
      final entry = ledger[key];
      final int at;
      if (entry == null && joining) {
        // A library synced for the first time gives way to what other Macs
        // already have, unless the record itself says it changed later
        // (a review, an import): its version is just older than theirs.
        final theirs = remote[key]?.version;
        final own = record.time;
        at = theirs != null && (own == null || theirs.at >= own) ? theirs.at - 1 : (own ?? 0);
      } else if (entry == null) {
        at = now;
      } else if (entry.localHash != record.hash) {
        at = _after(now, entry.updatedAt);
      } else {
        continue;
      }
      changes.add(_row(key, SyncVersion(at, deviceId), localHash: record.hash, hash: record.hash));
    }
    for (final MapEntry(:key, value: entry) in ledger.entries) {
      if (entry.deleted || local.containsKey(key)) continue;
      // Deleted on this Mac: a tombstone, newer than what it replaces.
      changes.add(_row(key, SyncVersion(_after(now, entry.updatedAt), deviceId), deleted: true));
    }
    await _saveLedger(changes, ledger);

    // 3. Newer versions from other Macs.
    final applies = <SyncRecordRow>[];
    final records = <(SyncKey, SyncEntry, String)>[];
    for (final MapEntry(:key, value: winner) in remote.entries) {
      final entry = ledger[key];
      if (!winner.version.isNewerThan(entry == null ? null : _version(entry))) continue;
      final mine = local[key];
      final holder = holders[key]!;
      if (winner.deleted ? mine == null : mine?.hash == winner.hash && winner.hash != null) {
        // Already the same here: only remember the version.
        applies.add(
          _row(
            key,
            winner.version,
            localHash: mine?.hash,
            hash: winner.hash,
            deleted: winner.deleted,
          ),
        );
        continue;
      }
      if (key.$1.isItem) {
        final hash = await _applyItem(key, winner, holder, mine);
        if (hash != null) {
          applies.add(
            _row(
              key,
              winner.version,
              localHash: hash.isEmpty ? null : hash,
              hash: winner.hash,
              deleted: winner.deleted,
            ),
          );
          applied++;
        }
      } else {
        records.add((key, winner, holder));
      }
    }
    for (final (_, row) in await _applyRecords(records)) {
      applies.add(row);
      applied++;
    }
    await _saveLedger(applies, ledger);

    // 4. Publish this Mac's versions: packages and recordings first, then
    // the state file, then remove files no version refers to any more.
    final current = await _snapshot();
    final out = <SyncEntry>[];
    final referenced = <String>{};
    for (final MapEntry(:key, value: entry) in ledger.entries) {
      if (entry.device != deviceId) continue;
      final version = _version(entry);
      if (entry.deleted) {
        out.add(SyncEntry(kind: key.$1, key: key.$2, version: version, deleted: true));
        continue;
      }
      final record = current[key] ?? local[key];
      if (record == null) continue;
      try {
        final entryOut = await _publish(key, version, entry.hash ?? record.hash, record);
        if (entryOut == null) continue;
        if (entryOut.file != null) referenced.add(entryOut.file!);
        out.add(entryOut);
      } on Object catch (e) {
        _problems.add(SyncProblem(SyncProblemKind.writeFailed, name: record.title, detail: '$e'));
      }
    }
    published = changes.length;
    try {
      await _writeState(out);
      await _collectGarbage(referenced);
    } on FileSystemException catch (e) {
      _problems.add(SyncProblem(SyncProblemKind.writeFailed, detail: '$e'));
    }
    if (_toDownload.isNotEmpty) {
      try {
        await drive?.download(_toDownload.toList());
      } on Object {
        // Asked again on the next pass.
      }
    }
    if (joining) await db.setMeta(joinedKey, clock().toUtc().toIso8601String());
    var courses = 0, sessions = 0, learner = 0;
    for (final MapEntry(:key, value: entry) in ledger.entries) {
      if (entry.deleted) continue;
      switch (key.$1) {
        case SyncKind.course:
          courses++;
        case SyncKind.session:
          sessions++;
        default:
          learner++;
      }
    }
    return _report(
      courses,
      sessions,
      learner,
      devices: devices,
      published: published,
      applied: applied,
    );
  }

  SyncReport _report(
    int courses,
    int sessions,
    int records, {
    int devices = 0,
    int published = 0,
    int applied = 0,
  }) => SyncReport(
    at: clock().toUtc(),
    courses: courses,
    sessions: sessions,
    records: records,
    waiting: _waiting,
    otherDevices: devices,
    published: published,
    applied: applied,
    problems: List.unmodifiable(_problems),
  );

  static int _after(int now, int previous) => now > previous ? now : previous + 1;

  SyncRecordRow _row(
    SyncKey key,
    SyncVersion version, {
    String? localHash,
    String? hash,
    bool deleted = false,
  }) => SyncRecordRow(
    kind: key.$1.name,
    key: key.$2,
    localHash: deleted ? null : localHash,
    updatedAt: version.at,
    device: version.device,
    deleted: deleted,
    hash: deleted ? null : hash,
  );

  static SyncVersion _version(SyncRecordRow row) => SyncVersion(row.updatedAt, row.device);

  // ---------------------------------------------------------------- folder

  /// The folder marker; false (with a problem) for a newer layout, or while
  /// iCloud has not downloaded the marker.
  Future<bool> _checkFolder() async {
    await folder.create();
    final marker = File(p.join(folder.path, 'sync.json'));
    switch (await _availability(marker.path)) {
      case _Availability.waiting:
        _waiting++;
        await drive?.download(_toDownload.toList());
        return false;
      case _Availability.missing:
        await _writeAtomically(
          marker.path,
          const JsonEncoder.withIndent('  ').convert({'format': folderFormat, 'version': version}),
        );
      case _Availability.ready:
        try {
          final json = jsonDecode(await marker.readAsString());
          final newer = json is Map<String, Object?> && (json['version'] as num? ?? 0) > version;
          if (newer) {
            _problems.add(const SyncProblem(SyncProblemKind.newerFolder));
            return false;
          }
        } on FormatException {
          // Damaged by hand: the layout is still this one; leave it alone.
        }
    }
    await Directory(p.join(_mine.path, 'items')).create(recursive: true);
    return true;
  }

  Future<void> _writeAtomically(String path, String text) async {
    final temp = File(
      p.join(Directory.systemTemp.path, 'tinglang-sync-${DateTime.now().microsecondsSinceEpoch}'),
    );
    await temp.writeAsString(text, flush: true);
    try {
      await temp.rename(path);
    } on FileSystemException {
      final near = File('$path.${DateTime.now().microsecondsSinceEpoch}.partial');
      await temp.copy(near.path);
      await temp.delete();
      await near.rename(path);
    }
  }

  /// Whether [path] can be read now. A file iCloud has not downloaded (a
  /// `.<name>.icloud` placeholder, or one macOS reports as not downloaded)
  /// is queued for download and reported as waiting.
  Future<_Availability> _availability(String path) async {
    final file = File(path);
    if (await file.exists()) {
      var state = CloudItemState.local;
      try {
        state = (await drive?.itemStates([path]))?[path] ?? CloudItemState.local;
      } on Object {
        // Unknown: read it like a local file (reading downloads it).
      }
      switch (state) {
        case CloudItemState.notDownloaded:
          _toDownload.add(path);
          return _Availability.waiting;
        case CloudItemState.outdated:
          // Readable; the newer copy comes on a later pass.
          _toDownload.add(path);
          return _Availability.ready;
        case CloudItemState.missing:
          return _Availability.missing;
        case CloudItemState.local || CloudItemState.current:
          return _Availability.ready;
      }
    }
    if (await File(_placeholder(path)).exists()) {
      _toDownload.add(path);
      return _Availability.waiting;
    }
    return _Availability.missing;
  }

  static String _placeholder(String path) => p.join(p.dirname(path), '.${p.basename(path)}.icloud');

  // -------------------------------------------------------------- snapshot

  static final _hashes = Expando<String>('sync hash');

  static String _sha(String text) => sha256.convert(utf8.encode(text)).toString();

  static String _courseHash(Course course) => _hashes[course] ??= _sha(
    jsonEncode([
      course.raw,
      course.area.name,
      course.sourceLabel,
      course.mediaPath == null ? null : p.basename(course.mediaPath!),
    ]),
  );

  static Map<String, Object?> _cardValue(ReviewCard card) => card.toJson();
  static String _cardHash(ReviewCard card) => _hashes[card] ??= _sha(jsonEncode(card.toJson()));

  /// An attempt as other Macs see it: no local recording path.
  static Map<String, Object?> _attemptValue(PracticeAttempt attempt) =>
      attempt.toJson()..remove('recordingPath');
  static String _attemptHash(PracticeAttempt attempt) =>
      _hashes[attempt] ??= _sha(jsonEncode(attempt.toJson()));

  static Map<String, Object?> _dictationValue(DictationAttemptRow row) => {
    'sessionId': row.sessionId,
    'segmentId': row.segmentId,
    'answer': row.answer,
    'result': row.result,
    'similarity': row.similarity,
    'createdAt': row.createdAt.toUtc().toIso8601String(),
  };

  static String _progressKey(String course, String clip, String step) =>
      jsonEncode([course, clip, step]);

  /// Every synced thing as it is on this Mac now, with its content hash.
  Future<Map<SyncKey, _Local>> _snapshot() async {
    final state = app.state;
    final out = <SyncKey, _Local>{};
    for (final course in state.courses) {
      out[(SyncKind.course, course.id)] = _Local(
        _courseHash(course),
        time: course.importedAt.millisecondsSinceEpoch,
        course: course,
        title: course.title,
      );
    }
    for (final (session, hash) in await _sessionHashes()) {
      out[(SyncKind.session, session.id)] = _Local(
        hash,
        time: (session.endedAt ?? session.startedAt).millisecondsSinceEpoch,
        session: session,
        title: session.title,
      );
    }
    for (final MapEntry(:key, value: steps) in state.completed.entries) {
      final ids = splitEntityKey(key);
      if (ids == null) continue;
      for (final step in steps) {
        out[(SyncKind.progress, _progressKey(ids.$1, ids.$2, step))] = const _Local(
          'done',
          value: true,
        );
      }
    }
    for (final MapEntry(:key, value: text) in state.drafts.entries) {
      out[(SyncKind.draft, key)] = _Local(_sha(text), value: text);
    }
    for (final card in state.reviews) {
      out[(SyncKind.card, card.id)] = _Local(
        _cardHash(card),
        time: card.lastReview?.millisecondsSinceEpoch,
        value: _cardValue(card),
        title: card.text,
      );
    }
    for (final attempt in state.attempts) {
      out[(SyncKind.attempt, attempt.id)] = _Local(
        _attemptHash(attempt),
        time: attempt.createdAt.millisecondsSinceEpoch,
        value: _attemptValue(attempt),
      );
    }
    for (final row in await repository.allDictationAttempts()) {
      final value = _dictationValue(row);
      out[(SyncKind.dictation, row.id)] = _Local(
        _sha(jsonEncode(value)),
        time: row.createdAt.millisecondsSinceEpoch,
        value: value,
      );
    }
    return out;
  }

  /// Finished sessions with a hash of everything their package carries
  /// (counted in SQL rather than reading every line on every pass).
  Future<List<(SessionRow, String)>> _sessionHashes([String? only]) async {
    final query = db.select(db.sessions)
      ..where(
        (s) => s.status.isIn(const ['completed', 'interrupted']) & s.origin.isIn(sessionOrigins),
      );
    if (only != null) query.where((s) => s.id.equals(only));
    final sessions = await query.get();
    if (sessions.isEmpty) return const [];
    final lines = {
      for (final row
          in await db
              .customSelect(
                'SELECT session_id, COUNT(*) AS n, SUM(LENGTH(body)) AS chars, MAX(end_ms) AS last, '
                'SUM(IFNULL(LENGTH(words_json), 0)) AS words FROM segment GROUP BY session_id',
                readsFrom: {db.segments},
              )
              .get())
        row.read<String>('session_id'): [
          row.read<int>('n'),
          row.read<int?>('chars'),
          row.read<int?>('last'),
          row.read<int?>('words'),
        ],
    };
    final translations = {
      for (final row
          in await db
              .customSelect(
                'SELECT g.session_id AS session_id, COUNT(*) AS n, SUM(LENGTH(t.body)) AS chars '
                'FROM "translation" t JOIN segment g ON g.id = t.segment_id GROUP BY g.session_id',
                readsFrom: {db.translations, db.segments},
              )
              .get())
        row.read<String>('session_id'): [row.read<int>('n'), row.read<int?>('chars')],
    };
    return [
      for (final s in sessions)
        (
          s,
          _sha(
            jsonEncode([
              s.title,
              s.origin,
              s.status,
              s.language,
              s.timeBase,
              s.mediaId,
              s.sourceRef,
              s.startedAt.toUtc().toIso8601String(),
              s.endedAt?.toUtc().toIso8601String(),
              lines[s.id],
              translations[s.id],
            ]),
          ),
        ),
    ];
  }

  Future<Map<SyncKey, SyncRecordRow>> _ledger() async => {
    for (final row in await db.select(db.syncRecords).get())
      if (SyncKind.byName[row.kind] case final kind?) (kind, row.key): row,
  };

  Future<void> _saveLedger(List<SyncRecordRow> rows, Map<SyncKey, SyncRecordRow> ledger) async {
    if (rows.isEmpty) return;
    await db.batch((b) => b.insertAllOnConflictUpdate(db.syncRecords, rows));
    for (final row in rows) {
      ledger[(SyncKind.byName[row.kind]!, row.key)] = row;
    }
  }

  // ----------------------------------------------------------- other Macs

  /// The newest entry per key over every other Mac's state file, which Mac
  /// holds it, and how many other Macs there are.
  Future<(Map<SyncKey, SyncEntry>, Map<SyncKey, String>, int)> _remoteEntries() async {
    final winners = <SyncKey, SyncEntry>{};
    final holders = <SyncKey, String>{};
    final devices = Directory(p.join(folder.path, 'devices'));
    if (!await devices.exists()) return (winners, holders, 0);
    var count = 0;
    await for (final dir in devices.list()) {
      if (dir is! Directory) continue;
      final id = p.basename(dir.path);
      if (id == deviceId || !RegExp(r'^[A-Za-z0-9._-]{1,80}$').hasMatch(id)) continue;
      count++;
      final file = File(p.join(dir.path, 'state.json'));
      switch (await _availability(file.path)) {
        case _Availability.missing:
          continue;
        case _Availability.waiting:
          _waiting++;
          continue;
        case _Availability.ready:
      }
      final Object? json;
      try {
        json = jsonDecode(await file.readAsString());
      } on Object catch (e) {
        _problems.add(SyncProblem(SyncProblemKind.unreadableState, detail: '$id: $e'));
        continue;
      }
      if (json is! Map<String, Object?> || json['format'] != stateFormat) {
        _problems.add(SyncProblem(SyncProblemKind.unreadableState, detail: id));
        continue;
      }
      final name = json['name'] is String ? json['name']! as String : id;
      if ((json['version'] as num? ?? 0) > version) {
        _problems.add(SyncProblem(SyncProblemKind.newerState, name: name));
        continue;
      }
      final records = json['records'];
      for (final record in records is List ? records : const []) {
        final entry = SyncEntry.tryParse(record);
        if (entry == null) continue;
        final key = (entry.kind, entry.key);
        if (entry.version.isNewerThan(winners[key]?.version)) {
          winners[key] = entry;
          holders[key] = id;
        }
      }
    }
    return (winners, holders, count);
  }

  // ---------------------------------------------------------------- items

  /// Applies another Mac's version of a course or session. Returns the
  /// local hash afterwards ('' for a deletion), or null when it has to wait
  /// or could not be read (reported).
  Future<String?> _applyItem(SyncKey key, SyncEntry winner, String holder, _Local? mine) async {
    final (kind, id) = key;
    if (winner.deleted) {
      if (kind == SyncKind.course) {
        await app.change((next) => next.courses.removeWhere((c) => c.id == id));
      } else {
        await repository.deleteSession(id);
      }
      return '';
    }
    final relative = winner.file;
    if (relative == null) return null;
    final path = p.join(folder.path, 'devices', holder, relative);
    final failureKey = '$path#${winner.hash}';
    if (_failures[failureKey] case final problem?) {
      _problems.add(problem);
      return null;
    }
    switch (await _availability(path)) {
      case _Availability.ready:
        break;
      case _Availability.waiting || _Availability.missing:
        // Not here yet (the state file can arrive before its package).
        _waiting++;
        return null;
    }
    void failed(SyncProblem problem) {
      _failures[failureKey] = problem;
      _problems.add(problem);
    }

    final SharePackageContents contents;
    try {
      contents = await readSharePackage(File(path));
    } on ShareFailure catch (e) {
      failed(
        SyncProblem(
          e.problem == ShareProblem.newerVersion
              ? SyncProblemKind.newerPackage
              : SyncProblemKind.unreadablePackage,
          name: mine?.title,
          detail: '$relative: ${e.problem.name}',
        ),
      );
      return null;
    } on Object catch (e) {
      failed(
        SyncProblem(SyncProblemKind.unreadablePackage, name: mine?.title, detail: '$relative: $e'),
      );
      return null;
    }
    try {
      final stamp = contents.sync;
      if (stamp == null || stamp['kind'] != kind.name || stamp['key'] != id) {
        throw const FormatException('The package belongs to another item.');
      }
      if (kind == SyncKind.course) {
        final course = await coursePackageCourse(contents, store);
        if (course.id != id) throw const FormatException('The course id does not match.');
        Course? saved;
        await app.change((next) {
          final index = next.courses.indexWhere((c) => c.id == id);
          // As an import: content is replaced, learner records stay, and
          // media already attached here is kept when the package has none.
          saved = index >= 0 && course.mediaPath == null
              ? course.copyWith(mediaPath: next.courses[index].mediaPath)
              : course;
          if (index < 0) {
            next.courses.add(saved!);
          } else {
            next.courses[index] = saved!;
          }
        });
        return _courseHash(saved!);
      }
      final sessionId = await importSyncedSession(
        contents,
        repository: repository,
        store: store,
        fallbackLanguage: app.setting(AppController.learningLanguageKey, 'en'),
      );
      if (sessionId != id) throw const FormatException('The session id does not match.');
      final hashes = await _sessionHashes(id);
      return hashes.isEmpty ? '' : hashes.single.$2;
    } on Object catch (e) {
      failed(
        SyncProblem(
          e is ShareFailure && e.problem == ShareProblem.newerVersion
              ? SyncProblemKind.newerPackage
              : SyncProblemKind.unreadablePackage,
          name: contents.title.isEmpty ? mine?.title : contents.title,
          detail: '$relative: $e',
        ),
      );
      return null;
    } finally {
      await contents.close();
    }
  }

  // -------------------------------------------------------------- records

  /// Applies newer learner records from other Macs in one change (one
  /// transaction) plus the dictation answers; returns the ledger rows.
  Future<List<(SyncKey, SyncRecordRow)>> _applyRecords(
    List<(SyncKey, SyncEntry, String)> records,
  ) async {
    if (records.isEmpty) return const [];
    final rows = <(SyncKey, SyncRecordRow)>[];
    final progress = <(String, String, String, bool)>[];
    final drafts = <String, String?>{};
    final cards = <String, ReviewCard?>{};
    final attempts = <String, PracticeAttempt?>{};
    for (final (key, entry, holder) in records) {
      final (kind, id) = key;
      try {
        switch (kind) {
          case SyncKind.progress:
            final ids = jsonDecode(id);
            if (ids is! List || ids.length != 3 || ids.any((v) => v is! String)) continue;
            progress.add((ids[0] as String, ids[1] as String, ids[2] as String, !entry.deleted));
            rows.add((key, _row(key, entry.version, localHash: 'done', deleted: entry.deleted)));
          case SyncKind.draft:
            final text = entry.deleted ? null : jsonString(entry.value, 'draft');
            drafts[id] = text;
            rows.add((
              key,
              _row(
                key,
                entry.version,
                localHash: text == null ? null : _sha(text),
                hash: entry.hash,
                deleted: entry.deleted,
              ),
            ));
          case SyncKind.card:
            final card = entry.deleted
                ? null
                : ReviewCard.fromJson(jsonObject(entry.value, 'card'));
            if (card != null && card.id != id) continue;
            cards[id] = card;
            rows.add((
              key,
              _row(
                key,
                entry.version,
                localHash: card == null ? null : _cardHash(card),
                hash: entry.hash,
                deleted: entry.deleted,
              ),
            ));
          case SyncKind.attempt:
            PracticeAttempt? attempt;
            if (!entry.deleted) {
              final value = jsonObject(entry.value, 'attempt');
              final recording = await _receiveRecording(id, entry, holder);
              if (recording == _waitingForRecording) {
                _waiting++;
                continue;
              }
              attempt = PracticeAttempt.fromJson({...value, 'recordingPath': recording});
              if (attempt.id != id) continue;
            }
            attempts[id] = attempt;
            rows.add((
              key,
              _row(
                key,
                entry.version,
                localHash: attempt == null ? null : _attemptHash(attempt),
                hash: entry.hash,
                deleted: entry.deleted,
              ),
            ));
          case SyncKind.dictation:
            if (entry.deleted) {
              await repository.deleteDictationAttempt(id);
              rows.add((key, _row(key, entry.version, deleted: true)));
              continue;
            }
            final value = jsonObject(entry.value, 'dictation');
            final sessionId = jsonString(value['sessionId'], 'sessionId');
            if (await repository.session(sessionId) == null) {
              // Its recording has not arrived yet.
              _waiting++;
              continue;
            }
            final row = DictationAttemptRow(
              id: id,
              sessionId: sessionId,
              segmentId: jsonString(value['segmentId'], 'segmentId'),
              answer: jsonString(value['answer'], 'answer'),
              result: jsonString(value['result'], 'result'),
              similarity: (value['similarity'] as num).toDouble(),
              createdAt: DateTime.parse(jsonString(value['createdAt'], 'createdAt')).toUtc(),
            );
            await repository.putDictationAttempt(row);
            rows.add((
              key,
              _row(
                key,
                entry.version,
                localHash: _sha(jsonEncode(_dictationValue(row))),
                hash: entry.hash,
              ),
            ));
          case SyncKind.course || SyncKind.session:
            break;
        }
      } on Object catch (e) {
        _problems.add(SyncProblem(SyncProblemKind.unreadablePackage, detail: '${kind.name}: $e'));
      }
    }
    if (progress.isEmpty && drafts.isEmpty && cards.isEmpty && attempts.isEmpty) return rows;
    await app.change((next) {
      for (final (course, clip, step, done) in progress) {
        final key = entityKey(course, clip);
        final steps = next.completed.putIfAbsent(key, () => {});
        if (done) {
          steps.add(step);
        } else {
          steps.remove(step);
          if (steps.isEmpty) next.completed.remove(key);
        }
      }
      for (final MapEntry(:key, :value) in drafts.entries) {
        if (value == null) {
          next.drafts.remove(key);
        } else {
          next.drafts[key] = value;
        }
      }
      for (final MapEntry(:key, :value) in cards.entries) {
        final index = next.reviews.indexWhere((r) => r.id == key);
        if (value == null) {
          if (index >= 0) next.reviews.removeAt(index);
        } else if (index >= 0) {
          next.reviews[index] = value;
        } else {
          next.reviews.add(value);
        }
      }
      for (final MapEntry(:key, :value) in attempts.entries) {
        final index = next.attempts.indexWhere((a) => a.id == key);
        if (value == null) {
          if (index >= 0) next.attempts.removeAt(index);
        } else if (index >= 0) {
          next.attempts[index] = value;
        } else {
          next.attempts.add(value);
        }
      }
    });
    return rows;
  }

  static const _waitingForRecording = '\u0000waiting';

  /// Copies an attempt's recording from another Mac's folder into the
  /// library; null without one, [_waitingForRecording] while iCloud has not
  /// downloaded it.
  Future<String?> _receiveRecording(String attemptId, SyncEntry entry, String holder) async {
    final relative = entry.file;
    if (relative == null) return null;
    final source = p.join(folder.path, 'devices', holder, relative);
    switch (await _availability(source)) {
      case _Availability.ready:
        break;
      case _Availability.waiting || _Availability.missing:
        return _waitingForRecording;
    }
    final extension = p.extension(relative).toLowerCase();
    final target = 'recordings/sync-${_sha(attemptId).substring(0, 24)}$extension';
    final file = File(store.resolve(target));
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      final part = File('${file.path}.${newId()}.partial');
      try {
        await File(source).copy(part.path);
        await part.rename(file.path);
      } finally {
        if (await part.exists()) await part.delete();
      }
    }
    return target;
  }

  // -------------------------------------------------------------- publish

  static String _fileStem(SyncKey key) => '${key.$1.name}-${_sha(key.$2).substring(0, 24)}';

  /// The state entry for one of this Mac's versions, writing the package or
  /// recording it needs when it is not in the folder yet.
  Future<SyncEntry?> _publish(SyncKey key, SyncVersion version, String hash, _Local record) async {
    final (kind, id) = key;
    switch (kind) {
      case SyncKind.course || SyncKind.session:
        final relative =
            'items/${_fileStem(key)}-${hash.substring(0, 16)}.${SharePackage.extension}';
        final path = p.join(_mine.path, relative);
        if (!await File(path).exists() && !await File(_placeholder(path)).exists()) {
          final stamp = {
            'kind': kind.name,
            'key': id,
            'hash': hash,
            'at': version.at,
            'device': version.device,
          };
          if (kind == SyncKind.course) {
            await exportCoursePackage(
              course: record.course!,
              store: store,
              destination: path,
              sync: stamp,
            );
          } else {
            await exportSessionPackage(
              repository: repository,
              store: store,
              sessionId: id,
              title: record.session!.title,
              destination: path,
              sync: stamp,
            );
          }
        }
        return SyncEntry(kind: kind, key: id, version: version, hash: hash, file: relative);
      case SyncKind.attempt:
        final attempt = app.state.attempts.where((a) => a.id == id).firstOrNull;
        String? relative;
        final recording = attempt?.recordingPath;
        if (recording != null) {
          final source = File(store.resolve(recording));
          if (await source.exists()) {
            relative = 'recordings/${_fileStem(key)}${p.extension(recording).toLowerCase()}';
            final target = File(p.join(_mine.path, relative));
            if (!await target.exists() && !await File(_placeholder(target.path)).exists()) {
              await target.parent.create(recursive: true);
              final part = File(
                p.join(Directory.systemTemp.path, 'tinglang-sync-${newId()}.partial'),
              );
              try {
                await source.copy(part.path);
                try {
                  await part.rename(target.path);
                } on FileSystemException {
                  await part.copy(target.path);
                }
              } finally {
                if (await part.exists()) await part.delete();
              }
            }
          }
        }
        return SyncEntry(
          kind: kind,
          key: id,
          version: version,
          hash: hash,
          value: record.value,
          file: relative,
        );
      case SyncKind.progress || SyncKind.draft || SyncKind.card || SyncKind.dictation:
        return SyncEntry(kind: kind, key: id, version: version, hash: hash, value: record.value);
    }
  }

  Future<void> _writeState(List<SyncEntry> entries) async {
    entries.sort((a, b) {
      final kind = a.kind.index.compareTo(b.kind.index);
      return kind != 0 ? kind : a.key.compareTo(b.key);
    });
    final text = const JsonEncoder.withIndent(' ').convert({
      'format': stateFormat,
      'version': version,
      'device': deviceId,
      'name': deviceName,
      'app': appVersion,
      'records': [for (final e in entries) e.toJson()],
    });
    final file = File(p.join(_mine.path, 'state.json'));
    // Unchanged: write nothing (no new upload, no folder event).
    if (await _availability(file.path) == _Availability.ready &&
        await file.readAsString() == text) {
      return;
    }
    await _writeAtomically(file.path, text);
  }

  /// Removes this Mac's packages and recordings that no version refers to
  /// any more (only in its own folder; other Macs clean up theirs).
  Future<void> _collectGarbage(Set<String> referenced) async {
    for (final folderName in const ['items', 'recordings']) {
      final dir = Directory(p.join(_mine.path, folderName));
      if (!await dir.exists()) continue;
      await for (final file in dir.list()) {
        if (file is! File) continue;
        var name = p.basename(file.path);
        // A placeholder stands for the file it names.
        if (name.startsWith('.') && name.endsWith('.icloud')) {
          name = name.substring(1, name.length - '.icloud'.length);
        } else if (name.startsWith('.')) {
          continue;
        }
        if (!referenced.contains('$folderName/$name')) await file.delete();
      }
    }
  }
}

enum _Availability { ready, waiting, missing }
