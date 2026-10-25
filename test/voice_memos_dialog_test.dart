import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/l10n/app_localizations.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/transcription_controller.dart';
import 'package:tinglang/services/voice_memos.dart';
import 'package:tinglang/ui/voice_memos_dialog.dart';
import 'package:tinglang_native/tinglang_native.dart';
import 'package:tinglang_platform_interface/testing.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

void main() {
  late Directory dir;
  late TinglangDatabase db;
  late AppController app;
  late FakeVoiceMemoLibrary library;
  late FakeDesktopShell shell;
  late VoiceMemoService service;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('tinglang-memo-dialog-');
    db = TinglangDatabase.memory();
    final store = LibraryStore(Directory('${dir.path}/library'));
    app = AppController(store, LibraryState());
    final today = DateTime.now();
    VoiceMemo memo(String id, DateTime local, String title) => VoiceMemo(
      id: id,
      title: title,
      recordedAt: local.toUtc(),
      duration: const Duration(minutes: 2, seconds: 5),
      path: '${dir.path}/$id.m4a',
    );
    library = FakeVoiceMemoLibrary([
      memo('a', DateTime(today.year, today.month, today.day, 8), 'Standup'),
      memo('b', DateTime(today.year, today.month, today.day, 7), ''),
      memo(
        'c',
        DateTime(today.year, today.month, today.day).subtract(const Duration(days: 3)),
        'Old',
      ),
    ]);
    shell = FakeDesktopShell();
    final platform = TinglangPlatform(
      probeSource: FakeProbeSource(FakeProbes.macos(const OsVersion(26))),
    )..voiceMemos.register(BackendFactory(BackendCatalog.appleVoiceMemos, () => library));
    // Saved up front: the dialog's own save would be real file IO, which
    // widget tests' fake time never completes.
    await app.setSetting(VoiceMemoService.enabledKey, 'true');
    service = VoiceMemoService(
      app: app,
      transcription: TranscriptionController(
        repository: LiveRepository(db),
        store: store,
        platform: platform,
      ),
      platform: platform,
      shell: shell,
    );
  });
  tearDown(() async {
    app.dispose();
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TinglangTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showVoiceMemos(context, service),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets("today's new recordings come selected; untitled ones are named by date", (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Standup'), findsOneWidget);
    expect(find.textContaining('Voice memo · '), findsOneWidget);
    expect(find.text('Old'), findsOneWidget);
    expect(find.textContaining('2:05'), findsNWidgets(3));
    expect(find.text('Import and transcribe (2)'), findsOneWidget);

    await tester.tap(find.text('Old'));
    await tester.pump();
    expect(find.text('Import and transcribe (3)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a protected library explains Full Disk Access and opens the settings', (
    tester,
  ) async {
    library.problem = VoiceMemoProblem.needsFullDiskAccess;
    await open(tester);
    expect(find.text('Let TingLang read Voice Memos'), findsOneWidget);
    expect(find.textContaining('Import and transcribe'), findsNothing);
    await tester.tap(find.text('Open System Settings'));
    await tester.pump();
    expect(shell.openedSettings, [SystemSettingsPane.fullDiskAccess]);

    // After granting access, checking again shows the list.
    library.problem = null;
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(find.text('Standup'), findsOneWidget);
    expect(find.text('Import and transcribe (2)'), findsOneWidget);
  });
}
