import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tinglang_native/tinglang_native.dart';

import '../core/share_package.dart';
import 'app_controller.dart';
import 'live_controller.dart';
import 'panel_settings.dart';
import 'transcription_controller.dart';
import 'voice_memos.dart';

/// Where the main window should go when the panel opens it.
sealed class ShellRequest {
  const ShellRequest();
}

final class OpenHistory extends ShellRequest {
  const OpenHistory();
}

final class OpenSettings extends ShellRequest {
  const OpenSettings({this.speech = false});

  /// Open the Speech recognition tab (a setup the panel asked for).
  final bool speech;
}

/// History with the Voice Memos list open.
final class OpenVoiceMemos extends ShellRequest {
  const OpenVoiceMemos();
}

final class OpenSession extends ShellRequest {
  const OpenSession(this.sessionId, {this.makeCourse = false});
  final String sessionId;
  final bool makeCourse;
}

/// `.tinglang` files to import, oldest first (opened from Finder or the
/// Dock, or dropped on the panel or the window).
final class ImportPackages extends ShellRequest {
  const ImportPackages(this.paths);
  final List<String> paths;
}

/// What the floating panel's buttons do outside live captions: open the main
/// window, import dropped files, remember the look and the audio source, and
/// keep its language and counters in step with the settings.
class PanelCoordinator {
  PanelCoordinator({
    required this.app,
    required this.live,
    required this.transcription,
    required this.navigation,
    this.shell,
    this.voiceMemos,
    this.languageName = _identity,
  });

  final AppController app;
  final LiveController live;
  final TranscriptionController transcription;
  final DesktopShell? shell;

  /// Today's new recordings show as a chip on the panel.
  final VoiceMemoService? voiceMemos;

  /// The main window consumes and clears requests.
  final ValueNotifier<ShellRequest?> navigation;
  final String Function(String code) languageName;
  String? _locale, _theme;
  bool? _shown;
  StreamSubscription<void>? _opened;

  static String _identity(String code) => code;

  bool get panelWanted => app.setting(PanelKeys.visible, 'true') == 'true';

  Future<void> start() async {
    live
      ..requestBuilder = (() => liveRequestFrom(app))
      ..onPanelEvent = handle;
    app.addListener(_onSettings);
    voiceMemos?.addListener(_onMemos);
    await _refresh(force: true);
    // Files opened from Finder or the Dock, also those that arrived while the
    // app was starting (the shell keeps them until asked).
    _opened = shell?.filesOpened.listen((_) => unawaited(_takeOpenedFiles()));
    await _takeOpenedFiles();
  }

  Future<void> _takeOpenedFiles() async {
    final paths = await shell?.takeOpenedFiles() ?? const <String>[];
    if (paths.isNotEmpty) await handle(OverlayFilesDropped(paths, mainWindow: true));
  }

  void _onSettings() => unawaited(_refresh());

  void _onMemos() => live.setPanelCounts(recordings: voiceMemos?.fresh.length ?? 0);

  /// Follows the settings: counts always; the window appearance when the
  /// theme changes; the panel's strings and visibility when the interface
  /// language or the "show panel" switch changes.
  Future<void> _refresh({bool force = false}) async {
    final l = localizationsFor(app);
    live
      ..panelText = L10nPanelText(l, languageName: languageName)
      ..setPanelCounts(due: app.due.length);
    final theme = app.setting(AppController.themeKey, 'system');
    if (force || theme != _theme) {
      _theme = theme;
      await shell?.setAppearance(switch (theme) {
        'light' => ShellAppearance.light,
        'dark' => ShellAppearance.dark,
        _ => ShellAppearance.system,
      });
    }
    final wanted = panelWanted;
    if (!force && l.localeName == _locale && wanted == _shown) {
      // A look changed in Settings (layout, lines kept for scrolling back).
      final style = captionStyleFrom(app);
      if (style != live.panelStyle) await live.applyPanelStyle(style);
      return;
    }
    _locale = l.localeName;
    _shown = wanted;
    if (wanted) {
      await live.showPanel(captionStyleFrom(app), panelStrings(l));
    } else {
      live.preparePanel(captionStyleFrom(app), panelStrings(l));
      if (live.panelVisible) await live.hidePanel();
    }
  }

  Future<void> handle(OverlayEvent event) async {
    switch (event) {
      case OverlayActionRequested(action: OverlayAction.openHistory):
        await _open(const OpenHistory());
      case OverlayActionRequested(action: OverlayAction.showRecordings):
        await _open(voiceMemos == null ? const OpenHistory() : const OpenVoiceMemos());
      case OverlayActionRequested(action: OverlayAction.openSettings):
        // A refused capture permission is allowed in System Settings.
        if (live.setupNeed case CapturePermissionNeeded(:final permission)) {
          await shell?.openSystemSettings(
            permission == PermissionKind.microphone
                ? SystemSettingsPane.microphone
                : SystemSettingsPane.screenRecording,
          );
          return;
        }
        await _open(OpenSettings(speech: isSpeechSettingsNeed(live.setupNeed)));
      case OverlayActionRequested(action: OverlayAction.openSession, value: final id?):
        await _open(OpenSession(id));
      case OverlayActionRequested(action: OverlayAction.makeCourse, value: final id?):
        await _open(OpenSession(id, makeCourse: true));
      case OverlayActionRequested(action: OverlayAction.useSystemAudio):
        await app.setSetting(liveSourceKey, 'system');
      case OverlayActionRequested(action: OverlayAction.useMicrophone):
        await app.setSetting(liveSourceKey, 'microphone');
      case OverlayActionRequested(action: OverlayAction.hide):
        // The panel has already hidden itself.
        _shown = false;
        live.panelVisible = false;
        await app.setSetting(PanelKeys.visible, 'false');
      case OverlayActionRequested(action: OverlayAction.show):
        _shown = true;
        await app.setSetting(PanelKeys.visible, 'true');
        await live.showPanel(captionStyleFrom(app), panelStrings(localizationsFor(app)));
      case OverlayActionRequested(action: OverlayAction.unlock):
        await _saveStyle(live.panelStyle.copyWith(clickThrough: false));
      case OverlayActionRequested(action: OverlayAction.quit):
        if (live.isActive) await live.stop();
        await ServicesBinding.instance.exitApplication(AppExitType.cancelable);
      case OverlayFilesDropped(:final paths, :final mainWindow):
        // Share files go through the import flow in the main window.
        final packages = [
          for (final path in paths)
            if (_extension(path) == SharePackage.extension) path,
        ];
        if (packages.isNotEmpty) {
          final waiting = navigation.value;
          await _open(
            ImportPackages([if (waiting is ImportPackages) ...waiting.paths, ...packages]),
          );
        }
        final files = [
          for (final path in paths)
            if (TranscriptionController.extensions.contains(_extension(path))) File(path),
        ];
        for (final file in files) {
          await transcribeMedia(app, transcription, file);
        }
        // On the main window, show where the progress is.
        if (mainWindow && files.isNotEmpty && packages.isEmpty) {
          navigation.value = const OpenHistory();
        }
        final text = live.panelText;
        if (text != null && files.isNotEmpty) live.showNotice(text.importing(files.length));
      case OverlayStyleChanged(:final style):
        await _saveStyle(style);
      case OverlayActionRequested():
      case OverlayClosedByUser():
      case OverlayMoved():
        break;
    }
  }

  Future<void> _saveStyle(CaptionStyle style) async {
    await app.setSettings(captionStyleSettings(style));
    // As read back from the settings, so Settings and the panel agree.
    await live.applyPanelStyle(captionStyleFrom(app));
  }

  Future<void> _open(ShellRequest request) async {
    navigation.value = request;
    await shell?.showMainWindow();
  }

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    return dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
  }

  void dispose() {
    unawaited(_opened?.cancel());
    app.removeListener(_onSettings);
    voiceMemos?.removeListener(_onMemos);
  }
}
