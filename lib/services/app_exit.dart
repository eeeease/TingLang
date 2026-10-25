import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:tinglang_native/tinglang_native.dart';

import 'app_controller.dart';
import 'live_controller.dart';
import 'panel_settings.dart';
import 'recording_service.dart';

/// True while quitting would lose work: a recording runs or its attempt is
/// not saved yet. The exit handler and the updater both respect it.
bool exitBlockedByRecording({required AppController app, required RecordingService recorder}) =>
    recorder.navigationLocked || app.pendingAttempt != null;

/// Decides whether the app may quit. It lives outside the widget tree because
/// the main window may never have been opened (the panel is the front door).
/// A refusal is explained in the main window through [notice].
Future<AppExitResponse> handleExitRequest({
  required AppController app,
  required RecordingService recorder,
  required LiveController live,
  required ValueNotifier<String?> notice,
  DesktopShell? shell,
}) async {
  final l = localizationsFor(app);
  if (exitBlockedByRecording(app: app, recorder: recorder)) {
    notice.value = l.exitBlockedRecording;
    await shell?.showMainWindow();
    return AppExitResponse.cancel;
  }
  // Finish the live session so its last captions are saved.
  await live.stop();
  await app.flush();
  if (app.persistenceError != null) {
    notice.value = l.exitBlockedSaveError;
    await shell?.showMainWindow();
    return AppExitResponse.cancel;
  }
  await app.store.close();
  return AppExitResponse.exit;
}
