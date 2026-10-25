import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import '../l10n/app_localizations.dart';
import '../services/sync_service.dart';
import 'brand.dart';
import 'errors.dart';

/// Settings → iCloud Drive sync: the switch (off by default), whether iCloud
/// Drive is there, the folder, the last sync, what is in sync, and anything
/// that was skipped. Self-contained: give it the app's [SyncService].
class SyncPanel extends StatefulWidget {
  const SyncPanel({super.key, required this.sync, this.reveal});
  final SyncService sync;

  /// Opens a folder in Finder; defaults to `open <path>`.
  final Future<void> Function(String path)? reveal;

  @override
  State<SyncPanel> createState() => _SyncPanelState();
}

class _SyncPanelState extends State<SyncPanel> {
  SyncService get sync => widget.sync;

  @override
  void initState() {
    super.initState();
    // Only whether the iCloud Drive folder exists; nothing inside is read
    // while sync is off.
    unawaited(sync.refreshAvailability());
  }

  Future<void> _reveal(BuildContext context) => reportAction(context, () async {
    final path = sync.folder.path;
    final reveal = widget.reveal;
    if (reveal != null) return reveal(path);
    final result = await Process.run('open', [path]);
    if (result.exitCode != 0 && context.mounted) {
      throw StateError(context.l10n.finderFailed('${result.stderr}'.trim()));
    }
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: sync,
    builder: (context, _) {
      final l = context.l10n;
      final c = context.sl;
      final status = sync.status;
      final report = sync.report;
      final on = sync.enabled;
      return SlPanel(
        key: const ValueKey('sync-panel'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(l.syncTitle, style: Theme.of(context).textTheme.titleLarge)),
                // Files leave this Mac (through Apple's iCloud) when it is on.
                SlBadge.cloud(l.syncBadge),
              ],
            ),
            const SizedBox(height: SlSpace.sm),
            Text(l.syncBody, style: SlType.body.copyWith(color: c.inkSoft)),
            const SizedBox(height: SlSpace.md),
            Row(
              children: [
                Expanded(
                  child: Text(l.syncSwitch, style: SlType.body.copyWith(color: c.text)),
                ),
                Switch.adaptive(
                  key: const ValueKey('sync-switch'),
                  value: on,
                  onChanged: (value) => reportAction(context, () => sync.setEnabled(value)),
                ),
              ],
            ),
            const SizedBox(height: SlSpace.sm),
            _status(context, l, status),
            if (on && report != null && report.waiting > 0) ...[
              const SizedBox(height: SlSpace.sm),
              _line(
                context,
                Icons.cloud_download_outlined,
                l.syncWaiting('${report.waiting}'),
                key: const ValueKey('sync-waiting'),
              ),
            ],
            if (on && status != SyncStatus.unavailable) ...[
              const SizedBox(height: SlSpace.lg),
              _folder(context, l),
            ],
            if (on && report != null) ...[
              const SizedBox(height: SlSpace.md),
              Text(
                l.syncCounts('${report.courses}', '${report.sessions}', '${report.records}'),
                style: SlType.caption.copyWith(color: c.muted),
              ),
              if (report.otherDevices > 0)
                Text(
                  l.syncOtherMacs('${report.otherDevices}'),
                  style: SlType.caption.copyWith(color: c.muted),
                ),
            ],
            if (on && report != null && report.problems.isNotEmpty) ...[
              const SizedBox(height: SlSpace.md),
              ..._problems(context, l, report.problems),
            ],
            const SizedBox(height: SlSpace.md),
            Text(l.syncFootnote, style: SlType.caption.copyWith(color: c.muted)),
          ],
        ),
      );
    },
  );

  Widget _status(BuildContext context, AppLocalizations l, SyncStatus status) {
    final c = context.sl;
    final last = sync.lastSync;
    final when = last == null
        ? l.syncNever
        : l.syncLast(DateFormat.yMMMd(l.localeName).add_Hm().format(last.toLocal()));
    return switch (status) {
      SyncStatus.off => _line(
        context,
        Icons.cloud_off_outlined,
        l.syncOff,
        key: const ValueKey('sync-off'),
      ),
      SyncStatus.unavailable => SlNotice(
        l.syncUnavailable,
        error: true,
        key: const ValueKey('sync-unavailable'),
      ),
      SyncStatus.failed => SlNotice(
        _failure(l, sync.error),
        error: true,
        key: const ValueKey('sync-failed'),
        action: TextButton(onPressed: sync.syncNow, child: Text(l.syncNow)),
      ),
      SyncStatus.syncing => Row(
        key: const ValueKey('sync-syncing'),
        children: [
          const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: SlSpace.sm),
          Text(l.syncSyncing, style: SlType.body.copyWith(color: c.inkSoft)),
        ],
      ),
      SyncStatus.idle => Row(
        key: const ValueKey('sync-idle'),
        children: [
          Icon(Icons.cloud_done_outlined, size: 18, color: c.success),
          const SizedBox(width: SlSpace.sm),
          Expanded(
            child: Text(
              last == null ? l.syncUpToDate : '${l.syncUpToDate} · $when',
              style: SlType.body.copyWith(color: c.inkSoft),
            ),
          ),
          TextButton(
            key: const ValueKey('sync-now'),
            onPressed: sync.syncNow,
            child: Text(l.syncNow),
          ),
        ],
      ),
    };
  }

  static String _failure(AppLocalizations l, Object? error) {
    // EPERM / EACCES: macOS refused the folder (Files and Folders).
    if (error is FileSystemException && const {1, 13}.contains(error.osError?.errorCode)) {
      return l.syncNoAccess;
    }
    return l.syncFailed(error == null ? '' : describeError(l, error));
  }

  Widget _line(BuildContext context, IconData icon, String text, {Key? key}) {
    final c = context.sl;
    return Row(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: c.muted),
        ),
        const SizedBox(width: SlSpace.sm),
        Expanded(
          child: Text(text, style: SlType.body.copyWith(color: c.inkSoft)),
        ),
      ],
    );
  }

  Widget _folder(BuildContext context, AppLocalizations l) {
    final c = context.sl;
    return Row(
      children: [
        Icon(Icons.folder_outlined, size: 18, color: c.muted),
        const SizedBox(width: SlSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.syncFolderLabel, style: SlType.label.copyWith(color: c.text)),
              SelectableText(sync.folder.path, style: SlType.caption.copyWith(color: c.muted)),
            ],
          ),
        ),
        const SizedBox(width: SlSpace.sm),
        OutlinedButton.icon(
          key: const ValueKey('sync-show-in-finder'),
          onPressed: () => _reveal(context),
          icon: const Icon(Icons.folder_open_outlined, size: 18),
          label: Text(l.syncShowInFinder),
        ),
      ],
    );
  }

  List<Widget> _problems(BuildContext context, AppLocalizations l, List<SyncProblem> problems) {
    // The same problem on every pass shows once.
    final messages = <String>{for (final problem in problems) _problem(l, problem)}.toList();
    const shown = 4;
    return [
      for (final message in messages.take(shown))
        Padding(
          padding: const EdgeInsets.only(bottom: SlSpace.xs),
          child: SlNotice(message, error: true),
        ),
      if (messages.length > shown)
        Text(
          l.syncMoreProblems('${messages.length - shown}'),
          style: SlType.caption.copyWith(color: context.sl.muted),
        ),
    ];
  }

  static String _problem(AppLocalizations l, SyncProblem problem) {
    final name = problem.name == null || problem.name!.trim().isEmpty
        ? l.syncUnnamedItem
        : '“${problem.name!.trim()}”';
    return switch (problem.kind) {
      SyncProblemKind.newerFolder => l.syncProblemNewerFolder,
      SyncProblemKind.newerState => l.syncProblemNewerState(problem.name ?? l.syncUnnamedItem),
      SyncProblemKind.unreadableState => l.syncProblemUnreadableState,
      SyncProblemKind.newerPackage => l.syncProblemNewerPackage(name),
      SyncProblemKind.unreadablePackage => l.syncProblemUnreadablePackage(name),
      SyncProblemKind.writeFailed => l.syncProblemWriteFailed,
    };
  }
}
