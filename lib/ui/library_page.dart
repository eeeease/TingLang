import 'package:flutter/material.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import '../core/models.dart';
import '../services/app_controller.dart';
import 'brand.dart';
import 'share_import.dart';

enum LibraryTab { mine, discover, shared }

/// Study material: your courses, a place to discover new ones, and
/// recordings or courses shared with you.
class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.app,
    required this.onOpen,
    required this.onImport,
    required this.onImportShared,
    required this.tab,
    required this.onTab,
  });
  final AppController app;
  final void Function(Course, String?) onOpen;
  final VoidCallback onImport;
  final Future<void> Function() onImportShared;
  final LibraryTab tab;
  final ValueChanged<LibraryTab> onTab;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  Area? _filter;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SlPageHeader(
          title: l.navLibrary,
          tabs: SlTabs<LibraryTab>(
            tabs: [
              (value: LibraryTab.mine, label: l.tabMine, count: null),
              (value: LibraryTab.discover, label: l.tabDiscover, count: null),
              (value: LibraryTab.shared, label: l.tabShared, count: null),
            ],
            selected: widget.tab,
            onChanged: widget.onTab,
          ),
          actions: switch (widget.tab) {
            LibraryTab.mine => [
              FilledButton.icon(
                onPressed: widget.onImport,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l.importMaterial),
              ),
            ],
            LibraryTab.shared || LibraryTab.discover => const [],
          },
        ),
        Expanded(
          child: switch (widget.tab) {
            LibraryTab.mine => _mine(context),
            LibraryTab.discover => _placeholder(
              icon: Icons.explore_outlined,
              title: l.discoverEmptyTitle,
              body: l.discoverEmptyBody,
              action: OutlinedButton.icon(
                onPressed: widget.onImport,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l.discoverImportInstead),
              ),
            ),
            LibraryTab.shared => _placeholder(
              icon: Icons.ios_share_outlined,
              title: l.sharedEmptyTitle,
              body: l.sharedEmptyBody,
              action: FilledButton.icon(
                onPressed: widget.onImportShared,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(l.importShared),
              ),
            ),
          },
        ),
      ],
    );
  }

  Widget _placeholder({
    required IconData icon,
    required String title,
    required String body,
    required Widget action,
  }) => ListView(
    padding: const EdgeInsets.fromLTRB(SlSpace.page, 0, SlSpace.page, SlSpace.page),
    children: [SlEmptyState(icon: icon, title: title, body: body, action: action)],
  );

  Widget _mine(BuildContext context) {
    final l = context.l10n;
    final courses = widget.app.state.courses
        .where(
          (course) =>
              (_filter == null || course.area == _filter) &&
              '${course.title} ${course.sourceLabel}'.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(SlSpace.page, 0, SlSpace.page, SlSpace.page),
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            isDense: true,
            hintText: l.searchHint,
            prefixIcon: Icon(Icons.search, size: 18, color: context.sl.muted),
          ),
        ),
        const SizedBox(height: SlSpace.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(l.allScenes),
              selected: _filter == null,
              onSelected: (_) => setState(() => _filter = null),
            ),
            for (final area in Area.values)
              ChoiceChip(
                avatar: Icon(Brand.areaIcon(area), size: 16),
                label: Text(Brand.areaLabel(l, area)),
                selected: _filter == area,
                onSelected: (_) => setState(() => _filter = area),
              ),
          ],
        ),
        const SizedBox(height: SlSpace.xl),
        if (courses.isEmpty)
          SlEmptyState(
            icon: Icons.video_library_outlined,
            title: l.libraryEmptyTitle,
            body: l.libraryEmptyBody,
            action: OutlinedButton(
              onPressed: () => reportAction(context, widget.app.installDemo, success: l.demoLoaded),
              child: Text(l.loadDemo),
            ),
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
                  for (final course in courses)
                    SizedBox(
                      width: width,
                      child: CourseCard(
                        course: course,
                        app: widget.app,
                        onTap: () => widget.onOpen(course, null),
                        onExport: () =>
                            exportCourseShare(context, course: course, store: widget.app.store),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.course,
    required this.app,
    required this.onTap,
    this.onExport,
  });
  final Course course;
  final AppController app;
  final VoidCallback onTap;

  /// Saves the course and its audio or video as a `.tinglang` file.
  final VoidCallback? onExport;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    final count = course.clips.fold<int>(0, (n, clip) => n + app.done(course, clip).length);
    final progress = course.clips.isEmpty
        ? 0.0
        : count / (course.clips.length * learningSteps.length);
    final percent = (progress.clamp(0.0, 1.0) * 100).round();
    return SlPanel(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: c.raised, borderRadius: SlRadius.all(8)),
                    child: Icon(Brand.areaIcon(course.area), size: 16, color: c.inkSoft),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      Brand.areaLabel(l, course.area),
                      style: SlType.caption.copyWith(color: c.muted),
                    ),
                  ),
                  if (percent > 0)
                    Text(
                      l.percentDone(percent),
                      style: SlType.caption.copyWith(
                        color: c.accentInk,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  if (onExport != null)
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: PopupMenuButton<String>(
                        key: ValueKey('course-menu-${course.id}'),
                        tooltip: l.panelMore,
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: Icon(Icons.more_horiz, color: c.muted),
                        onSelected: (_) => onExport!(),
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'share', child: Text(l.exportShared)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                course.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SlType.subtitle.copyWith(color: c.text),
              ),
              const SizedBox(height: 6),
              Text(
                '${l.courseScenes(course.clips.length)} · '
                '${course.mediaPath == null ? l.mediaPending : l.mediaLocal}',
                style: SlType.caption.copyWith(color: c.muted),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: SlRadius.all(3),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0).toDouble(),
                  minHeight: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
