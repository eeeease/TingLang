import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/app.dart';
import 'package:tinglang/core/course_codec.dart';
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/json_helpers.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/core/models.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/live_controller.dart';
import 'package:tinglang/services/playback_hub.dart';
import 'package:tinglang/services/recording_service.dart';
import 'package:tinglang/services/transcription_controller.dart';

/// Every course and every recording can be saved as a `.tinglang` file from
/// where people look for it: the course card, the course page, the History
/// list and the session page.
void main() {
  testWidgets('courses and recordings offer "Export share file…" in their menus', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => null,
    );
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('tinglang-menus-')))!;
    addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
    final course = const CourseCodec().fromMap(
      jsonObject(jsonDecode(File('assets/demo/course.json').readAsStringSync()), 'demo'),
      area: Area.nba,
    );
    final store = LibraryStore(dir);
    final app = AppController(
      store,
      LibraryState(courses: [course], settings: {AppController.uiLocaleKey: 'en'}),
    );
    final db = TinglangDatabase.memory();
    addTearDown(() => tester.runAsync(db.close));
    final repository = LiveRepository(db);
    await repository.createSession(
      id: 's1',
      origin: 'live_mic',
      language: 'en',
      title: 'Morning talk',
      startedAt: DateTime.now().toUtc(),
    );
    await repository.endSession('s1', status: 'completed', endedAt: DateTime.now().toUtc());
    final live = LiveController(repository: repository);
    await tester.pumpWidget(
      TinglangApp(
        controller: app,
        playback: PlaybackHub(),
        recorder: RecordingService(store),
        live: live,
        transcription: TranscriptionController(repository: repository, store: store),
        navigation: ValueNotifier(null),
        exitNotice: ValueNotifier(null),
      ),
    );
    await tester.pumpAndSettle();

    // History: the recording's menu.
    expect(find.text('Morning talk'), findsOneWidget);
    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('session-share')), findsOneWidget);
    expect(find.text('Export share file…'), findsOneWidget);
    await tester.tapAt(const Offset(5, 500));
    await tester.pumpAndSettle();

    // Library: the course card's menu.
    await tester.tap(find.byKey(const ValueKey('nav-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('course-menu-${course.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Export share file…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
