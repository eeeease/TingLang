import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import '../core/models.dart';
import '../core/review.dart';
import '../services/app_controller.dart';
import 'brand.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.app, required this.onOpen});
  final AppController app;
  final void Function(Course, String?) onOpen;
  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final Set<String> _revealed = {};
  bool _showAll = false;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    final cards = _showAll ? widget.app.state.reviews : widget.app.due;
    return ListView(
      padding: const EdgeInsets.fromLTRB(SlSpace.page, 0, SlSpace.page, SlSpace.page),
      children: [
        if (widget.app.state.reviews.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: SlSpace.lg),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: Text(l.showAllSaved),
                selected: _showAll,
                onSelected: (value) => setState(() => _showAll = value),
              ),
            ),
          ),
        if (cards.isEmpty)
          SlEmptyState(
            icon: Icons.bookmark_border,
            title: widget.app.state.reviews.isEmpty ? l.reviewEmptyNone : l.reviewEmptyDone,
            body: widget.app.state.reviews.isEmpty ? l.reviewEmptyHint : l.reviewDoneHint,
          ),
        for (final card in cards)
          Padding(
            padding: const EdgeInsets.only(bottom: SlSpace.md),
            child: SlPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.meaning.isEmpty ? l.recallPrompt : card.meaning,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.nextReview(
                      DateFormat.MMMd(l.localeName).add_Hm().format(card.dueAt.toLocal()),
                    ),
                    style: SlType.caption.copyWith(color: c.muted),
                  ),
                  const SizedBox(height: 18),
                  if (!_revealed.contains(card.id))
                    FilledButton(
                      onPressed: () => setState(() => _revealed.add(card.id)),
                      child: Text(l.reveal),
                    )
                  else ...[
                    SelectableText(
                      card.text,
                      style: TextStyle(color: c.accentInk, fontSize: 22, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final recall in Recall.values)
                          OutlinedButton(
                            onPressed: () => reportAction(context, () async {
                              await widget.app.rateCard(card, recall);
                              if (mounted) setState(() => _revealed.remove(card.id));
                            }),
                            child: Text(
                              l.recallInterval(switch (recall) {
                                Recall.again => l.recallAgain,
                                Recall.hard => l.recallHard,
                                Recall.good => l.recallGood,
                                Recall.easy => l.recallEasy,
                              }, card.previewDays(recall, DateTime.now())),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      Course? source;
                      for (final course in widget.app.state.courses) {
                        if (course.id == card.courseId) source = course;
                      }
                      final course = source;
                      if (course == null || !course.clips.any((c) => c.id == card.clipId)) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(l.clipMissing)));
                        return;
                      }
                      widget.onOpen(course, card.clipId);
                    },
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: Text(l.backToScene),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
