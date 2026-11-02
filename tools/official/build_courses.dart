// Builds official-library courses from the YouTube videos in a manifest
// (TingLang-web/scripts/library-manifest.json) with the app's own course
// pipeline and a Claude model. Run it from the TingLang folder:
//
//   TINGLANG_LLM_KEY=sk-ant-… fvm dart run tools/official/build_courses.dart \
//     --manifest ../TingLang-web/scripts/library-manifest.json \
//     --work ../TingLang-web/library-work --out ../TingLang-web/library-courses \
//     --yt-dlp <path> --transcriber <path> [--model claude-haiku-5-5] [--budget 200] \
//     [--clip-minutes 2] [--max-clips 30]
//
// For each `url` entry: page facts (yt-dlp -J), then the transcript — the
// page's English captions when it has them, else its audio transcribed on
// this Mac (tools/official/transcribe.swift, built with swiftc; the audio
// is deleted afterwards) — then L1 selection and parallel L2 clip plans,
// compiled and validated like any generated course. A course gets a clip
// per [--clip-minutes] of video, at most [--max-clips]. Finished courses
// are skipped on the next run unless built at another density: those are
// rebuilt and the new file replaces the old one in place. No new video
// starts once [--budget] US dollars are spent. A summary goes to
// `_summary-<manifest name>.json` in --out, so runs over different
// manifests can share one --out. The key is read from TINGLANG_LLM_KEY only.
import 'dart:convert';
import 'dart:io';

import 'package:tinglang/core/captions.dart';
import 'package:tinglang/core/generation/course_generator.dart';
import 'package:tinglang/core/generation/lexicon.dart';
import 'package:tinglang/core/generation/llm_planner.dart';
import 'package:tinglang/core/models.dart';
import 'package:tinglang/core/providers/catalog.dart';
import 'package:tinglang/core/providers/llm_client.dart';

late String ytDlp, transcriber;
late double clipMinutes;
late int maxClips;
late Directory work;

Future<void> main(List<String> args) async {
  final options = <String, String>{};
  for (var i = 0; i + 1 < args.length; i += 2) {
    options[args[i].replaceFirst('--', '')] = args[i + 1];
  }
  for (final required in ['manifest', 'work', 'out', 'yt-dlp', 'transcriber']) {
    if (!options.containsKey(required)) _usage('--$required is required');
  }
  ytDlp = options['yt-dlp']!;
  transcriber = options['transcriber']!;
  work = Directory(options['work']!)..createSync(recursive: true);
  final out = Directory(options['out']!)..createSync(recursive: true);
  final budget = double.tryParse(options['budget'] ?? '') ?? 200;
  clipMinutes = double.tryParse(options['clip-minutes'] ?? '') ?? 2;
  maxClips = int.tryParse(options['max-clips'] ?? '') ?? 30;
  final model = options['model'] ?? 'claude-haiku-5-5';
  final key = Platform.environment['TINGLANG_LLM_KEY'];
  if (key == null || key.isEmpty) _usage('TINGLANG_LLM_KEY is not set');

  final manifest =
      jsonDecode(File(options['manifest']!).readAsStringSync()) as Map<String, Object?>;
  final entries = [
    for (final e in manifest['courses']! as List)
      if ((e as Map)['url'] is String) e.cast<String, Object?>(),
  ];
  final catalog = ProviderCatalog.fromJson(
    File('assets/providers/catalog.v1.json').readAsStringSync(),
  );
  final price = catalog.model('anthropic', model);
  final client = LlmClient(
    baseUrl: 'https://api.anthropic.com/v1',
    model: model,
    apiKey: key,
    protocol: LlmProtocol.anthropic,
  );
  final jsonModel = ClientJsonModel('anthropic', client);
  final lexicon = Lexicon.fromGzip(File('assets/lexicon/en.v1.json.gz').readAsBytesSync());
  double spent() => price == null
      ? 0
      : price.cost(
          client.usage.inputTokens,
          client.usage.outputTokens,
          cacheWrites: client.usage.cacheWriteTokens,
          cacheReads: client.usage.cacheReadTokens,
        );

  final summary = <Map<String, Object?>>[];
  var warm = false;
  try {
    for (final entry in entries) {
      final url = entry['url']! as String;
      final id = youtubeVideoId(Uri.parse(url));
      if (id == null) {
        _log('skip $url: not a YouTube video');
        continue;
      }
      final done = out.listSync().whereType<File>().where((f) => f.path.contains('youtube-$id-')).toList();
      if (done.isNotEmpty && _density(done.first) == clipMinutes) {
        _log('done $id (${done.first.uri.pathSegments.last})');
        continue;
      }
      if (spent() >= budget) {
        _log('stop: \$${spent().toStringAsFixed(2)} of \$$budget spent');
        break;
      }
      final watch = Stopwatch()..start();
      try {
        final info = await _info(id, url);
        final (lines, source) = await _transcript(id, url, info);
        final before = (client.usage.inputTokens, client.usage.outputTokens, spent());
        final course = await _course(
          info: info,
          lines: lines,
          entry: entry,
          lexicon: lexicon,
          model: jsonModel,
          warm: warm,
        );
        warm = true;
        final file = File('${out.path}/${course['podcast_id']}.json')
          ..writeAsStringSync(jsonEncode(course));
        // A course rebuilt under a new title: keep the old file aside.
        for (final old in done.where((f) => f.path != file.path)) {
          final kept = Directory('${out.path}-replaced')..createSync(recursive: true);
          old.renameSync('${kept.path}/${old.uri.pathSegments.last}');
        }
        final clips = (course['clips']! as List).length;
        final cost = spent() - before.$3;
        summary.add({
          'id': course['podcast_id'],
          'category': entry['category'],
          'transcript': source,
          'clips': clips,
          'input_tokens': client.usage.inputTokens - before.$1,
          'output_tokens': client.usage.outputTokens - before.$2,
          'usd': double.parse(cost.toStringAsFixed(4)),
        });
        _log(
          'ok   ${file.uri.pathSegments.last}: $clips clips from $source '
          '(${(watch.elapsedMilliseconds / 1000).round()} s, \$${cost.toStringAsFixed(3)})',
        );
      } on LlmException catch (e) {
        if (e.unauthorized || e.status == null) rethrow;
        _log('fail $id: $e');
      } on Object catch (e) {
        _log('fail $id: $e');
      }
    }
  } finally {
    client.close();
    final u = client.usage;
    _log(
      'total: ${u.calls} requests, ${u.inputTokens} input, ${u.cacheWriteTokens} cache written, '
      '${u.cacheReadTokens} cache read, ${u.outputTokens} output tokens = \$${spent().toStringAsFixed(3)}',
    );
    final name = File(options['manifest']!).uri.pathSegments.last.replaceAll('.json', '');
    File('${out.path}/_summary-$name.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'model': model,
        'usd': double.parse(spent().toStringAsFixed(4)),
        'requests': client.usage.calls,
        'input_tokens': client.usage.inputTokens,
        'cache_write_tokens': client.usage.cacheWriteTokens,
        'cache_read_tokens': client.usage.cacheReadTokens,
        'output_tokens': client.usage.outputTokens,
        'courses': summary,
      }),
    );
  }
}

/// yt-dlp's facts about the page, kept in [work].
Future<Map<String, Object?>> _info(String id, String url) async {
  final file = File('${work.path}/$id.info.json');
  if (file.existsSync()) return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final result = await Process.run(ytDlp, ['-J', '--no-playlist', '--no-warnings', url]);
  if (result.exitCode != 0) throw StateError('yt-dlp -J: ${result.stderr}');
  final json = jsonDecode('${result.stdout}') as Map<String, Object?>;
  final facts = {
    for (final k in [
      'id',
      'title',
      'channel',
      'uploader',
      'duration',
      'upload_date',
      'language',
      'subtitles',
      'automatic_captions',
    ])
      if (json[k] != null)
        k: k.endsWith('captions') || k == 'subtitles'
            ? {for (final c in (json[k]! as Map).keys) c: const <Object?>[]}
            : json[k],
  };
  file.writeAsStringSync(jsonEncode(facts));
  return facts;
}

/// The transcript as lines: captions first, else this Mac's recogniser.
Future<(List<CaptionLine>, String)> _transcript(
  String id,
  String url,
  Map<String, Object?> info,
) async {
  final saved = File('${work.path}/$id.lines.json');
  if (saved.existsSync()) {
    final json = jsonDecode(saved.readAsStringSync()) as Map<String, Object?>;
    return (
      [
        for (final l in json['lines']! as List)
          CaptionLine(
            (l as Map)['s'] as int,
            l['e'] as int,
            l['t'] as String,
            l['w'] == null
                ? null
                : [
                    for (final w in l['w'] as List)
                      (w: (w as Map)['w'] as String, s: w['s'] as int, e: w['e'] as int),
                  ],
          ),
      ],
      json['source']! as String,
    );
  }
  List<CaptionLine>? lines;
  var source = '';
  final track = englishCaptions(info);
  if (track != null) {
    final result = await Process.run(ytDlp, [
      '--skip-download',
      if (track.automatic) '--write-auto-subs' else '--write-subs',
      '--sub-langs',
      track.language,
      '--sub-format',
      'json3',
      '--no-playlist',
      '--no-warnings',
      '-o',
      '${work.path}/$id',
      url,
    ]);
    final file = File('${work.path}/$id.${track.language}.json3');
    if (result.exitCode == 0 && file.existsSync()) {
      lines = captionLines(file.readAsStringSync());
      source = track.automatic ? 'YouTube captions (automatic)' : 'YouTube captions';
      file.deleteSync();
    }
  }
  if (lines == null || lines.fold(0, (n, l) => n + l.text.split(' ').length) < 100) {
    final download = await Process.run(ytDlp, [
      '-q',
      '--no-warnings',
      '--no-playlist',
      '-f',
      'bestaudio[ext=m4a]/bestaudio',
      '-o',
      '${work.path}/$id.%(ext)s',
      '--print',
      'after_move:filepath',
      url,
    ]);
    final path = '${download.stdout}'.trim().split('\n').last;
    if (download.exitCode != 0 || !File(path).existsSync()) {
      throw StateError('audio download: ${download.stderr}');
    }
    final result = await Process.run(transcriber, [path]);
    File(path).deleteSync();
    if (result.exitCode != 0) throw StateError('transcription: ${result.stderr}');
    lines = [
      for (final s in jsonDecode('${result.stdout}') as List)
        CaptionLine((s as Map)['startMs'] as int, s['endMs'] as int, s['text'] as String, [
          for (final w in s['words'] as List)
            (w: (w as Map)['w'] as String, s: w['s'] as int, e: w['e'] as int),
        ]),
    ];
    source = 'Apple SpeechTranscriber';
  }
  saved.writeAsStringSync(
    jsonEncode({
      'source': source,
      'lines': [
        for (final l in lines)
          {
            's': l.startMs,
            'e': l.endMs,
            't': l.text,
            if (l.words != null)
              'w': [
                for (final w in l.words!) {'w': w.w, 's': w.s, 'e': w.e},
              ],
          },
      ],
    }),
  );
  return (lines, source);
}

Future<Map<String, Object?>> _course({
  required Map<String, Object?> info,
  required List<CaptionLine> lines,
  required Map<String, Object?> entry,
  required Lexicon lexicon,
  required JsonModel model,
  required bool warm,
}) async {
  final id = info['id']! as String;
  final title = '${info['title']}'.trim();
  final channel = '${info['channel'] ?? info['uploader'] ?? 'YouTube'}';
  final sentences = sentencesFromLines([
    for (var i = 0; i < lines.length; i++)
      (
        segmentId: '$id-$i',
        text: lines[i].text,
        startMs: lines[i].startMs,
        endMs: lines[i].endMs,
        wordsJson: lines[i].wordsJson,
        translation: null,
      ),
  ]).where((s) => s.text.isNotEmpty).toList();
  final windows = buildWindows(sentences);
  final candidates = [for (final w in windows) candidatesFor(w, lexicon)];
  for (var i = 0; i < windows.length; i++) {
    windows[i].score = candidates[i].density + (windows[i].durationMs >= 30000 ? 1 : 0);
  }
  // A clip per [clipMinutes] of video: much richer than an everyday
  // generated course.
  final minutes = ((info['duration'] as num?) ?? windows.last.endMs / 1000) / 60;
  final count = (minutes / clipMinutes).round().clamp(2, maxClips).clamp(1, windows.length);
  var picked = selectWindows(windows, count: count);
  Map<String, Object?>? overview;
  if (windows.length > picked.length) {
    final choice = await _soft(() => selectWithModel(model, windows, picked.length));
    if (choice != null) {
      picked = choice.indices;
      overview = choice.overview;
    }
  }
  Future<ClipPlan> plan(int n) async =>
      await _soft(() => planWithModel(model, windows[picked[n]], candidates[picked[n]])) ??
      basicPlan(windows[picked[n]], candidates[picked[n]]);
  // The first clip of a run goes alone: it writes the shared system prompt
  // to the prompt cache, which every later clip then reads.
  final first = warm ? null : await plan(0);
  final rest = await inParallel(picked.length - (first == null ? 0 : 1), 6, (n) async {
    return plan(n + (first == null ? 0 : 1));
  });
  final plans = [?first, ...rest];
  final slug = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  final courseId =
      'youtube-$id-${slug.length > 60 ? slug.substring(0, 60).replaceAll(RegExp(r'-$'), '') : slug}';
  final json = compileCourse(
    GenerationInput(
      courseId: courseId,
      title: title,
      sentences: sentences,
      sourceLabel: '$channel · YouTube',
    ),
    [for (final i in picked) windows[i]],
    plans,
    overview: overview,
  );
  json[Course.youtubeIdKey] = id;
  json['tinglang_category'] = entry['category'];
  json['tinglang_clip_minutes'] = clipMinutes;
  json['tinglang_series'] = entry['series'];
  if (info['duration'] is num) {
    json['tinglang_duration_ms'] = ((info['duration']! as num) * 1000).round();
  }
  validateCompiled(json);
  return json;
}

/// The clip density a finished course was built with; older courses have
/// none and are rebuilt (the new file replaces the old one).
double? _density(File course) {
  try {
    final json = jsonDecode(course.readAsStringSync()) as Map<String, Object?>;
    return (json['tinglang_clip_minutes'] as num?)?.toDouble();
  } on Object {
    return null;
  }
}

/// A clip the model fails on gets Basic content; a rejected key or an
/// unreachable provider stops the run. Rate limits and overloads are
/// waited out first, so several runs can share one key.
Future<T?> _soft<T>(Future<T?> Function() call) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await call();
    } on LlmException catch (e) {
      if (e.unauthorized || e.status == null) rethrow;
      final busy = e.status == 429 || e.status == 529 || e.status! >= 500;
      if (busy && attempt < 6) {
        _log('  busy (${e.status}), retrying in ${attempt * 15} s');
        await Future<void>.delayed(Duration(seconds: attempt * 15));
        continue;
      }
      _log('  model problem, Basic content instead: $e');
      return null;
    } on FormatException catch (e) {
      _log('  unusable reply, Basic content instead: ${e.message}');
      return null;
    }
  }
}

void _log(String line) =>
    stdout.writeln('${DateTime.now().toIso8601String().substring(11, 19)} $line');

Never _usage(String problem) {
  stderr.writeln('$problem\nSee the comment at the top of tools/official/build_courses.dart.');
  exit(64);
}
