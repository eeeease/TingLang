// Minimal end-to-end check of AI course generation against a real model:
// L1 clip selection, L2 clip plans in parallel, then compile and validate
// with the same strict rules the app uses. Nothing is saved in the app.
//
//   TINGLANG_LLM_KEY=sk-… fvm dart run tools/llm_demo.dart --preset deepseek
//   TINGLANG_LLM_KEY=sk-ant-… fvm dart run tools/llm_demo.dart --preset anthropic
//   fvm dart run tools/llm_demo.dart --base-url http://localhost:11434/v1 --model qwen3:8b
//
// Options: --preset <id> (see assets/providers/catalog.v1.json), --model,
// --base-url, --protocol openai|anthropic, --clips <n> (default 2),
// --transcript <file> (plain English text; a built-in sample otherwise),
// --out <file> (default build/llm_demo_course.json).
//
// The API key is read from TINGLANG_LLM_KEY only; it is never printed.
import 'dart:convert';
import 'dart:io';

import 'package:tinglang/core/generation/course_generator.dart';
import 'package:tinglang/core/generation/lexicon.dart';
import 'package:tinglang/core/generation/llm_planner.dart';
import 'package:tinglang/core/providers/catalog.dart';
import 'package:tinglang/core/providers/llm_client.dart';

/// Original sample text written for this demo.
const _sample = '''
Last autumn I finally signed up for a weekend pottery class near my office.
I had always assumed it would be relaxing, but the first lesson was surprisingly demanding.
The teacher made us practise centring the clay for almost an hour before we could shape anything.
My hands kept drifting, and the clay wobbled no matter how carefully I pressed.
Eventually she told me to stop fighting it and let my elbows rest against my knees.
That tiny adjustment made an enormous difference to how steady I felt.
By the third week I could pull up the walls of a small cup without collapsing it.
It was lopsided and heavy, yet I was ridiculously proud of it.
What surprised me most was how completely the class cleared my head.
For two hours I could not check my phone or worry about deadlines at all.
Several people in the group said they came for exactly the same reason.
One of them, a retired engineer, treated every bowl like a careful experiment.
He measured the thickness of the base and kept notes on every firing.
I tease him about it, but his pieces are consistently the best in the room.
Meanwhile my glazes still come out patchy and unpredictable.
Next month we are supposed to try making a set of matching plates.
Honestly, I suspect matching will be the hardest part for someone like me.
Switching topics, my sister has just moved to a city where she knows nobody.
She told me the first few weeks were lonelier than she had anticipated.
Her new job keeps her busy, but the evenings felt long and quiet.
So she made a rule to say yes to every invitation for a whole month.
Some of those evenings were awkward, and a couple were genuinely boring.
But one invitation led her to a volunteer group that repairs bicycles for refugees.
Now she spends Saturday mornings fixing brakes and chatting with regulars.
She says having a shared task makes conversation feel far less forced.
Nobody has to perform; you just pass each other tools and talk.
I think that insight applies to making friends at almost any age.
It is easier to connect beside someone than face to face across a table.
She has invited me to join them when I visit in the spring.
I have no idea how to fix a bicycle, but I am looking forward to learning.
''';

Future<void> main(List<String> args) async {
  final options = <String, String>{};
  for (var i = 0; i + 1 < args.length; i += 2) {
    if (!args[i].startsWith('--')) _usage('Unexpected argument ${args[i]}');
    options[args[i].substring(2)] = args[i + 1];
  }
  if (args.length.isOdd) _usage('Every option needs a value');

  final catalog = ProviderCatalog.fromJson(
    File('assets/providers/catalog.v1.json').readAsStringSync(),
  );
  final preset = catalog.preset(options['preset'] ?? 'custom');
  final baseUrl = options['base-url'] ?? preset.baseUrl;
  final model = options['model'] ?? preset.model;
  final protocol = options.containsKey('protocol')
      ? LlmProtocol.parse(options['protocol'])
      : preset.protocol;
  if (baseUrl.isEmpty || model.isEmpty) _usage('Give --preset, or --base-url and --model');
  final key = Platform.environment['TINGLANG_LLM_KEY'];
  final info = catalog.model(preset.id, model);

  final client = LlmClient(
    baseUrl: baseUrl,
    model: model,
    apiKey: key,
    protocol: protocol,
    jsonMode: info?.jsonSchema == false ? JsonMode.jsonObject : JsonMode.schema,
  );
  final jsonModel = ClientJsonModel(preset.id, client);
  stdout.writeln(
    'Model: $model (${protocol.name}) at $baseUrl, key ${key == null || key.isEmpty ? 'not set' : 'set'}',
  );

  // D1–D3: sentences with even timings (~0.3 s a word), windows, candidates.
  final text = options['transcript'] == null
      ? _sample
      : File(options['transcript']!).readAsStringSync();
  final sentences = <GenSentence>[];
  var t = 0;
  for (final s in RegExp(r'[^.?!]+[.?!]+').allMatches(text)) {
    final sentence = s[0]!.trim().replaceAll(RegExp(r'\s+'), ' ');
    final ms = sentence.split(' ').length * 300;
    sentences.add(GenSentence(sentence, t, t + ms));
    t += ms + 400;
  }
  final lexicon = Lexicon.fromGzip(File('assets/lexicon/en.v1.json.gz').readAsBytesSync());
  final windows = buildWindows(sentences);
  final candidates = [for (final w in windows) candidatesFor(w, lexicon)];
  for (var i = 0; i < windows.length; i++) {
    windows[i].score = candidates[i].density;
  }
  final count = int.tryParse(options['clips'] ?? '') ?? 2;
  var picked = selectWindows(windows, count: count);
  stdout.writeln('${sentences.length} sentences, ${windows.length} windows');

  final watch = Stopwatch()..start();
  try {
    Map<String, Object?>? overview;
    if (windows.length > picked.length) {
      final choice = await selectWithModel(jsonModel, windows, picked.length);
      if (choice != null) {
        picked = choice.indices;
        overview = choice.overview;
      }
      stdout.writeln('L1 selection: windows $picked (${_seconds(watch)})');
    }
    final plans = await inParallel(picked.length, 4, (n) async {
      final started = watch.elapsed;
      final plan = await planWithModel(jsonModel, windows[picked[n]], candidates[picked[n]]);
      stdout.writeln(
        'L2 clip ${n + 1}: ${plan?.items.length ?? 0} items '
        '(${((watch.elapsed - started).inMilliseconds / 1000).toStringAsFixed(1)} s)',
      );
      return plan ?? basicPlan(windows[picked[n]], candidates[picked[n]]);
    });

    final json = compileCourse(
      GenerationInput(
        courseId: 'llm-demo',
        title: 'LLM demo',
        sentences: sentences,
        sourceLabel: 'Generated with $model',
      ),
      [for (final i in picked) windows[i]],
      plans,
      overview: overview,
    );
    final course = validateCompiled(json);
    final out = File(options['out'] ?? 'build/llm_demo_course.json');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));

    final usage = client.usage;
    final cost = info != null && info.priced
        ? ' ≈ ${formatUsd(info.cost(usage.inputTokens, usage.outputTokens))}'
        : '';
    stdout
      ..writeln(
        'OK: ${course.clips.length} clips, '
        '${course.clips.fold(0, (sum, c) => sum + c.items.length)} items, '
        'all quotes verbatim (${_seconds(watch)})',
      )
      ..writeln(
        '${usage.calls} requests, ${usage.inputTokens} input + ${usage.outputTokens} output '
        'tokens$cost; structured output: ${client.jsonMode.name}',
      )
      ..writeln('Course JSON: ${out.path}');
  } on LlmException catch (e) {
    stderr.writeln('Failed: $e');
    exitCode = 1;
  } on FormatException catch (e) {
    stderr.writeln('The course did not validate: ${e.message}');
    exitCode = 1;
  } finally {
    client.close();
  }
}

String _seconds(Stopwatch watch) =>
    '${(watch.elapsedMilliseconds / 1000).toStringAsFixed(1)} s';

Never _usage(String problem) {
  stderr.writeln('$problem\nSee the comment at the top of tools/llm_demo.dart.');
  exit(64);
}
