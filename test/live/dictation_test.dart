import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/dictation.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart' show TimedWord;

void main() {
  test('normalisation matches app.js: case, curly apostrophes, punctuation, spaces', () {
    expect(normalizeAnswer("  It’s  the \"Manta\"!  "), "it's the manta");
    expect(normalizeAnswer('你好，世界。'), '你好世界');
  });

  test('exact after normalisation is correct; ≥0.85 similarity is close', () {
    const expected = 'The other local beer is called Manta.';
    expect(
      gradeDictation('the other local beer is called manta', expected).result,
      DictationResult.correct,
    );
    expect(
      gradeDictation('the other local beer is called mantra', expected).result,
      DictationResult.close,
    );
    expect(gradeDictation('a beer', expected).result, DictationResult.incorrect);
  });

  test('word diff marks missed and extra words in order', () {
    final grade = gradeDictation(
      'the local beer is so called',
      'The other local beer is called Manta.',
    );
    expect(grade.words.map((w) => '${w.mark.name}:${w.text}'), [
      'matched:the',
      'missed:other',
      'matched:local',
      'matched:beer',
      'matched:is',
      'extra:so',
      'matched:called',
      'missed:manta',
    ]);
  });

  test('Chinese is diffed character by character', () {
    final grade = gradeDictation('今天天气好', '今天天气很好。');
    expect(grade.words.where((w) => w.mark == WordMark.missed).map((w) => w.text), ['很']);
    expect(grade.result, DictationResult.close);
  });

  test('sentence span pads and clamps', () {
    expect(sentenceSpan(100, 900), (startMs: 0, endMs: 1100));
    expect(sentenceSpan(5000, 7000), (startMs: 4800, endMs: 7200));
  });

  test('word timings round-trip to the stored JSON shape', () {
    expect(wordsToJson(const [TimedWord('Hi', 0, 300)]), '[{"w":"Hi","s":0,"e":300}]');
    expect(wordsToJson(const []), isNull);
  });

  test('long recognised lines split into timed sentences', () {
    const words =
        '[{"w":"Well,","s":0,"e":300},{"w":"that","s":300,"e":500},'
        '{"w":"works.","s":500,"e":900},{"w":"Does","s":1200,"e":1400},'
        '{"w":"it?","s":1400,"e":1800},{"w":"Yes","s":2000,"e":2300}]';
    final items = dictationItems([
      (
        segmentId: 's-0',
        text: 'Well, that works. Does it? Yes',
        startMs: 0,
        endMs: 2300,
        wordsJson: words,
        translation: '是的',
      ),
      (
        segmentId: 's-1',
        text: 'No timings here at all',
        startMs: 3000,
        endMs: 4000,
        wordsJson: null,
        translation: null,
      ),
    ]);
    expect(items.map((i) => (i.id, i.text, i.startMs, i.endMs)), [
      ('s-0#0', 'Well, that works.', 0, 900),
      ('s-0#1', 'Does it?', 1200, 1800),
      ('s-1', 'No timings here at all', 3000, 4000),
    ]);
    expect(items.first.context, '是的');
  });

  test('very long sentences break at a comma after maxWords', () {
    final words = [
      for (var i = 0; i < 6; i++)
        '{"w":"w$i${i == 3 ? ',' : ''}","s":${i * 100},"e":${i * 100 + 90}}',
    ];
    final items = dictationItems([
      (
        segmentId: 'x',
        text: '',
        startMs: 0,
        endMs: 600,
        wordsJson: '[${words.join(',')}]',
        translation: null,
      ),
    ], maxWords: 3);
    expect(items.map((i) => i.text), ['w0 w1 w2 w3,', 'w4 w5']);
  });
}
