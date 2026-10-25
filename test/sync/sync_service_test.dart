import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/db/sqlite_library_store.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/sync_service.dart';
import 'package:tinglang_platform_interface/testing.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory temp, iCloud;
  late TinglangDatabase db;
  late AppController app;
  late LiveRepository repository;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('tinglang-sync-service-');
    iCloud = Directory(p.join(temp.path, 'com~apple~CloudDocs'));
    db = TinglangDatabase.memory();
    final store = SqliteLibraryStore(Directory(p.join(temp.path, 'library')), db);
    app = AppController(store, await store.load());
    repository = LiveRepository(db);
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  SyncService service({
    FakeCloudDrive? drive,
    Duration debounce = const Duration(milliseconds: 20),
  }) {
    final sync = SyncService(
      app: app,
      repository: repository,
      drive: drive,
      iCloudDrive: iCloud,
      deviceName: 'Test Mac',
      debounce: debounce,
      interval: Duration.zero,
      watchFolder: false,
      followLifecycle: false,
    );
    addTearDown(sync.dispose);
    return sync;
  }

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(done(), isTrue, reason: 'did not happen in time');
  }

  Directory devices() => Directory(p.join(iCloud.path, 'Tinglang', 'devices'));

  test('off by default: nothing in iCloud Drive is read or written', () async {
    await iCloud.create();
    final sync = service();
    await sync.start();
    expect(sync.enabled, isFalse);
    expect(sync.status, SyncStatus.off);
    await app.saveDraft('c', 'k', 'retelling', 'hello');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(iCloud.listSync(), isEmpty);
    expect(await db.select(db.syncRecords).get(), isEmpty);
  });

  test('without iCloud Drive it says so and writes nothing until it is back', () async {
    final sync = service();
    await sync.start();
    await sync.setEnabled(true);
    expect(app.setting(SyncService.enabledKey, ''), 'true');
    expect(sync.status, SyncStatus.unavailable);
    expect(sync.iCloudDriveAvailable, isFalse);
    // Sync never creates iCloud Drive itself.
    expect(iCloud.existsSync(), isFalse);

    await iCloud.create();
    await sync.syncNow();
    expect(sync.status, SyncStatus.idle);
    expect(sync.lastSync, isNotNull);
    expect(devices().listSync(), hasLength(1));
  });

  test('turning it on syncs at once, and a change syncs again shortly after', () async {
    await iCloud.create();
    final sync = service();
    await sync.start();
    await sync.setEnabled(true);
    expect(sync.status, SyncStatus.idle);
    expect(sync.report, isNotNull);
    final state = File(p.join(devices().listSync().single.path, 'state.json'));
    expect(state.readAsStringSync(), isNot(contains('hello')));

    await app.saveDraft('c', 'k', 'retelling', 'hello');
    await until(() => state.readAsStringSync().contains('hello'));
    expect(sync.report!.records, 1);

    // Off: changes stay on this Mac, and what is in iCloud Drive stays too.
    await sync.setEnabled(false);
    expect(sync.status, SyncStatus.off);
    await app.saveDraft('c', 'k', 'retelling', 'not synced');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(state.readAsStringSync(), contains('hello'));
    expect(state.readAsStringSync(), isNot(contains('not synced')));
  });

  test('a recording saved in the database also starts a pass', () async {
    await iCloud.create();
    final sync = service();
    await sync.start();
    await sync.setEnabled(true);
    await repository.createSession(
      id: 's1',
      origin: 'live_mic',
      language: 'en',
      title: 'Talk',
      startedAt: DateTime.utc(2026, 10, 25),
    );
    await repository.endSession('s1', status: 'completed', endedAt: DateTime.utc(2026, 10, 25, 1));
    await until(() => sync.report?.sessions == 1);
  });

  test('the Mac keeps its folder; a library copied to another Mac gets its own', () async {
    await iCloud.create();
    await app.setSetting(SyncService.enabledKey, 'true');
    final first = service(drive: FakeCloudDrive(machine: 'mac-1'));
    await first.start();
    final folder = devices().listSync().single.path;

    final again = service(drive: FakeCloudDrive(machine: 'mac-1'));
    await again.syncNow();
    expect(devices().listSync().map((d) => d.path), [folder]);

    // The same library on another Mac (Migration Assistant, a backup).
    final copied = service(drive: FakeCloudDrive(machine: 'mac-2'));
    await copied.syncNow();
    expect(devices().listSync(), hasLength(2));
  });
}
