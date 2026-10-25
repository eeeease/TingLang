import 'dart:io';

import 'package:flutter/material.dart';

import '../core/library_store.dart';
import '../core/live_repository.dart';
import '../core/models.dart';
import '../core/share_package.dart';
import '../services/app_controller.dart';
import 'brand.dart';
import 'file_picking.dart';

/// Lets the user pick a `.tinglang` file and imports it: a recording lands
/// under History, a course in the library (keeping learner records if the
/// same course was imported before).
Future<void> importSharedFile(
  BuildContext context, {
  required AppController app,
  required LiveRepository repository,
  required void Function(String sessionId) onSession,
  required void Function(Course course) onCourse,
}) => reportAction(context, () async {
  final path = await pickFile(const [
    SharePackage.extension,
  ], dialogTitle: context.l10n.importShared);
  if (path == null || !context.mounted) return;
  await _importShared(
    context,
    path,
    app: app,
    repository: repository,
    onSession: onSession,
    onCourse: onCourse,
  );
});

/// Imports a `.tinglang` file the user opened from Finder (a double-click,
/// Open With, a drop on the Dock icon or the window), with the same
/// confirmation and messages as importing it from the library.
Future<void> importSharedPath(
  BuildContext context,
  String path, {
  required AppController app,
  required LiveRepository repository,
  required void Function(String sessionId) onSession,
  required void Function(Course course) onCourse,
}) => reportAction(
  context,
  () => _importShared(
    context,
    path,
    app: app,
    repository: repository,
    onSession: onSession,
    onCourse: onCourse,
  ),
);

Future<void> _importShared(
  BuildContext context,
  String path, {
  required AppController app,
  required LiveRepository repository,
  required void Function(String sessionId) onSession,
  required void Function(Course course) onCourse,
}) async {
  final l = context.l10n;
  final item = await importSharePackage(
    File(path),
    repository: repository,
    store: app.store,
    fallbackLanguage: app.setting(AppController.learningLanguageKey, 'en'),
  );
  if (!context.mounted) return;
  switch (item) {
    case SharedSession(:final sessionId):
      onSession(sessionId);
    case SharedCourse(:final course):
      final exists = app.state.courses.any((c) => c.id == course.id);
      if (exists) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.updateCourseTitle),
            content: Text(l.updateCourseBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.updateContent),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
      await app.upsertCourse(course);
      onCourse(course);
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.sharedImported)));
  }
}

String _fileName(String title) =>
    '${title.trim().isEmpty ? 'tinglang' : title.trim().replaceAll(RegExp(r'[/:\\]'), '-')}'
    '.${SharePackage.extension}';

/// Saves a recording (transcript, translations, media) as a `.tinglang` file.
Future<void> exportSessionShare(
  BuildContext context, {
  required LiveRepository repository,
  required LibraryStore store,
  required String sessionId,
  required String title,
}) => reportAction(context, () async {
  final l = context.l10n;
  final destination = await pickSaveLocation(
    dialogTitle: l.exportShared,
    fileName: _fileName(title),
    extensions: const [SharePackage.extension],
  );
  if (destination == null) return;
  await exportSessionPackage(
    repository: repository,
    store: store,
    sessionId: sessionId,
    title: title,
    destination: destination,
  );
  if (context.mounted) _saved(context);
});

/// Saves a course (and its media) as a `.tinglang` file.
Future<void> exportCourseShare(
  BuildContext context, {
  required Course course,
  required LibraryStore store,
}) => reportAction(context, () async {
  final l = context.l10n;
  final destination = await pickSaveLocation(
    dialogTitle: l.exportShared,
    fileName: _fileName(course.title),
    extensions: const [SharePackage.extension],
  );
  if (destination == null) return;
  await exportCoursePackage(course: course, store: store, destination: destination);
  if (context.mounted) _saved(context);
});

void _saved(BuildContext context) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.sharedExported)));
