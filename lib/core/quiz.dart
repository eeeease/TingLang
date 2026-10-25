import 'models.dart';

enum QuizKind { cloze, recall }

class QuizQuestion {
  const QuizQuestion({required this.item, required this.kind, required this.prompt});
  final LearningItem item;
  final QuizKind kind;

  /// Cloze: the source sentence with the item replaced by `____`.
  /// Recall: the native-language meaning.
  final String prompt;
  String get answer => item.text;
}

/// Deterministic quiz for one clip (no LLM): a cloze from each word/phrase's
/// exact source sentence, and a recall question from each item's meaning.
List<QuizQuestion> buildQuiz(CourseClip clip) {
  final questions = <QuizQuestion>[];
  for (final item in clip.items) {
    if (item.kind != 'sentences' && item.original.isNotEmpty) {
      final at = item.original.toLowerCase().indexOf(item.text.toLowerCase());
      if (at >= 0) {
        questions.add(
          QuizQuestion(
            item: item,
            kind: QuizKind.cloze,
            prompt:
                '${item.original.substring(0, at)}____${item.original.substring(at + item.text.length)}',
          ),
        );
      }
    }
    if (item.meaning.trim().isNotEmpty) {
      questions.add(QuizQuestion(item: item, kind: QuizKind.recall, prompt: item.meaning));
    }
  }
  return questions;
}
