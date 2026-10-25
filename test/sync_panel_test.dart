import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/db/sqlite_library_store.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/l10n/app_localizations.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/sync_engine.dart';
import 'package:tinglang/services/sync_service.dart';
import 'package:tinglang/ui/sync_panel.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory temp, iCloud;
  late TinglangDatabase db;
  late AppController app;
  late SyncService sync;
  final revealed = <String>[];

  Future<void> setUpLibrary(WidgetTester tester, {bool enabled = false, bool iCloudDrive = true}) =>
      tester.runAsync(() async {
        temp = await Directory.systemTemp.createTemp('tinglang-sync-panel-');
        iCloud = Directory(p.join(temp.path, 'com~apple~CloudDocs'));
        if (iCloudDrive) await iCloud.create();
        db = TinglangDatabase.memory();
        final store = SqliteLibraryStore(Directory(p.join(temp.path, 'library')), db);
        app = AppController(store, await store.load());
        if (enabled) await app.setSetting(SyncService.enabledKey, 'true');
        sync = SyncService(
          app: app,
          repository: LiveRepository(db),
          iCloudDrive: iCloud,
          deviceName: 'This Mac',
          interval: Duration.zero,
          watchFolder: false,
          followLifecycle: false,
        );
        await sync.start();
      });

  tearDown(() async {
    sync.dispose();
    await db.close();
    await temp.delete(recursive: true);
    revealed.clear();
  });

  Future<void> show(WidgetTester tester, {String locale = 'en', bool dark = false}) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: TinglangTheme.light(),
        darkTheme: TinglangTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(locale),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SyncPanel(sync: sync, reveal: (path) async => revealed.add(path)),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  /// Real file and database work runs outside the test's fake time.
  Future<void> settle(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 150 && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(done(), isTrue, reason: 'did not finish in time');
    await tester.pumpAndSettle();
  }

  testWidgets('off by default, saying nothing is copied', (tester) async {
    await setUpLibrary(tester);
    await show(tester);
    expect(find.text('iCloud Drive sync'), findsOneWidget);
    expect(find.text('Off. Nothing is copied to iCloud Drive.'), findsOneWidget);
    final toggle = tester.widget<Switch>(find.byKey(const ValueKey('sync-switch')));
    expect(toggle.value, isFalse);
    expect(find.byKey(const ValueKey('sync-show-in-finder')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('in Chinese and dark mode', (tester) async {
    await setUpLibrary(tester);
    await show(tester, locale: 'zh', dark: true);
    expect(find.text('iCloud 云盘同步'), findsOneWidget);
    expect(find.text('已关闭，不会向 iCloud 云盘复制任何内容。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without iCloud Drive the panel says how to turn it on', (tester) async {
    await setUpLibrary(tester, enabled: true, iCloudDrive: false);
    await show(tester);
    expect(find.byKey(const ValueKey('sync-unavailable')), findsOneWidget);
    expect(find.textContaining('System Settings → Apple Account → iCloud'), findsOneWidget);
    expect(iCloud.existsSync(), isFalse);
  });

  testWidgets('turning it on syncs and shows the folder, the counts and problems', (tester) async {
    await setUpLibrary(tester);
    await tester.runAsync(() async {
      await app.saveDraft('c', 'k', 'retelling', 'hello');
      // Another Mac running a newer Tinglang.
      final other = Directory(p.join(iCloud.path, 'Tinglang', 'devices', 'other-mac'));
      await other.create(recursive: true);
      await File(p.join(other.path, 'state.json')).writeAsString(
        jsonEncode({
          'format': SyncEngine.stateFormat,
          'version': 7,
          'device': 'other-mac',
          'name': 'Studio Mac',
          'records': <Object?>[],
        }),
      );
    });
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('sync-switch')));
    await settle(tester, () => sync.report != null && sync.status == SyncStatus.idle);
    expect(find.byKey(const ValueKey('sync-idle')), findsOneWidget);
    expect(find.text('iCloud Drive › Tinglang'), findsOneWidget);
    expect(find.text(sync.folder.path), findsOneWidget);
    expect(find.text('0 course(s) · 0 recording(s) · 1 learning record(s)'), findsOneWidget);
    expect(find.text('Shared with 1 other Mac(s)'), findsOneWidget);
    expect(find.textContaining('Studio Mac uses a newer version of TingLang'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sync-show-in-finder')));
    await tester.pumpAndSettle();
    expect(revealed, [sync.folder.path]);
    expect(tester.takeException(), isNull);
  });
}
