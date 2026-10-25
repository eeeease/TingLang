import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tinglang_native/tinglang_native.dart' show VoiceMemo, VoiceMemoProblem;
import 'package:tinglang_ui/tinglang_ui.dart';

import '../l10n/app_localizations.dart';
import '../services/voice_memos.dart';
import 'brand.dart';

/// Recordings without a title of their own are named by when they were made.
String voiceMemoTitle(AppLocalizations l, VoiceMemo memo) => memo.title.isNotEmpty
    ? memo.title
    : l.voiceMemoUntitled(DateFormat.MMMd(l.localeName).add_Hm().format(memo.recordedAt.toLocal()));

/// Lists Voice Memos with today's new ones selected; returns true when an
/// import started (its progress shows under History).
Future<bool> showVoiceMemos(BuildContext context, VoiceMemoService service) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _VoiceMemosDialog(service: service),
    ) ??
    false;

class _VoiceMemosDialog extends StatefulWidget {
  const _VoiceMemosDialog({required this.service});
  final VoiceMemoService service;

  @override
  State<_VoiceMemosDialog> createState() => _VoiceMemosDialogState();
}

class _VoiceMemosDialogState extends State<_VoiceMemosDialog> {
  final _selected = <String>{};
  bool _seeded = false, _importing = false;

  VoiceMemoService get service => widget.service;

  @override
  void initState() {
    super.initState();
    service.addListener(_seed);
    service.refresh();
  }

  @override
  void dispose() {
    service.removeListener(_seed);
    super.dispose();
  }

  /// The first time the list arrives, today's new recordings are selected.
  void _seed() {
    if (_seeded || service.loading || service.problem != null || service.memos.isEmpty) return;
    _seeded = true;
    _selected.addAll(service.fresh.map((m) => m.id));
  }

  List<VoiceMemo> get _chosen => [
    for (final memo in service.memos)
      if (_selected.contains(memo.id) && !service.isImported(memo)) memo,
  ];

  Future<void> _import() async {
    final l = context.l10n;
    final chosen = _chosen;
    if (chosen.isEmpty) return;
    setState(() => _importing = true);
    await reportAction(context, () => service.import(chosen, (memo) => voiceMemoTitle(l, memo)));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: ListenableBuilder(
          listenable: service,
          builder: (context, _) {
            final count = _chosen.length;
            final listed = service.problem == null && service.memos.isNotEmpty;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
                  child: Text(l.voiceMemos, style: Theme.of(context).textTheme.titleLarge),
                ),
                Flexible(
                  child: switch (service.problem) {
                    _ when service.loading && service.memos.isEmpty => const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator.adaptive()),
                    ),
                    VoiceMemoProblem.needsFullDiskAccess => _access(context),
                    VoiceMemoProblem.noLibrary => _message(context, l.voiceMemosNoLibrary),
                    VoiceMemoProblem.unreadable => _message(
                      context,
                      l.voiceMemosUnreadable,
                      retry: true,
                    ),
                    null when service.memos.isEmpty => _message(context, l.voiceMemosEmpty),
                    null => ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [for (final memo in service.memos) _row(context, memo)],
                    ),
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(l.cancel),
                      ),
                      if (listed) ...[
                        const SizedBox(width: SlSpace.sm),
                        FilledButton(
                          onPressed: count == 0 || _importing ? null : _import,
                          child: Text(l.voiceMemosImport('$count')),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, VoiceMemo memo) {
    final l = context.l10n;
    final c = context.sl;
    final imported = service.isImported(memo);
    final when = DateFormat.MMMd(l.localeName).add_Hm().format(memo.recordedAt.toLocal());
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: imported || _selected.contains(memo.id),
      onChanged: imported
          ? null
          : (value) => setState(() {
              if (value ?? false) {
                _selected.add(memo.id);
              } else {
                _selected.remove(memo.id);
              }
            }),
      title: Text(
        voiceMemoTitle(l, memo),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: SlType.body.copyWith(color: c.text, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '$when · ${_clock(memo.duration)}',
        style: SlType.caption.copyWith(
          color: c.muted,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      secondary: imported ? SlBadge(l.voiceMemoImported) : null,
    );
  }

  Widget _access(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 20, color: c.accentInk),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.voiceMemosAccessTitle,
                  style: SlType.subtitle.copyWith(color: c.text, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: SlSpace.sm),
          Text(l.voiceMemosAccessBody, style: SlType.body.copyWith(color: c.inkSoft)),
          const SizedBox(height: SlSpace.lg),
          Wrap(
            spacing: SlSpace.sm,
            runSpacing: SlSpace.sm,
            children: [
              FilledButton(
                onPressed: service.openPrivacySettings,
                child: Text(l.voiceMemosOpenSettings),
              ),
              OutlinedButton(onPressed: service.refresh, child: Text(l.voiceMemosCheckAgain)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _message(BuildContext context, String text, {bool retry = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: SlType.body.copyWith(color: context.sl.inkSoft)),
        if (retry) ...[
          const SizedBox(height: SlSpace.md),
          OutlinedButton(
            onPressed: service.refresh,
            child: Text(context.l10n.voiceMemosCheckAgain),
          ),
        ],
      ],
    ),
  );

  static String _clock(Duration d) {
    final m = d.inMinutes, s = d.inSeconds % 60;
    return d.inHours > 0
        ? '${d.inHours}:${(m % 60).toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '$m:${s.toString().padLeft(2, '0')}';
  }
}
