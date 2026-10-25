import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import '../l10n/app_localizations.dart';
import '../services/update_service.dart';
import 'brand.dart';

/// One sentence for a failed update, in the user's words.
String describeUpdateFailure(
  AppLocalizations l,
  UpdateFailure failure, {
  required String version,
}) => switch (failure.problem) {
  UpdateProblem.network => l.updateErrorNetwork,
  UpdateProblem.checksum => l.updateErrorChecksum,
  UpdateProblem.badPackage => l.updateErrorPackage(version),
  UpdateProblem.disk => l.updateErrorDisk,
  UpdateProblem.busy => l.updateErrorBusy,
  UpdateProblem.quitRefused => l.updateErrorQuitRefused,
  UpdateProblem.install => l.updateErrorInstall,
  UpdateProblem.notBundle => l.updateErrorNotBundle,
  UpdateProblem.translocated => l.updateErrorTranslocated,
  UpdateProblem.readOnly => l.updateErrorReadOnly,
  UpdateProblem.notWritable => l.updateErrorNotWritable(failure.detail ?? ''),
};

/// Opens a release page with [openUrl], or `open <url>` without one.
Future<void> _openPage(Uri page, Future<void> Function(Uri url)? openUrl) async {
  if (openUrl != null) return openUrl(page);
  await Process.run('/usr/bin/open', ['$page']);
}

/// What an update is doing, in a sentence (with a progress bar while it
/// downloads or installs); the banner and the update dialog share it.
Widget _stageMessage(AppLocalizations l, UpdateService updates, String version) {
  final failure = updates.failure;
  return switch (updates.stage) {
    UpdateStage.idle => Text(l.updateAvailable(version)),
    UpdateStage.downloading => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.updateDownloading(version, '${(updates.progress * 100).floor()}')),
        const SizedBox(height: SlSpace.xs),
        LinearProgressIndicator(
          key: const ValueKey('update-progress'),
          value: updates.progress,
          minHeight: 3,
        ),
      ],
    ),
    UpdateStage.installing => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.updateInstalling),
        const SizedBox(height: SlSpace.xs),
        const LinearProgressIndicator(key: ValueKey('update-progress'), minHeight: 3),
      ],
    ),
    UpdateStage.restarting => Text(l.updateRestarting),
    UpdateStage.failed => Text(
      failure == null
          ? l.updateAvailable(version)
          : describeUpdateFailure(l, failure, version: version),
      key: const ValueKey('update-error'),
    ),
  };
}

/// A strip for the top of the main window: "TingLang X.Y.Z is available ·
/// What's new · Update and restart", then the download's progress, and
/// what went wrong. Takes no room while there is nothing to show.
/// Self-contained: give it the app's [UpdateService].
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({
    super.key,
    required this.updates,
    this.openUrl,
    this.padding = defaultPadding,
  });

  final UpdateService updates;

  /// Opens the release page in the default browser (`DesktopShell.openUrl`);
  /// defaults to `open <url>`.
  final Future<void> Function(Uri url)? openUrl;

  /// Room around the content; the default leaves the transparent title bar
  /// free, like the recording notice at the top of the window.
  final EdgeInsetsGeometry padding;
  static const defaultPadding = EdgeInsets.fromLTRB(SlSpace.page, 34, SlSpace.page, 10);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updates,
    builder: (context, _) {
      final release = updates.available;
      if (!updates.showBanner || release == null) return const SizedBox.shrink();
      final l = context.l10n;
      final c = context.sl;
      final stage = updates.stage;
      final failure = updates.failure;
      final failed = stage == UpdateStage.failed && failure != null;
      final releasePageOnly = failure?.problem.needsReleasePage ?? false;
      final version = '${release.version}';
      final tone = failed ? c.danger : c.accentInk;
      final compact = ButtonStyle(visualDensity: VisualDensity.compact);
      final message = _stageMessage(l, updates, version);
      final actions = <Widget>[
        if (stage == UpdateStage.idle) ...[
          TextButton(
            key: const ValueKey('update-whats-new'),
            style: compact,
            onPressed: () => reportAction(context, () => _openPage(release.page, openUrl)),
            child: Text(l.updateWhatsNew),
          ),
          FilledButton(
            key: const ValueKey('update-install'),
            style: compact,
            onPressed: () => unawaited(updates.install()),
            child: Text(l.updateInstall),
          ),
        ],
        if (stage == UpdateStage.downloading || stage == UpdateStage.installing)
          TextButton(
            key: const ValueKey('update-cancel'),
            style: compact,
            onPressed: updates.cancel,
            child: Text(l.updateCancel),
          ),
        if (failed && releasePageOnly)
          FilledButton(
            key: const ValueKey('update-open-release'),
            style: compact,
            onPressed: () => reportAction(context, () => _openPage(release.page, openUrl)),
            child: Text(l.updateOpenReleasePage),
          ),
        if (failed && !releasePageOnly)
          FilledButton(
            key: const ValueKey('update-retry'),
            style: compact,
            onPressed: () => unawaited(updates.install()),
            child: Text(l.updateTryAgain),
          ),
        if (stage == UpdateStage.idle || failed)
          IconButton(
            key: const ValueKey('update-later'),
            tooltip: l.updateLater,
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed: updates.dismiss,
            icon: Icon(Icons.close_rounded, color: c.muted),
          ),
      ];
      return Container(
        key: const ValueKey('update-banner'),
        width: double.infinity,
        padding: padding,
        color: (failed ? c.danger : c.accent).withValues(alpha: .08),
        child: Row(
          children: [
            Icon(failed ? Icons.error_outline : Icons.system_update_alt, size: 18, color: tone),
            const SizedBox(width: SlSpace.sm),
            Expanded(
              child: DefaultTextStyle.merge(
                style: SlType.body.copyWith(fontSize: 13, color: c.text),
                child: message,
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(width: SlSpace.md),
              for (final (i, action) in actions.indexed) ...[
                if (i > 0) const SizedBox(width: SlSpace.xs),
                action,
              ],
            ],
          ],
        ),
      );
    },
  );
}

/// A small green arrow on the corner of the sidebar's mark while a newer
/// version is out, also after the banner was put off; pressing it opens
/// [showUpdateDialog]. Takes no room otherwise.
class UpdateBadge extends StatelessWidget {
  const UpdateBadge({super.key, required this.updates, this.openUrl});

  final UpdateService updates;
  final Future<void> Function(Uri url)? openUrl;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updates,
    builder: (context, _) {
      final release = updates.available;
      if (release == null) return const SizedBox.shrink();
      final l = context.l10n;
      final c = context.sl;
      final hint = l.updateBadgeHint('${release.version}');
      return Tooltip(
        message: hint,
        child: Semantics(
          button: true,
          label: hint,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              key: const ValueKey('update-badge'),
              onTap: () => showUpdateDialog(context, updates: updates, openUrl: openUrl),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: c.success,
                  shape: BoxShape.circle,
                  // Cut out of the mark by the sidebar's own colour.
                  border: Border.all(color: c.sidebar, width: 2),
                ),
                child: Icon(Icons.arrow_upward_rounded, size: 12, color: _onSuccess(context)),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// White on the deep green of the light theme, ink on the bright green of
/// the dark one.
Color _onSuccess(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? TinglangBrand.ink : Colors.white;

/// The update as a dialog: the new and the current version, What's new and
/// Update and restart, then the same progress and errors as the banner.
Future<void> showUpdateDialog(
  BuildContext context, {
  required UpdateService updates,
  Future<void> Function(Uri url)? openUrl,
}) => showDialog<void>(
  context: context,
  builder: (_) => UpdateDialog(updates: updates, openUrl: openUrl),
);

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key, required this.updates, this.openUrl});

  final UpdateService updates;
  final Future<void> Function(Uri url)? openUrl;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updates,
    builder: (context, _) {
      final l = context.l10n;
      final c = context.sl;
      final release = updates.available;
      final stage = updates.stage;
      final failure = updates.failure;
      final failed = stage == UpdateStage.failed && failure != null;
      final releasePageOnly = failure?.problem.needsReleasePage ?? false;
      final version = release == null ? '' : '${release.version}';
      final working =
          stage == UpdateStage.downloading ||
          stage == UpdateStage.installing ||
          stage == UpdateStage.restarting;
      return AlertDialog(
        key: const ValueKey('update-dialog'),
        icon: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: c.success, shape: BoxShape.circle),
          child: Icon(Icons.arrow_upward_rounded, color: _onSuccess(context)),
        ),
        title: Text(release == null ? l.updateUpToDate : l.updateDialogTitle(version)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.updateDialogBody(updates.appVersion),
                style: SlType.body.copyWith(color: c.inkSoft),
              ),
              if (release != null && stage != UpdateStage.idle) ...[
                const SizedBox(height: SlSpace.lg),
                DefaultTextStyle.merge(
                  style: SlType.body.copyWith(color: failed ? c.danger : c.text),
                  child: _stageMessage(l, updates, version),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (release != null && !working)
            TextButton(
              key: const ValueKey('update-dialog-whats-new'),
              onPressed: () => reportAction(context, () => _openPage(release.page, openUrl)),
              child: Text(l.updateWhatsNew),
            ),
          if (working && stage != UpdateStage.restarting)
            TextButton(
              key: const ValueKey('update-dialog-cancel'),
              onPressed: updates.cancel,
              child: Text(l.updateCancel),
            )
          else if (!working)
            TextButton(
              key: const ValueKey('update-dialog-later'),
              onPressed: () => Navigator.pop(context),
              child: Text(l.updateLater),
            ),
          if (release != null && failed && releasePageOnly)
            FilledButton(
              key: const ValueKey('update-dialog-open-release'),
              onPressed: () => reportAction(context, () => _openPage(release.page, openUrl)),
              child: Text(l.updateOpenReleasePage),
            )
          else if (release != null && !working)
            FilledButton(
              key: const ValueKey('update-dialog-install'),
              onPressed: () => unawaited(updates.install()),
              child: Text(failed ? l.updateTryAgain : l.updateInstall),
            ),
        ],
      );
    },
  );
}

/// Settings → General: the automatic-check switch (it contacts GitHub),
/// this version, Check now and what the last check found. Self-contained:
/// give it the app's [UpdateService]. With [framed] it is its own panel
/// with a title; without, it fits inside an existing settings group.
class UpdateSettingsTile extends StatelessWidget {
  const UpdateSettingsTile({super.key, required this.updates, this.openUrl, this.framed = true});

  final UpdateService updates;

  /// Opens the release page ("What's new"); defaults to `open <url>`.
  final Future<void> Function(Uri url)? openUrl;
  final bool framed;

  String _status(AppLocalizations l) {
    final release = updates.available;
    final last = updates.lastCheck;
    final found = release != null
        ? l.updateAvailable('${release.version}')
        : switch (updates.lastResult) {
            UpdateCheckResult.upToDate => l.updateUpToDate,
            UpdateCheckResult.unknown || UpdateCheckResult.available => l.updateNoneFound,
            null => last == null ? l.updateNeverChecked : null,
          };
    final when = last == null
        ? null
        : l.updateLastChecked(DateFormat.yMMMd(l.localeName).add_Hm().format(last.toLocal()));
    return [?found, ?when].join(' ');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updates,
    builder: (context, _) {
      final l = context.l10n;
      final c = context.sl;
      final release = updates.available;
      final stage = updates.stage;
      final working =
          stage == UpdateStage.downloading ||
          stage == UpdateStage.installing ||
          stage == UpdateStage.restarting;
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (framed) ...[
            Text(l.updateSettingsTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: SlSpace.sm),
          ],
          SwitchListTile(
            key: const ValueKey('update-auto-check'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.updateAutoCheck, style: SlType.body.copyWith(color: c.text)),
            subtitle: Text(l.updateAutoCheckHelp, style: SlType.caption.copyWith(color: c.muted)),
            value: updates.autoCheck,
            onChanged: (value) => reportAction(context, () => updates.setAutoCheck(value)),
          ),
          const SizedBox(height: SlSpace.sm),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.updateCurrentVersion(updates.appVersion),
                      style: SlType.body.copyWith(color: c.text),
                    ),
                    Text(
                      _status(l),
                      key: const ValueKey('update-status'),
                      style: SlType.caption.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SlSpace.md),
              if (release != null && !working) ...[
                TextButton(
                  key: const ValueKey('update-settings-whats-new'),
                  onPressed: () => reportAction(context, () => _openPage(release.page, openUrl)),
                  child: Text(l.updateWhatsNew),
                ),
                const SizedBox(width: SlSpace.xs),
                FilledButton(
                  key: const ValueKey('update-settings-install'),
                  onPressed: () => unawaited(updates.install()),
                  child: Text(l.updateInstall),
                ),
                const SizedBox(width: SlSpace.sm),
              ],
              OutlinedButton(
                key: const ValueKey('update-check-now'),
                onPressed: updates.checking || working ? null : () => unawaited(updates.checkNow()),
                child: updates.checking
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: SlSpace.sm),
                          Text(l.updateChecking),
                        ],
                      )
                    : Text(l.updateCheckNow),
              ),
            ],
          ),
        ],
      );
      return framed
          ? SlPanel(key: const ValueKey('update-settings'), child: content)
          : KeyedSubtree(key: const ValueKey('update-settings'), child: content);
    },
  );
}
