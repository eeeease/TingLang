import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/db/database.dart';

import 'generated/schema.dart';

void main() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('fresh database matches the committed v4 schema snapshot', () async {
    final connection = await verifier.startAt(4);
    final db = TinglangDatabase(connection);
    addTearDown(db.close);
    // Fails when tables change without bumping schemaVersion and running
    // `dart run drift_dev make-migrations`.
    await verifier.migrateAndValidate(db, 4);
  });

  test('v1 → v4 adds dictation_attempt and keeps existing rows', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      "INSERT INTO session (id, origin, time_base, title, started_at, status) "
      "VALUES ('s1', 'live_system', 'wallclock', '', '2026-10-21T09:00:00.000Z', 'completed')",
    );
    final db = TinglangDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);
    expect((await db.select(db.sessions).get()).single.id, 's1');
    expect(await db.select(db.dictationAttempts).get(), isEmpty);
  });

  test('v2 → v4 adds session.source_ref, empty for existing sessions', () async {
    final schema = await verifier.schemaAt(2);
    schema.rawDatabase.execute(
      "INSERT INTO session (id, origin, time_base, title, started_at, status) "
      "VALUES ('s1', 'file', 'media', 'memo', '2026-10-21T09:00:00.000Z', 'completed')",
    );
    final db = TinglangDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);
    final session = (await db.select(db.sessions).get()).single;
    expect(session.title, 'memo');
    expect(session.sourceRef, isNull);
  });

  test('v3 → v4 adds an empty sync_record table and keeps learner rows', () async {
    final schema = await verifier.schemaAt(3);
    schema.rawDatabase.execute(
      "INSERT INTO progress (course_id, clip_id, step) VALUES ('c1', 'k1', 'words')",
    );
    final db = TinglangDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);
    expect((await db.select(db.progress).get()).single.step, 'words');
    // Nothing is synced until the user turns sync on.
    expect(await db.select(db.syncRecords).get(), isEmpty);
  });

  test('a database from a newer app version is refused, not downgraded', () async {
    final executor = NativeDatabase.memory(setup: (raw) => raw.userVersion = 99);
    final db = TinglangDatabase(executor);
    addTearDown(db.close);
    await expectLater(db.customSelect('SELECT 1').get(), throwsA(isA<StateError>()));
  });
}
