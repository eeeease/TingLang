import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/models.dart';
import 'package:tinglang/core/quiz.dart';

void main() {
  test('cloze from the exact source sentence, recall from the meaning', () {
    const clip = CourseClip(
      id: 'c1',
      title: 't',
      startMs: 0,
      endMs: 1000,
      transcript: '',
      sentences: [],
      items: [
        LearningItem(
          id: 'w',
          kind: 'words',
          text: 'Staggering',
          meaning: '惊人的',
          original: 'It is a staggering amount.',
        ),
        LearningItem(
          id: 's',
          kind: 'sentences',
          text: 'One and the same.',
          meaning: '同一回事',
          original: 'One and the same.',
        ),
        LearningItem(id: 'p', kind: 'phrases', text: 'turn out', original: 'Nothing here matches.'),
      ],
      blanks: [],
      blindTemplate: '',
      shadowing: [],
      retellPrompt: '',
      followUp: '',
      outline: [],
    );
    final quiz = buildQuiz(clip);
    expect(quiz.map((q) => (q.item.id, q.kind, q.prompt)), [
      ('w', QuizKind.cloze, 'It is a ____ amount.'),
      ('w', QuizKind.recall, '惊人的'),
      ('s', QuizKind.recall, '同一回事'),
    ]);
  });
}
