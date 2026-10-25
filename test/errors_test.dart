import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/l10n/app_localizations.dart';
import 'package:tinglang/services/transcription_controller.dart';
import 'package:tinglang/ui/errors.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final zh = lookupAppLocalizations(const Locale('zh'));

  test('a missing file-dialog entitlement reads as an action, not a code', () {
    final error = PlatformException(
      code: 'ENTITLEMENT_NOT_FOUND',
      message: 'Either the Read-Only or Read/Write entitlement is required for this action.',
    );
    expect(describeError(en, error), en.errorFileDialog);
    expect(describeError(zh, error), isNot(contains('ENTITLEMENT')));
  });

  test('import problems are localised with the offending extension', () {
    expect(
      describeError(zh, const ImportFailure(ImportProblem.unsupportedFormat, 'mkv')),
      zh.errorUnsupportedFormat('mkv'),
    );
    expect(describeError(en, const ImportFailure(ImportProblem.noAudio)), en.errorNoAudio);
  });

  test('Dart exception prefixes never reach the screen', () {
    for (final error in <Object>[
      const FormatException('Course JSON is too large'),
      StateError('Course JSON is too large'),
      const FileSystemException('Course JSON is too large'),
    ]) {
      final text = describeError(en, error);
      expect(text, contains('Course JSON is too large'));
      expect(text, isNot(contains('Exception')));
      expect(text, isNot(contains('Bad state')));
    }
    expect(describeError(en, const PathNotFoundException('/x', OSError())), en.errorFileMissing);
  });
}
