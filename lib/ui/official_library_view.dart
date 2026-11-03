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

  /// The chosen category id; null shows every course, [_other] those in
  /// no listed category.
  String? _category;
  static const _other = '';
  bool _signingIn = false;

  @override
  void initState() {
    super.initState();
    _official.load();
  }

  Future<void> _add(LibraryEntry entry) => reportAction(context, () async {
    final course = await _official.add(entry);
    if (mounted) widget.onOpen(course);
  });

  Future<void> _signIn() async {
    setState(() => _signingIn = true);
    await reportAction(context, _official.signIn);
    if (mounted) setState(() => _signingIn = false);
  }

  /// Signed out, the server lists a few courses per category: say how many
  /// there are and offer to sign in.
  Widget _previewNotice(BuildContext context, OfficialLibrary library) {
    final l = context.l10n;
    final c = context.sl;
    return SlPanel(
      key: const ValueKey('official-preview'),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: c.accentInk),
          const SizedBox(width: SlSpace.md),
          Expanded(
            child: Text(
              l.officialPreviewNotice(library.courseCount ?? library.courses.length),
              style: SlType.body.copyWith(color: c.text),
            ),
          ),
          if (_official.account != null) ...[
            const SizedBox(width: SlSpace.md),
            FilledButton(
              key: const ValueKey('official-sign-in'),
              onPressed: _signingIn ? null : _signIn,
              child: Text(l.officialSignInForAll),
            ),
          ],
        ],
      ),
    );
  }

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
        final language = Localizations.localeOf(context).languageCode;
        final listed = {for (final category in library.categories) category.id};
        bool inCategory(LibraryEntry entry, String id) =>
            id == _other ? !listed.contains(entry.category) : entry.category == id;
        // Only categories that have courses; a stale choice shows everything.
        final categories = [
          for (final category in library.categories)
            if (library.courses.any((e) => e.category == category.id)) category,
        ];
        final others = categories.isNotEmpty && library.courses.any((e) => inCategory(e, _other));
        final chosen =
            _category == null ||
                (_category == _other ? others : categories.any((x) => x.id == _category))
            ? _category
            : null;
        final courses = chosen == null
            ? library.courses
            : [
                for (final entry in library.courses)
                  if (inCategory(entry, chosen)) entry,
              ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(SlSpace.page, 0, SlSpace.page, SlSpace.page),
          children: [
            Text(l.officialIntro, style: SlType.body.copyWith(color: c.inkSoft)),
            const SizedBox(height: SlSpace.xl),
            if (library.preview) ...[
              _previewNotice(context, library),
              const SizedBox(height: SlSpace.xl),
            ],
            if (categories.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l.officialAllCategories),
                    selected: chosen == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                  for (final category in categories)
                    ChoiceChip(
                      key: ValueKey('official-category-${category.id}'),
                      label: Text(category.name(language)),
                      selected: chosen == category.id,
                      onSelected: (_) => setState(() => _category = category.id),
                    ),
                  if (others)
                    ChoiceChip(
                      label: Text(l.officialOtherCategory),
                      selected: chosen == _other,
                      onSelected: (_) => setState(() => _category = _other),
                    ),
                ],
              ),
              const SizedBox(height: SlSpace.xl),
            ],
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
                      for (final entry in courses)
                        SizedBox(width: width, child: _card(context, entry)),
                    ],
                  );
                },
              ),
            if (library.preview && chosen != null && chosen != _other)
              for (final category in categories.where((x) => x.id == chosen))
                if ((category.courseCount ?? 0) > courses.length)
                  Padding(
                    padding: const EdgeInsets.only(top: SlSpace.lg),
                    child: Text(
                      l.officialMoreAfterSignIn(category.courseCount! - courses.length),
                      key: const ValueKey('official-more'),
                      style: SlType.caption.copyWith(color: c.muted),
                    ),
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
