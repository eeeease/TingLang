import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/l10n/app_localizations.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/link_import.dart';
import 'package:tinglang/services/transcription_controller.dart';
import 'package:tinglang/ui/import_dialog.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import 'update/update_fakes.dart' show MemoryStore;

void main() {
  late AppController app;
  late TinglangDatabase db;
  late TranscriptionController transcription;
  setUp(() {
    app = AppController(MemoryStore(), LibraryState());
    db = TinglangDatabase.memory();
    transcription = TranscriptionController(repository: LiveRepository(db), store: MemoryStore());
  });
  tearDown(() => db.close());

  LinkImportService service() => LinkImportService(
    app: app,
    transcription: transcription,
    toolsFolder: Directory('${Directory.systemTemp.path}/tinglang-no-tools'),
  );

  testWidgets('the import dialog offers a link field when links are available', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> open({LinkImportService? links}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TinglangTheme.light(),
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ImportDialog(app: app, onTranscribe: (_) async {}, links: links),
          ),
        ),
      );
      await tester.pump();
    }

    await open(links: service());
    expect(find.text('粘贴视频链接'), findsOneWidget);
    expect(find.byKey(const ValueKey('link-field')), findsOneWidget);
    expect(find.textContaining('由你自己负责'), findsOneWidget);
    await open();
    expect(find.byKey(const ValueKey('link-field')), findsNothing);
  });
}
