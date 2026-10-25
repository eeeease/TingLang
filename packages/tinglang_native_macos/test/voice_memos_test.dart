import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang_native_macos/tinglang_native_macos.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart';

/// Seconds since 2001-01-01 UTC, as Core Data stores dates.
double coreData(DateTime utc) => utc.millisecondsSinceEpoch / 1000 - 978307200;

void main() {
  late Directory home;
  late String folder;

  setUp(() async {
    home = await Directory.systemTemp.createTemp('voice-memos-home-');
    folder = p.join(home.path, MacVoiceMemoLibrary.recordingFolders.first);
    await Directory(folder).create(recursive: true);
  });
  tearDown(() => home.delete(recursive: true));

  /// A Voice Memos index with [columns] and [rows] (values by column).
  void index(List<String> columns, List<Map<String, Object?>> rows) {
    final db = sqlite3.open(p.join(folder, 'CloudRecordings.db'));
    db.execute('CREATE TABLE ZCLOUDRECORDING (${columns.join(', ')})');
    for (final row in rows) {
      db.execute(
        'INSERT INTO ZCLOUDRECORDING (${row.keys.join(', ')}) '
        'VALUES (${List.filled(row.length, '?').join(', ')})',
        row.values.toList(),
      );
    }
    db.close();
  }

  void audio(String name) => File(p.join(folder, name)).writeAsBytesSync([0, 1, 2, 3]);

  const full = [
    'Z_PK INTEGER PRIMARY KEY',
    'ZPATH VARCHAR',
    'ZDATE TIMESTAMP',
    'ZDURATION FLOAT',
    'ZCUSTOMLABEL VARCHAR',
    'ZENCRYPTEDTITLE VARCHAR',
    'ZUNIQUEID VARCHAR',
    'ZEVICTIONDATE TIMESTAMP',
  ];

  test('lists recordings on this Mac, newest first, with titles and times', () async {
    final morning = DateTime.utc(2026, 10, 22, 0, 15);
    final evening = DateTime.utc(2026, 10, 21, 11);
    final older = DateTime.utc(2026, 9, 30, 8);
    audio('20261022 081500-AAAA.m4a');
    audio('20261021 190000-BBBB.qta');
    audio('old.m4a');
    audio('notes.txt');
    File(p.join(home.path, 'secret.m4a')).writeAsBytesSync([1]);
    index(full, [
      {
        'Z_PK': 1,
        'ZPATH': '20261022 081500-AAAA.m4a',
        'ZDATE': coreData(morning),
        'ZDURATION': 63.5,
        'ZCUSTOMLABEL': 'Morning standup',
        'ZUNIQUEID': 'UID-1',
      },
      {
        'Z_PK': 2,
        'ZPATH': '20261021 190000-BBBB.qta',
        'ZDATE': coreData(evening),
        'ZDURATION': 1800,
        'ZENCRYPTEDTITLE': ' Lecture ',
      },
      // Only in iCloud, file missing, outside the folder, deleted, not audio.
      {'Z_PK': 3, 'ZPATH': null, 'ZDATE': coreData(morning)},
      {'Z_PK': 4, 'ZPATH': 'gone.m4a', 'ZDATE': coreData(morning)},
      {'Z_PK': 5, 'ZPATH': '../../../../../secret.m4a', 'ZDATE': coreData(morning)},
      {
        'Z_PK': 6,
        'ZPATH': '20261022 081500-AAAA.m4a',
        'ZDATE': coreData(morning),
        'ZEVICTIONDATE': coreData(morning),
      },
      {'Z_PK': 7, 'ZPATH': 'notes.txt', 'ZDATE': coreData(morning)},
      // An absolute path from the old library location.
      {
        'Z_PK': 8,
        'ZPATH':
            '/Users/someone/Library/Application Support/com.apple.voicememos/Recordings/old.m4a',
        'ZDATE': coreData(older),
        'ZDURATION': 12,
      },
    ]);

    final memos = await MacVoiceMemoLibrary(home: home.path).list();
    expect(memos.map((m) => m.id), ['UID-1', 'pk-2', 'pk-8']);
    expect(memos.map((m) => m.title), ['Morning standup', 'Lecture', '']);
    expect(memos.first.recordedAt, morning);
    expect(memos.first.duration, const Duration(milliseconds: 63500));
    expect(memos[1].path, p.join(p.normalize(p.absolute(folder)), '20261021 190000-BBBB.qta'));
    expect(memos.last.path, endsWith('${p.separator}old.m4a'));
    expect(File(memos.last.path).existsSync(), isTrue);
  });

  test('older indexes without the optional columns still list', () async {
    audio('a.m4a');
    index(
      const ['Z_PK INTEGER PRIMARY KEY', 'ZPATH VARCHAR', 'ZDATE TIMESTAMP'],
      [
        {'Z_PK': 1, 'ZPATH': 'a.m4a', 'ZDATE': 0},
      ],
    );
    final memos = await MacVoiceMemoLibrary(home: home.path).list();
    expect(memos.single.id, 'pk-1');
    expect(memos.single.recordedAt, DateTime.utc(2001));
    expect(memos.single.duration, Duration.zero);
  });

  Matcher fails(VoiceMemoProblem problem) =>
      throwsA(isA<VoiceMemoFailure>().having((f) => f.problem, 'problem', problem));

  test('says why nothing can be listed', () async {
    final empty = await Directory.systemTemp.createTemp('voice-memos-empty-');
    addTearDown(() => empty.delete(recursive: true));
    await expectLater(
      MacVoiceMemoLibrary(home: empty.path).list(),
      fails(VoiceMemoProblem.noLibrary),
    );

    // A folder without an index (Voice Memos never synced here).
    await expectLater(
      MacVoiceMemoLibrary(home: home.path).list(),
      fails(VoiceMemoProblem.noLibrary),
    );

    sqlite3.open(p.join(folder, 'CloudRecordings.db'))
      ..execute('CREATE TABLE ZSOMETHINGELSE (Z_PK INTEGER)')
      ..close();
    await expectLater(
      MacVoiceMemoLibrary(home: home.path).list(),
      fails(VoiceMemoProblem.unreadable),
    );
  });

  test('a protected index asks for Full Disk Access', () async {
    index(full, const []);
    final file = File(p.join(folder, 'CloudRecordings.db'));
    // Privacy protection refuses to open the file, much like a 000 mode.
    await Process.run('chmod', ['000', file.path]);
    addTearDown(() => Process.run('chmod', ['644', file.path]));
    await expectLater(
      MacVoiceMemoLibrary(home: home.path).list(),
      fails(VoiceMemoProblem.needsFullDiskAccess),
    );
  });
}
