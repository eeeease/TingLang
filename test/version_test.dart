import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/app.dart';

void main() {
  test('the version shown in the app is the one in pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final version = line.substring('version:'.length).trim().split('+').first;
    expect(appVersion, version);
    // Releases are tagged v<version>; .github/workflows/release.yml checks it.
    expect(appVersion, matches(RegExp(r'^\d+\.\d+\.\d+$')));
  });
}
