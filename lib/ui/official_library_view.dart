import 'package:flutter/material.dart';
import 'package:tinglang_api/tinglang_api.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import '../core/models.dart';
import '../services/official_library.dart';
import 'brand.dart';
import 'errors.dart';

/// Library → Official: courses from the official library, each with its
/// cover, ready to add. The list is requested when this view first shows.
class OfficialLibraryView extends StatefulWidget {
  const OfficialLibraryView({super.key, required this.official, required this.onOpen});
  final OfficialLibraryService official;
  final void Function(Course course) onOpen;

  @override
  State<OfficialLibraryView> createState() => _OfficialLibraryViewState();
}

class _OfficialLibraryViewState extends State<OfficialLibraryView> {
  OfficialLibraryService get _official => widget.official;

  @override
  void initState() {
    super.initState();
    _official.load();
  }

  Future<void> _add(LibraryEntry entry) => reportAction(context, () async {
    final course = await _official.add(entry);
    if (mounted) widget.onOpen(course);
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    return ListenableBuilder(
      listenable: Listenable.merge([_official, _official.app]),
      builder: (context, _) {
        final library = _official.library;
        if (library == null && _official.loading) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (library == null) {
          final error = _official.error;
          return ListView(
            padding: const EdgeInsets.fromLTRB(SlSpace.page, 0, SlSpace.page, SlSpace.page),
            children: [
              SlEmptyState(
                icon: Icons.cloud_off_outlined,
                title: l.officialUnavailable,
                body: error == null ? '' : describeError(l, error),
                action: OutlinedButton(
                  onPressed: () => _official.load(force: true),
                  child: Text(l.voiceMemosCheckAgain),
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(SlSpace.page, 0, SlSpace.page, SlSpace.page),
          children: [
            Text(l.officialIntro, style: SlType.body.copyWith(color: c.inkSoft)),
            const SizedBox(height: SlSpace.xl),
            if (library.courses.isEmpty)
              SlEmptyState(
                icon: Icons.explore_outlined,
                title: l.discoverEmptyTitle,
                body: l.discoverEmptyBody,
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 3
                      : constraints.maxWidth >= 620
                      ? 2
                      : 1;
                  final width = (constraints.maxWidth - (columns - 1) * SlSpace.lg) / columns;
                  return Wrap(
                    spacing: SlSpace.lg,
                    runSpacing: SlSpace.lg,
                    children: [
                      for (final entry in library.courses)
                        SizedBox(width: width, child: _card(context, entry)),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _card(BuildContext context, LibraryEntry entry) {
    final l = context.l10n;
    final c = context.sl;
    final added = _official.added(entry);
    final busy = _official.adding.contains(entry.id);
    final saved = _official.coverFor(entry.id);
    final cover = entry.coverUrl;
    Course? course() => _official.app.state.courses.where((c) => c.id == entry.id).firstOrNull;
    final Widget action;
    if (busy) {
      action = const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (_official.updatable(entry)) {
      action = FilledButton.tonal(
        key: ValueKey('official-update-${entry.id}'),
        onPressed: () => _add(entry),
        child: Text(l.officialUpdate),
      );
    } else if (added) {
      action = TextButton(
        key: ValueKey('official-open-${entry.id}'),
        onPressed: () {
          final mine = course();
          if (mine != null) widget.onOpen(mine);
        },
        child: Text(l.officialOpen),
      );
    } else {
      action = FilledButton.tonal(
        key: ValueKey('official-add-${entry.id}'),
        onPressed: () => _add(entry),
        child: Text(l.officialAdd),
      );
    }
    return SlPanel(
      key: ValueKey('official-${entry.id}'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(SlRadius.md)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: saved != null
                  ? Image.file(saved, fit: BoxFit.cover)
                  : cover != null
                  ? Image.network(
                      '$cover',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(context, entry),
                    )
                  : _placeholder(context, entry),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SlType.body.copyWith(color: c.text, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          ?entry.sourceLabel,
                          l.courseScenes(entry.clipCount),
                          ?entry.learnerLevel,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SlType.caption.copyWith(color: c.muted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    action,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context, LibraryEntry entry) => Container(
    color: context.sl.raised,
    alignment: Alignment.center,
    child: Icon(Brand.areaIcon(Area.parse(entry.area ?? 'podcasts')), color: context.sl.muted),
  );
}
