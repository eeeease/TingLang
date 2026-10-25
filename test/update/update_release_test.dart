import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/services/update_install.dart';
import 'package:tinglang/services/update_service.dart';

void main() {
  ReleaseVersion v(String text) => ReleaseVersion.tryParse(text)!;

  group('versions', () {
    test('compare number by number, with or without a leading v', () {
      expect(v('0.10.0') > v('0.9.0'), isTrue);
      expect(v('v1.0.0') > v('0.99.99'), isTrue);
      expect(v('0.4.1') > v('0.4.0'), isTrue);
      expect(v('0.4.0') > v('0.4.0'), isFalse);
      expect(v('v0.4.0'), v('0.4.0'));
      expect(v('0.9.0') > v('0.10.0'), isFalse);
      expect([v('0.10.0'), v('0.2.0'), v('0.9.1')]..sort(), [v('0.2.0'), v('0.9.1'), v('0.10.0')]);
      expect('${v('v2.3.4')}', '2.3.4');
    });

    test('anything but X.Y.Z is no version', () {
      for (final text in [
        '',
        '1.2',
        '1.2.3.4',
        'v1.2.3-rc1',
        '1.2.3+4',
        'latest',
        'V1.2.3',
        '1.2.x',
      ]) {
        expect(ReleaseVersion.tryParse(text), isNull, reason: text);
      }
    });
  });

  group('GitHub release JSON', () {
    final endpoints = UpdateEndpoints.gitHub;
    Map<String, Object?> release({
      String tag = 'v0.5.0',
      Object? draft = false,
      Object? prerelease = false,
      List<Object?>? assets,
    }) => {
      'tag_name': tag,
      'draft': draft,
      'prerelease': prerelease,
      'html_url': 'https://evil.example/not-used',
      'assets':
          assets ??
          [
            {
              'name': 'Tinglang-0.5.0-macOS.zip',
              'state': 'uploaded',
              'size': 48000000,
              'browser_download_url': 'https://github.com/eeeease/TingLang/releases/download/v0.5.0/Tinglang-0.5.0-macOS.zip',
            },
            {
              'name': 'Tinglang-0.5.0-macOS.zip.sha256',
              'state': 'uploaded',
              'size': 91,
              'browser_download_url': 'https://github.com/eeeease/TingLang/releases/download/v0.5.0/Tinglang-0.5.0-macOS.zip.sha256',
            },
            {'name': 'notes.txt', 'size': 3, 'browser_download_url': 'https://evil.example/x'},
          ],
    };

    test('a published release with both files', () {
      final r = UpdateRelease.fromGitHub(release(), endpoints)!;
      expect(r.version, v('0.5.0'));
      expect(r.tag, 'v0.5.0');
      expect(r.archive.name, 'Tinglang-0.5.0-macOS.zip');
      expect(r.archive.size, 48000000);
      expect(r.archive.url.host, 'github.com');
      expect(r.checksum.name, 'Tinglang-0.5.0-macOS.zip.sha256');
      expect(r.checksum.size, 91);
      // The page is built from the repository, never taken from the answer.
      expect('${r.page}', 'https://github.com/eeeease/TingLang/releases/tag/v0.5.0');
      // The settings cache reads back the same release.
      final again = UpdateRelease.fromJson(r.toJson(), endpoints)!;
      expect(again.version, r.version);
      expect(again.archive.url, r.archive.url);
      expect(again.checksum.size, r.checksum.size);
    });

    test('drafts, prereleases and odd tags are ignored', () {
      expect(UpdateRelease.fromGitHub(release(draft: true), endpoints), isNull);
      expect(UpdateRelease.fromGitHub(release(prerelease: true), endpoints), isNull);
      expect(UpdateRelease.fromGitHub(release(draft: null), endpoints), isNull);
      expect(UpdateRelease.fromGitHub(release(tag: '0.5.0'), endpoints), isNull);
      expect(UpdateRelease.fromGitHub(release(tag: 'v0.5.0-beta'), endpoints), isNull);
      // The files must carry the tag's version.
      expect(UpdateRelease.fromGitHub(release(tag: 'v0.6.0'), endpoints), isNull);
    });

    test('missing files, bad sizes and addresses outside GitHub are refused', () {
      Map<String, Object?> asset(String name, {Object? size = 100, String? url, String? state}) => {
        'name': name,
        'size': size,
        'state': ?state,
        'browser_download_url':
            url ?? 'https://github.com/eeeease/TingLang/releases/download/v0.5.0/$name',
      };
      const zip = 'Tinglang-0.5.0-macOS.zip';
      UpdateRelease? read(List<Object?> assets) =>
          UpdateRelease.fromGitHub(release(assets: assets), endpoints);
      expect(read([asset(zip), asset('$zip.sha256')]), isNotNull);
      expect(read([asset(zip)]), isNull, reason: 'no checksum file');
      expect(read([asset('$zip.sha256')]), isNull, reason: 'no archive');
      expect(read([asset(zip, size: 0), asset('$zip.sha256')]), isNull);
      expect(read([asset(zip, size: '100'), asset('$zip.sha256')]), isNull);
      expect(read([asset(zip, size: 3 * 1024 * 1024 * 1024), asset('$zip.sha256')]), isNull);
      expect(read([asset(zip), asset('$zip.sha256', size: 100000)]), isNull);
      expect(read([asset(zip, state: 'starter'), asset('$zip.sha256')]), isNull);
      expect(
        read([asset(zip, url: 'http://github.com/x.zip'), asset('$zip.sha256')]),
        isNull,
        reason: 'plain http',
      );
      expect(read([asset(zip, url: 'https://evil.example/x.zip'), asset('$zip.sha256')]), isNull);
      expect(UpdateRelease.fromGitHub('not a map', endpoints), isNull);
      expect(UpdateRelease.fromGitHub({'tag_name': 'v0.5.0'}, endpoints), isNull);
    });
  });

  test('downloads only from https on github.com and *.githubusercontent.com', () {
    bool ok(String url) => UpdateEndpoints.isGitHubDownload(Uri.parse(url));
    expect(ok('https://github.com/eeeease/TingLang/releases/download/v1.0.0/a.zip'), isTrue);
    expect(ok('https://objects.githubusercontent.com/github-production-release-asset/1'), isTrue);
    expect(ok('https://release-assets.githubusercontent.com/github-production/1?sig=x'), isTrue);
    expect(ok('https://GitHub.com/a'), isTrue);
    expect(ok('https://github.com:443/a'), isTrue);
    expect(ok('http://github.com/a'), isFalse);
    expect(ok('https://github.com:8443/a'), isFalse);
    expect(ok('https://user:secret@github.com/a'), isFalse);
    expect(ok('https://evilgithub.com/a'), isFalse);
    expect(ok('https://github.com.evil.example/a'), isFalse);
    expect(ok('https://githubusercontent.com.evil.example/a'), isFalse);
    expect(ok('https://githubusercontent.com/a'), isFalse);
    expect(ok('https://api.github.com/a'), isFalse);
    expect(ok('ftp://github.com/a'), isFalse);
    expect(ok('file:///etc/passwd'), isFalse);

    final gitHub = UpdateEndpoints.gitHub;
    expect(
      gitHub.latestRelease.toString(),
      'https://api.github.com/repos/eeeease/TingLang/releases/latest',
    );
    expect(gitHub.allowsApi(gitHub.latestRelease), isTrue);
    expect(gitHub.allowsApi(Uri.parse('https://github.com/x')), isFalse);
    expect(gitHub.allowsApi(Uri.parse('http://api.github.com/x')), isFalse);
    // Loopback stands in for GitHub only when a test asks for it.
    expect(gitHub.allowsDownload(Uri.parse('http://127.0.0.1:8080/x')), isFalse);
    final test = UpdateEndpoints(latestRelease: gitHub.latestRelease, allowLoopback: true);
    expect(test.allowsDownload(Uri.parse('http://127.0.0.1:8080/x')), isTrue);
    expect(test.allowsDownload(Uri.parse('http://localhost:8080/x')), isFalse);
  });

  test('checksum files are read as shasum -a 256 writes them', () {
    final hash = 'ab' * 32;
    expect(
      parseChecksumFile('$hash  Tinglang-0.5.0-macOS.zip\n', 'Tinglang-0.5.0-macOS.zip'),
      hash,
    );
    expect(parseChecksumFile('${hash.toUpperCase()}\n', 'x.zip'), hash);
    expect(parseChecksumFile('$hash *x.zip', 'x.zip'), hash);
    expect(parseChecksumFile('$hash  other.zip', 'x.zip'), isNull);
    expect(parseChecksumFile('abc  x.zip', 'x.zip'), isNull);
    expect(parseChecksumFile('', 'x.zip'), isNull);
    expect(parseChecksumFile('<html>Not Found</html>', 'x.zip'), isNull);
  });

  group('the installed app', () {
    test('is found from the executable inside its bundle', () {
      expect(
        bundleOfExecutable('/Applications/Tinglang.app/Contents/MacOS/Tinglang'),
        '/Applications/Tinglang.app',
      );
      expect(
        bundleOfExecutable('/Users/me/Apps/TingLang 2.app/Contents/MacOS/Tinglang'),
        '/Users/me/Apps/TingLang 2.app',
      );
      expect(bundleOfExecutable('/usr/local/bin/flutter_tester'), isNull);
      expect(bundleOfExecutable('/Applications/Tinglang.app/Contents/Frameworks/x'), isNull);
      expect(bundleOfExecutable('Tinglang.app/Contents/MacOS/Tinglang'), isNull);
    });

    test('a write error says whether the disk is read-only', () {
      FileSystemException error(int code) =>
          FileSystemException('Cannot create file', '/Volumes/x/probe', OSError('e', code));
      expect(problemForWriteError(error(30)), UpdateProblem.readOnly);
      expect(problemForWriteError(error(13)), UpdateProblem.notWritable);
      expect(problemForWriteError(error(1)), UpdateProblem.notWritable);
      expect(problemForWriteError(const FileSystemException('x')), UpdateProblem.notWritable);
    });

    test('problems that only the release page can solve', () {
      expect(
        {
          for (final problem in UpdateProblem.values)
            if (problem.needsReleasePage) problem,
        },
        {
          UpdateProblem.notBundle,
          UpdateProblem.translocated,
          UpdateProblem.readOnly,
          UpdateProblem.notWritable,
          UpdateProblem.badPackage,
          UpdateProblem.install,
        },
      );
    });
  });

  group('the install script', () {
    final script = updateInstallScript();

    test('takes every path as a parameter', () {
      final args = updateScriptArguments(
        appPid: 4242,
        target: '/Applications/Tinglang.app',
        staged: '/Applications/.tinglang-update-1',
        backup: '/Applications/.tinglang-old-1',
        work: '/tmp/w',
        quitTimeout: const Duration(minutes: 2),
        opener: '/usr/bin/open',
        log: '/tmp/l.log',
      );
      expect(args, [
        '4242',
        '/Applications/Tinglang.app',
        '/Applications/.tinglang-update-1',
        '/Applications/.tinglang-old-1',
        '/tmp/w',
        '120',
        '/usr/bin/open',
        '/tmp/l.log',
      ]);
      expect(script, isNot(contains('/Applications')));
      expect(script, contains(r'pid="$1"; target="$2"; staged="$3"; backup="$4"; work="$5"'));
      // Paths are only ever used in double quotes.
      for (final line in script.split('\n')) {
        final bare = [
          for (final (i, part) in line.split('"').indexed)
            if (i.isEven) part,
        ];
        for (final name in ['target', 'staged', 'backup', 'work', 'opener', 'log']) {
          if (bare.any((part) => part.contains('\$$name'))) fail('unquoted \$$name: $line');
        }
      }
    });

    test('waits for the app, swaps, clears quarantine, relaunches, then deletes the old app', () {
      int at(String text) {
        final i = script.indexOf(text);
        expect(i, isNonNegative, reason: text);
        return i;
      }

      final wait = at(r'while kill -0 "$pid"');
      final aside = at(r'mv "$target" "$backup"');
      final inPlace = at(r'mv "$staged" "$target"');
      final rollback = at(r'mv "$backup" "$target"');
      final quarantine = at(r'xattr -dr com.apple.quarantine "$target"');
      final relaunch = at(r'if ! "$opener" "$target"');
      final deleteOld = at(r'rm -rf "$backup" "$work"');
      expect(wait < aside && aside < inPlace && inPlace < rollback, isTrue);
      expect(rollback < quarantine && quarantine < relaunch && relaunch < deleteOld, isTrue);
      // The old app is deleted in one place only: after the new one opened.
      expect(RegExp(r'rm -rf[^\n]*"\$backup"').allMatches(script), hasLength(1));
      // Gives up without touching anything when the app does not quit.
      expect(script, contains(r'-gt $((wait_s * 10))'));
      expect(script, isNot(contains('sudo')));
    });
  });
}
