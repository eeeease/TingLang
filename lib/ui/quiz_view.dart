import 'package:flutter/material.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import '../core/dictation.dart';
import '../core/models.dart';
import '../core/quiz.dart';
import '../services/app_controller.dart';
import 'brand.dart';

/// Cloze and recall questions for one clip. Wrong answers are added to the
/// FSRS review deck; finishing marks the quiz step done.
class QuizView extends StatefulWidget {
  const QuizView({super.key, required this.app, required this.course, required this.clip});
  final AppController app;
  final Course course;
  final CourseClip clip;
  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  late final List<QuizQuestion> _questions = buildQuiz(widget.clip);
  final _answer = TextEditingController();
  int _index = 0, _correct = 0;
  DictationGrade? _grade;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_grade != null || _answer.text.trim().isEmpty) return;
    final q = _questions[_index];
    final grade = gradeDictation(_answer.text, q.answer);
    setState(() => _grade = grade);
    if (grade.result == DictationResult.incorrect) {
      await widget.app.saveExpression(widget.course, widget.clip, q.item.text, q.item.meaning);
    } else {
      _correct++;
    }
  }

  Future<void> _next() async {
    if (_index + 1 >= _questions.length) {
      setState(() => _index = _questions.length);
      await widget.app.setDone(widget.course, widget.clip, 'quiz', true);
      return;
    }
    setState(() {
      _index++;
      _grade = null;
      _answer.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    if (_questions.isEmpty) return SlNotice(l.quizEmpty);
    if (_index >= _questions.length) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.quizDone(_correct, _questions.length),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => setState(() {
              _index = 0;
              _correct = 0;
              _grade = null;
              _answer.clear();
            }),
            child: Text(l.quizRestart),
          ),
        ],
      );
    }
    final q = _questions[_index];
    final grade = _grade;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.quizIntro, style: SlType.caption.copyWith(color: c.muted)),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: _index / _questions.length),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: SlBadge(q.kind == QuizKind.cloze ? l.quizCloze : l.quizRecall),
        ),
        const SizedBox(height: 12),
        Text(q.prompt, style: const TextStyle(fontSize: 18, height: 1.6)),
        if (q.kind == QuizKind.recall && q.item.explanation.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(q.item.explanation, style: TextStyle(color: c.muted)),
          ),
        const SizedBox(height: 14),
        TextField(
          controller: _answer,
          autofocus: true,
          enabled: grade == null,
          onSubmitted: (_) => grade == null ? _check() : _next(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton(onPressed: grade == null ? _check : null, child: Text(l.quizCheck)),
            const SizedBox(width: 10),
            if (grade != null) FilledButton.tonal(onPressed: _next, child: Text(l.quizNext)),
          ],
        ),
        if (grade != null) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: SlBadge(switch (grade.result) {
              DictationResult.correct => l.dictationCorrect,
              DictationResult.close => l.dictationClose,
              DictationResult.incorrect => '${l.dictationIncorrect} · ${l.addedToReview}',
            }, warning: grade.result == DictationResult.incorrect),
          ),
          const SizedBox(height: 8),
          SelectableText(
            q.answer,
            style: TextStyle(color: c.accentInk, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          if (q.kind == QuizKind.recall && q.item.original.isNotEmpty)
            Text(q.item.original, style: TextStyle(color: c.muted)),
        ],
      ],
    );
  }
}
