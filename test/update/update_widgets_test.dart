import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/l10n/app_localizations.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/update_service.dart';
import 'package:tinglang/ui/update_banner.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import '../cloud/cloud_fakes.dart' show NoNetwork;
import 'update_fakes.dart';

const _translocated =
    '/private/var/folders/ab/xyz/T/AppTranslocation/0B1C/d/Tinglang.app/Contents/MacOS/Tinglang';

/// A release 0.5.0 as the settings cache keeps it.
String _cached() => jsonEncode(
  UpdateRelease.fromGitHub({
    'tag_name': 'v0.5.0',
    'draft': false,
    'prerelease': false,
    'assets': [
      for (final name in ['Tinglang-0.5.0-macOS.zip', 'Tinglang-0.5.0-macOS.zip.sha256'])
        {
          'name': name,
          'size': 100,
          'browser_download_url':
              'https://github.com/eeeease/TingLang/releases/download/v0.5.0/$name',
        },
    ],
  }, UpdateEndpoints.gitHub)!.toJson(),
);

void main() {
  late NoNetwork network;
  late HttpOverrides? before;
  late List<Uri> opened;

  setUp(() {
    network = NoNetwork();
    before = HttpOverrides.current;
    HttpOverrides.global = network;
    opened = [];
  });
  tearDown(() => HttpOverrides.global = before);

  Future<void> show(WidgetTester tester, UpdateService updates, {String locale = 'en'}) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: TinglangTheme.light(),
        locale: Locale(locale),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              UpdateBanner(updates: updates, openUrl: (url) async => opened.add(url)),
              Padding(
                padding: const EdgeInsets.all(SlSpace.page),
                child: UpdateSettingsTile(
                  updates: updates,
                  openUrl: (url) async => opened.add(url),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  UpdateService service(AppController app, {String? executable, bool Function()? busy}) =>
      UpdateService(app: app, appVersion: '0.4.0', executable: executable, busy: busy);

  testWidgets('nothing is sent while the app starts; the first check waits and fails quietly', (
    tester,
  ) async {
    final app = memoryApp();
    // The real scheduler and the real GitHub endpoint, behind NoNetwork.
    final updates = service(app)..start();
    await show(tester, updates);
    expect(find.text('Not checked yet.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(network.created, isEmpty, reason: 'no HttpClient during startup');

    // A minute after launch the check runs; the network is not there.
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(network.created, hasLength(1));
    expect(find.byKey(const ValueKey('update-banner')), findsNothing);
    expect(find.textContaining('No update found.'), findsOneWidget);
    expect(find.textContaining('Last checked'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The next one is a day later; disposing cancels it.
    await tester.pump(const Duration(hours: 23));
    expect(network.created, hasLength(1));
    updates.dispose();
  });

  testWidgets('with automatic checks off nothing is sent until the user asks', (tester) async {
    final app = memoryApp({UpdateService.autoCheckKey: 'false'});
    final updates = service(app)..start();
    await show(tester, updates);
    expect(
      find.textContaining('api.github.com'),
      findsOneWidget,
      reason: 'says it contacts GitHub',
    );
    final toggle = tester.widget<SwitchListTile>(find.byKey(const ValueKey('update-auto-check')));
    expect(toggle.value, isFalse);
    await tester.pump(const Duration(days: 2));
    expect(network.created, isEmpty);

    await tester.tap(find.byKey(const ValueKey('update-check-now')));
    await tester.pump();
    await tester.pump();
    expect(network.created, hasLength(1));
    expect(find.textContaining('No update found.'), findsOneWidget);

    // Turning it on schedules the daily check (the start delay is over).
    await tester.tap(find.byKey(const ValueKey('update-auto-check')));
    await tester.pump();
    expect(app.setting(UpdateService.autoCheckKey, ''), 'true');
    await tester.pump(const Duration(hours: 25));
    await tester.pump();
    expect(network.created, hasLength(2));
    updates.dispose();
  });

  testWidgets('an update found earlier shows in the banner and in Settings', (tester) async {
    final app = memoryApp({UpdateService.releaseKey: _cached()});
    final updates = service(app);
    addTearDown(updates.dispose);
    await show(tester, updates);
    expect(find.text('TingLang 0.5.0 is available.'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('update-install')), findsOneWidget);
    expect(find.byKey(const ValueKey('update-settings-install')), findsOneWidget);
    expect(find.text('You have TingLang 0.4.0.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('update-whats-new')));
    await tester.pump();
    expect(opened, [Uri.parse('https://github.com/eeeease/TingLang/releases/tag/v0.5.0')]);

    await tester.tap(find.byKey(const ValueKey('update-later')));
    await tester.pump();
    expect(find.byKey(const ValueKey('update-banner')), findsNothing);
    expect(find.byKey(const ValueKey('update-settings-install')), findsOneWidget);
    expect(network.created, isEmpty);
  });

  testWidgets('an app macOS runs from a temporary copy is told to use the release page', (
    tester,
  ) async {
    final app = memoryApp({UpdateService.releaseKey: _cached()});
    final updates = service(app, executable: _translocated);
    addTearDown(updates.dispose);
    await show(tester, updates);
    await tester.tap(find.byKey(const ValueKey('update-install')));
    await tester.pump();
    await tester.pump();
    expect(updates.failure?.problem, UpdateProblem.translocated);
    expect(find.textContaining('temporary copy'), findsOneWidget);
    expect(find.byKey(const ValueKey('update-retry')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('update-open-release')));
    await tester.pump();
    expect(opened.single.path, '/eeeease/TingLang/releases/tag/v0.5.0');
    expect(network.created, isEmpty, reason: 'refused before downloading');
  });

  testWidgets('during a recording the banner says to finish it first', (tester) async {
    final app = memoryApp({UpdateService.releaseKey: _cached()});
    final updates = service(app, busy: () => true);
    addTearDown(updates.dispose);
    await show(tester, updates);
    await tester.tap(find.byKey(const ValueKey('update-settings-install')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Finish or save your recording first, then update.'), findsOneWidget);
    expect(find.byKey(const ValueKey('update-retry')), findsOneWidget);
    expect(network.created, isEmpty);
  });

  testWidgets('the download shows its progress and can be cancelled', (tester) async {
    final app = memoryApp({UpdateService.releaseKey: _cached()});
    final updates = _Downloading(app);
    addTearDown(updates.dispose);
    await show(tester, updates);
    expect(find.text('Downloading TingLang 0.5.0… 42%'), findsOneWidget);
    expect(
      tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('update-progress'))).value,
      .42,
    );
    expect(find.byKey(const ValueKey('update-install')), findsNothing);
    final check = tester.widget<OutlinedButton>(find.byKey(const ValueKey('update-check-now')));
    expect(check.onPressed, isNull, reason: 'no check during a download');
    await tester.tap(find.byKey(const ValueKey('update-cancel')));
    expect(updates.cancelled, isTrue);
  });

  testWidgets('in Chinese', (tester) async {
    final app = memoryApp({UpdateService.releaseKey: _cached()});
    final updates = service(app);
    addTearDown(updates.dispose);
    await show(tester, updates, locale: 'zh');
    expect(find.text('听浪 0.5.0 已发布。'), findsNWidgets(2));
    expect(find.text('更新并重新打开'), findsNWidgets(2));
    expect(find.text('自动检查更新'), findsOneWidget);
    expect(find.text('当前版本：听浪 0.4.0。'), findsOneWidget);
    expect(find.text('立即检查'), findsOneWidget);
  });

  Future<void> showBadge(WidgetTester tester, UpdateService updates, {String locale = 'en'}) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: TinglangTheme.light(),
        locale: Locale(locale),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              UpdateBanner(updates: updates, openUrl: (url) async => opened.add(url)),
              UpdateBadge(updates: updates, openUrl: (url) async => opened.add(url)),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('no arrow on the mark without a newer version', (tester) async {
    final app = memoryApp();
    final updates = service(app);
    addTearDown(updates.dispose);
    await showBadge(tester, updates);
    expect(find.byKey(const ValueKey('update-badge')), findsNothing);
  });

  testWidgets('the arrow stays after the banner is put off and opens the update', (tester) async {
    final app = memoryApp({UpdateService.releaseKey: _cached()});
    final updates = service(app);
    addTearDown(updates.dispose);
    await showBadge(tester, updates);
    expect(find.byKey(const ValueKey('update-badge')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('update-later')));
    await tester.pump();
    expect(find.byKey(const ValueKey('update-banner')), findsNothing);
    expect(find.byKey(const ValueKey('update-badge')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('update-badge')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('update-dialog')), findsOneWidget);
    expect(find.text('TingLang 0.5.0 is available'), findsOneWidget);
    expect(find.textContaining('You have 0.4.0.'), findsOneWidget);
    expect(find.byKey(const ValueKey('update-dialog-install')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('update-dialog-whats-new')));
    await tester.pump();
    expect(opened, [Uri.parse('https://github.com/eeeease/TingLang/releases/tag/v0.5.0')]);

    await tester.tap(find.byKey(const ValueKey('update-dialog-later')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('update-dialog')), findsNothing);
    expect(network.created, isEmpty, reason: 'opening the dialog downloads nothing');
  });

  testWidgets('the dialog follows the download and can cancel it', (tester) async {
    final app = memoryApp({UpdateService.releaseKey: _cached()});
    final updates = _Downloading(app);
    addTearDown(updates.dispose);
    await showBadge(tester, updates, locale: 'zh');
    await tester.tap(find.byKey(const ValueKey('update-badge')));
    await tester.pumpAndSettle();
    expect(find.text('听浪 0.5.0 可以更新了'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('update-dialog')),
        matching: find.byKey(const ValueKey('update-progress')),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('update-dialog-install')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('update-dialog-cancel')));
    expect(updates.cancelled, isTrue);
  });
}

/// A download in progress, for the banner's looks.
final class _Downloading extends UpdateService {
  _Downloading(AppController app) : super(app: app, appVersion: '0.4.0');
  bool cancelled = false;

  @override
  UpdateStage get stage => UpdateStage.downloading;

  @override
  double get progress => .42;

  @override
  void cancel() => cancelled = true;
}
