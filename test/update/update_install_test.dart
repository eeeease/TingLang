// Downloads come from a loopback server; the "installed app" is a fake
// bundle in a temporary folder. The install script runs only against those
// fake folders, never against a real app, and opens nothing.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show AppExitResponse;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/update_install.dart';
import 'package:tinglang/services/update_service.dart';

import 'update_fakes.dart';

void main() {
  late FakeGitHub github;
  late Directory temp, works;
  late String folder, installed, executable;
  late AppController app;
  late List<List<String>> started;
  late int stopped, quits;
  late AppExitResponse quitAnswer;
  late bool Function() busy;

  setUp(() async {
    github = FakeGitHub();
    await github.start();
    temp = await Directory.systemTemp.createTemp('tinglang-update-install-');
    works = await Directory(p.join(temp.path, 'work')).create();
    folder = p.join(temp.path, 'Applications');
    installed = await fakeBundle(folder, version: '0.4.0');
    executable = p.join(installed, 'Contents', 'MacOS', 'Tinglang');
    app = memoryApp();
    started = [];
    stopped = 0;
    quits = 0;
    quitAnswer = AppExitResponse.exit;
    busy = () => false;
  });
  tearDown(() async {
    await github.close();
    await Process.run('/bin/chmod', ['-R', 'u+w', temp.path]);
    await temp.delete(recursive: true);
  });

  /// Publishes [version] built as a fake bundle and zipped like the release
  /// workflow does.
  Future<List<int>> publish(
    String version, {
    String? bundleVersion,
    String bundleId = 'dev.eeeease.tinglang',
    String? checksumLine,
    int? listedSize,
  }) async {
    final build = await Directory(p.join(temp.path, 'build-$version')).create();
    final bundle = await fakeBundle(
      build.path,
      version: bundleVersion ?? version,
      bundleId: bundleId,
    );
    final zip = await zipBundle(bundle, build.path);
    github.publish(version, zip, checksumLine: checksumLine, listedSize: listedSize);
    return zip;
  }

  UpdateService service({String? exe}) {
    final updates = UpdateService(
      app: app,
      appVersion: '0.4.0',
      endpoints: github.endpoints,
      executable: exe ?? executable,
      workFolder: () => works.createTemp('w-'),
      startDetached: (program, arguments) async {
        started.add([program, ...arguments]);
        return () => stopped++;
      },
      quit: () async {
        quits++;
        return quitAnswer;
      },
      busy: () => busy(),
      timer: FakeTimers().call,
      logFile: p.join(temp.path, 'update.log'),
    );
    addTearDown(updates.dispose);
    return updates;
  }

  Future<UpdateService> checked({String? exe}) async {
    final updates = service(exe: exe);
    await updates.checkNow();
    expect(updates.available, isNotNull);
    return updates;
  }

  Future<String?> versionOf(String bundle) =>
      plistValue(p.join(bundle, 'Contents', 'Info.plist'), 'CFBundleShortVersionString');

  List<String> leftovers() => [
    for (final entry in Directory(folder).listSync())
      if (p.basename(entry.path).startsWith('.')) p.basename(entry.path),
  ];

  /// Nothing was handed over: no script, no quit, the old app as it was,
  /// no download left behind.
  Future<void> expectNothingChanged() async {
    expect(started, isEmpty);
    expect(quits, 0);
    expect(await versionOf(installed), '0.4.0');
    expect(leftovers(), isEmpty);
    expect(works.listSync(), isEmpty, reason: 'the download folder is deleted');
  }

  test('downloads, verifies, stages the new app and hands over to the script', () async {
    await publish('0.5.0');
    final updates = await checked();
    final stages = <UpdateStage>[];
    updates.addListener(() => stages.add(updates.stage));
    await updates.install();

    expect(updates.failure, isNull);
    expect(updates.stage, UpdateStage.restarting);
    expect(stages, containsAllInOrder([UpdateStage.downloading, UpdateStage.installing]));
    expect(updates.progress, 1);
    expect(quits, 1);
    expect(github.paths, [
      FakeGitHub.latestPath,
      '/download/v0.5.0/Tinglang-0.5.0-macOS.zip.sha256',
      '/download/v0.5.0/Tinglang-0.5.0-macOS.zip',
    ]);
    for (final request in github.requests) {
      expect(request.headers.value(HttpHeaders.userAgentHeader), 'Tinglang/0.4.0 (macos)');
      expect(request.headers.value(HttpHeaders.cookieHeader), isNull);
    }

    final command = started.single;
    expect(command.take(4), ['/bin/sh', '-c', updateInstallScript(), 'tinglang-update']);
    final args = command.sublist(4);
    expect(args[0], '$pid');
    expect(args[1], installed);
    final staged = args[2], backup = args[3], work = args[4];
    expect(p.dirname(staged), folder, reason: 'staged next to the app: the swap is a rename');
    expect(p.basename(staged), startsWith('.tinglang-update-'));
    expect(p.dirname(backup), folder);
    expect(File(backup).existsSync() || Directory(backup).existsSync(), isFalse);
    expect(await versionOf(staged), '0.5.0');
    expect(await versionOf(installed), '0.4.0', reason: 'the script swaps them after quitting');
    expect(p.isWithin(works.path, work), isTrue);
    expect(
      Directory(work).listSync(recursive: true).whereType<File>(),
      isEmpty,
      reason: 'the archive is deleted once unpacked',
    );
    expect(args.sublist(5), ['120', '/usr/bin/open', p.join(temp.path, 'update.log')]);

    // Now the script itself, against these fake folders: the "app" has
    // already quit and opening is recorded instead of done.
    final opened = File(p.join(temp.path, 'opened.txt'));
    final result = await _runScript(
      args,
      pid: await _deadPid(),
      opener: await _opener(temp, opened),
    );
    expect(result.exitCode, 0, reason: File(p.join(temp.path, 'update.log')).readAsStringSync());
    expect(await versionOf(installed), '0.5.0');
    expect(leftovers(), isEmpty, reason: 'old app and staged copy are gone');
    expect(Directory(work).existsSync(), isFalse);
    expect(opened.readAsLinesSync(), [installed]);
    expect(File(p.join(temp.path, 'update.log')).readAsStringSync(), contains('updated'));
  });

  test('follows allowed redirects hop by hop and refuses the others', () async {
    final zip = await publish('0.5.0');
    const path = '/download/v0.5.0/Tinglang-0.5.0-macOS.zip';
    github.files['/cdn/blob'] = zip;
    github.redirects[path] = github.url('/cdn/hop');
    github.redirects['/cdn/hop'] = github.url('/cdn/blob');
    var updates = await checked();
    await updates.install();
    expect(updates.failure, isNull);
    expect(github.paths, containsAllInOrder([path, '/cdn/hop', '/cdn/blob']));

    // A hop to anywhere but GitHub is refused before connecting. (First
    // clear away what the successful run handed to the script.)
    started.clear();
    quits = 0;
    for (final entry in Directory(folder).listSync()) {
      if (p.basename(entry.path).startsWith('.')) entry.deleteSync(recursive: true);
    }
    for (final entry in works.listSync()) {
      entry.deleteSync(recursive: true);
    }
    github.redirects['/cdn/hop'] = 'https://evil.example/blob';
    github.requests.clear();
    updates = await checked();
    await updates.install();
    expect(updates.failure?.problem, UpdateProblem.network);
    expect(updates.stage, UpdateStage.failed);
    expect(github.paths.last, '/cdn/hop');
    await expectNothingChanged();
  });

  test('a checksum mismatch is an error and the download is deleted', () async {
    await publish('0.5.0', checksumLine: '${'0' * 64}  Tinglang-0.5.0-macOS.zip\n');
    final updates = await checked();
    await updates.install();
    expect(updates.stage, UpdateStage.failed);
    expect(updates.failure?.problem, UpdateProblem.checksum);
    expect(updates.failure!.problem.needsReleasePage, isFalse, reason: 'retry is offered');
    await expectNothingChanged();
  });

  test('a checksum file that is not one, or a wrong size, is refused too', () async {
    await publish('0.5.0', checksumLine: 'Not Found');
    var updates = await checked();
    await updates.install();
    expect(updates.failure?.problem, UpdateProblem.checksum);
    await expectNothingChanged();

    final zip = await publish('0.5.0');
    for (final size in [zip.length + 1, zip.length - 1]) {
      github.release = github.releaseJson('0.5.0', archiveSize: size);
      updates = await checked();
      await updates.install();
      expect(updates.failure?.problem, UpdateProblem.checksum, reason: 'listed $size');
      await expectNothingChanged();
    }
  });

  test('an archive that is not TingLang of that version is not installed', () async {
    for (final (id, version) in [
      ('com.example.other', '0.5.0'),
      ('dev.eeeease.tinglang', '0.4.9'),
    ]) {
      await publish('0.5.0', bundleId: id, bundleVersion: version);
      final updates = await checked();
      await updates.install();
      expect(updates.failure?.problem, UpdateProblem.badPackage, reason: '$id $version');
      expect(updates.failure!.problem.needsReleasePage, isTrue);
      await expectNothingChanged();
    }
    final garbage = utf8.encode('this is not a zip archive');
    github.publish('0.5.0', garbage);
    final updates = await checked();
    await updates.install();
    expect(updates.failure?.problem, UpdateProblem.badPackage);
    await expectNothingChanged();
  });

  test('a translocated app, or one outside a bundle, is refused before downloading', () async {
    await publish('0.5.0');
    for (final (exe, problem) in [
      (
        '/private/var/folders/ab/xyz/T/AppTranslocation/0B1C/d/Tinglang.app/Contents/MacOS/Tinglang',
        UpdateProblem.translocated,
      ),
      ('/usr/local/bin/flutter_tester', UpdateProblem.notBundle),
    ]) {
      github.requests.clear();
      final updates = await checked(exe: exe);
      await updates.install();
      expect(updates.failure?.problem, problem);
      expect(updates.failure!.problem.needsReleasePage, isTrue);
      expect(github.paths, [FakeGitHub.latestPath], reason: 'nothing downloaded');
      await expectNothingChanged();
    }
  });

  test('a folder the user may not change is refused, naming it', () async {
    await publish('0.5.0');
    await Process.run('/bin/chmod', ['555', folder]);
    github.requests.clear();
    final updates = await checked();
    await updates.install();
    expect(updates.failure?.problem, UpdateProblem.notWritable);
    expect(updates.failure?.detail, folder);
    expect(github.paths, [FakeGitHub.latestPath]);
    await Process.run('/bin/chmod', ['755', folder]);
    await expectNothingChanged();
  });

  test('never quits during a recording', () async {
    await publish('0.5.0');
    busy = () => true;
    var updates = await checked();
    await updates.install();
    expect(updates.failure?.problem, UpdateProblem.busy);
    expect(github.paths, [FakeGitHub.latestPath], reason: 'refused before downloading');
    await expectNothingChanged();

    // A recording that started during the download stops it at the end.
    var calls = 0;
    busy = () => ++calls > 1;
    updates = await checked();
    await updates.install();
    expect(updates.failure?.problem, UpdateProblem.busy);
    await expectNothingChanged();
  });

  test('when the app refuses to quit, the script is stopped and the copy removed', () async {
    await publish('0.5.0');
    quitAnswer = AppExitResponse.cancel;
    final updates = await checked();
    await updates.install();
    expect(updates.failure?.problem, UpdateProblem.quitRefused);
    expect(quits, 1);
    expect(started, hasLength(1));
    expect(stopped, 1);
    expect(await versionOf(installed), '0.4.0');
    expect(leftovers(), isEmpty);
    expect(works.listSync(), isEmpty);
  });

  test('cancel stops the download and keeps nothing', () async {
    final random = Random(7);
    final big = List<int>.generate(2 * 1024 * 1024, (_) => random.nextInt(256));
    github
      ..publish('0.5.0', big)
      ..chunkDelay = const Duration(milliseconds: 15);
    final updates = await checked();
    final installing = updates.install();
    for (var i = 0; i < 400 && updates.progress == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(updates.stage, UpdateStage.downloading);
    expect(updates.progress, greaterThan(0));
    updates.cancel();
    await installing;
    expect(updates.stage, UpdateStage.idle);
    expect(updates.failure, isNull);
    expect(updates.showBanner, isTrue, reason: 'the update is still on offer');
    await expectNothingChanged();
  });

  group('the script, against fake folders', () {
    late String staged, backup, work, log;
    late File opened;
    setUp(() async {
      final next = await fakeBundle(p.join(temp.path, 'next'), version: '0.5.0');
      staged = p.join(folder, '.tinglang-update-1');
      await Directory(next).rename(staged);
      backup = p.join(folder, '.tinglang-old-1');
      work = (await works.createTemp('w-')).path;
      log = p.join(temp.path, 'update.log');
      opened = File(p.join(temp.path, 'opened.txt'));
    });

    List<String> args({Duration timeout = const Duration(seconds: 5)}) => updateScriptArguments(
      appPid: 0,
      target: installed,
      staged: staged,
      backup: backup,
      work: work,
      quitTimeout: timeout,
      opener: '/usr/bin/true',
      log: log,
    );

    test('puts the old app back when the new one does not open', () async {
      final result = await _runScript(args(), pid: await _deadPid(), opener: '/usr/bin/false');
      expect(result.exitCode, 1);
      expect(await versionOf(installed), '0.4.0');
      expect(leftovers(), isEmpty);
      expect(Directory(work).existsSync(), isFalse);
      expect(File(log).readAsStringSync(), contains('putting the old one back'));
    });

    test('changes nothing when the new app is missing', () async {
      await Directory(staged).delete(recursive: true);
      final result = await _runScript(
        args(),
        pid: await _deadPid(),
        opener: await _opener(temp, opened),
      );
      expect(result.exitCode, 1);
      expect(await versionOf(installed), '0.4.0');
      expect(leftovers(), isEmpty);
      expect(opened.readAsLinesSync(), [installed], reason: 'the old app opens again');
    });

    test('gives up without changing anything when the app does not quit', () async {
      final result = await _runScript(
        args(timeout: const Duration(seconds: 1)),
        pid: pid,
        opener: await _opener(temp, opened),
      );
      expect(result.exitCode, 1);
      expect(await versionOf(installed), '0.4.0');
      expect(leftovers(), isEmpty, reason: 'the staged copy is removed');
      expect(Directory(work).existsSync(), isFalse);
      expect(opened.existsSync(), isFalse, reason: 'nothing is opened');
      expect(File(log).readAsStringSync(), contains('did not quit'));
    });
  });
}

/// Runs the install script with [pid] and [opener] in place of the
/// arguments' own.
Future<ProcessResult> _runScript(List<String> args, {required int pid, required String opener}) {
  final patched = [...args]
    ..[0] = '$pid'
    ..[6] = opener;
  return Process.run('/bin/sh', ['-c', updateInstallScript(), 'tinglang-update', ...patched]);
}

/// The id of a process that has exited.
Future<int> _deadPid() async {
  final process = await Process.start('/usr/bin/true', const []);
  await process.exitCode;
  return process.pid;
}

/// A stand-in for `open` that writes the path it was given to [record].
Future<String> _opener(Directory temp, File record) async {
  final path = p.join(temp.path, 'opener.sh');
  await File(path).writeAsString('#!/bin/sh\nprintf \'%s\\n\' "\$1" >> "${record.path}"\n');
  await Process.run('/bin/chmod', ['755', path]);
  return path;
}
