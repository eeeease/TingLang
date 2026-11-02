import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/core/models.dart';
import 'package:tinglang/l10n/app_localizations.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/playback_hub.dart';
import 'package:tinglang/services/recording_service.dart';
import 'package:tinglang/ui/learn_page.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import 'update/update_fakes.dart' show MemoryStore;

void main() {
  testWidgets('words show one card at a time, picked by tab or Previous / Next', (tester) async {
    // The record plugin creates its native recorder eagerly; no recording happens here.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => null,
    );
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    LearningItem word(String id, String text, String meaning) =>
        LearningItem(id: id, kind: 'words', text: text, meaning: meaning);
    final course = Course(
      id: 'c1',
      title: 'Commencement',
      area: Area.podcasts,
      raw: const {},
      importedAt: DateTime.utc(2026, 11, 2),
      clips: [
        CourseClip(
          id: 'clip-1',
          title: 'Adoption',
          startMs: 0,
          endMs: 60000,
          transcript: '',
          sentences: const [],
          items: [
            word('w1', 'relented', '让步'),
            word('w2', 'dropout', '辍学者'),
            word('w3', 'naive', '天真的'),
            const LearningItem(id: 'p1', kind: 'phrases', text: 'connect the dots', meaning: '串起'),
          ],
          blanks: const [],
          blindTemplate: '',
          shadowing: const [],
          retellPrompt: '',
          followUp: '',
          outline: const [],
        ),
      ],
    );
    final app = AppController(store, LibraryState(courses: [course]));
    await tester.pumpWidget(
      MaterialApp(
        theme: TinglangTheme.dark(),
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LearnPage(
            app: app,
            course: course,
            clipId: 'clip-1',
            playback: PlaybackHub(),
            recorder: RecordingService(store),
            onClip: (_) {},
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No heading above the tab's content; one card, with its place shown.
    expect(find.text('值得留下的词'), findsNothing);
    expect(find.text('让步'), findsOneWidget);
    expect(find.text('辍学者'), findsNothing);
    expect(find.text('1 / 3'), findsOneWidget);
    final previous = find.byKey(const ValueKey('item-words-previous'));
    final next = find.byKey(const ValueKey('item-words-next'));
    expect(tester.widget<OutlinedButton>(previous).onPressed, isNull);

    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('辍学者'), findsOneWidget);
    expect(find.text('让步'), findsNothing);
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('item-words-2')));
    await tester.pumpAndSettle();
    expect(find.text('天真的'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(next).onPressed, isNull);

    await tester.tap(previous);
    await tester.pumpAndSettle();
    expect(find.text('辍学者'), findsOneWidget);

    // Phrases keep their own place.
    await tester.tap(find.text('短语'));
    await tester.pumpAndSettle();
    expect(find.text('串起'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('可以复用的表达'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
