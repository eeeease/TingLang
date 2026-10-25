import 'dart:convert';

import 'json_helpers.dart';
import 'models.dart';
import 'sentence.dart';

/// 外部时间统一转换成“原媒体绝对毫秒”；不能把剪辑内时间混在一起。
int parseTimestamp(Object? value) {
  if (value is num && value.isFinite && value >= 0) {
    return (value * 1000).round();
  }
  if (value is! String) throw const FormatException('Invalid timestamp.');
  final match = RegExp(r'^(?:(\d+):)?([0-5]?\d):([0-5]\d)(?:[.,](\d{1,3}))?$')
      .firstMatch(value.trim());
  if (match == null) throw FormatException('Invalid timestamp: $value');
  final h = int.parse(match.group(1) ?? '0');
  final m = int.parse(match.group(2) ?? '0');
  final s = int.parse(match.group(3) ?? '0');
  final ms = int.parse((match.group(4) ?? '').padRight(3, '0'));
  return ((h * 60 + m) * 60 + s) * 1000 + ms;
}

String timeLabel(int ms) {
  final total = (ms < 0 ? 0 : ms) ~/ 1000;
  final hours = total ~/ 3600;
  final minutes = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
  final seconds = (total % 60).toString().padLeft(2, '0');
  return hours == 0 ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
}

String normalizeAnswer(String text) => text
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'[’‘]'), "'")
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'[.!?,;:]+$'), '');

String _space(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Source-text comparison used by the English V3 course validator:
/// case-insensitive, curly quotes folded, whitespace collapsed.
String sourceKey(String text) =>
    _space(text.toLowerCase().replaceAll(RegExp(r'[’‘]'), "'").replaceAll(RegExp(r'[“”]'), '"'));

/// 英文仓库的 V3 教学设计仍使用 schema_version=2，不冒充新 schema。
class CourseCodec {
  /// [strictSource] requires exact, case-sensitive quotes of the transcript
  /// (the 0.1 behaviour). The default follows that validator, so
  /// every course it accepts imports here too.
  const CourseCodec({this.strictSource = false});
  final bool strictSource;

  bool _inSource(String transcript, String quote) =>
      strictSource ? transcript.contains(quote) : sourceKey(transcript).contains(sourceKey(quote));
  Course decode(String text, {Area area = Area.life, DateTime? importedAt}) =>
      fromMap(jsonObject(jsonDecode(text), 'course'), area: area, importedAt: importedAt);

  Course fromMap(
    Map<String, Object?> root, {
    Area area = Area.life,
    DateTime? importedAt,
    String? mediaPath,
    String? sourceLabel,
  }) {
    if (jsonInt(root['schema_version'], 'schema_version') != 2) {
      throw const FormatException('Only English schema_version: 2 is supported.');
    }
    final design = jsonInt(root['design_version'], 'design_version', fallback: 3);
    if (design != 3) throw const FormatException('Expected design_version: 3.');
    final id = nonEmpty(root['podcast_id'], 'podcast_id');
    final title = nonEmpty(root['title'], 'title');
    final clipData = jsonList(root['clips'], 'clips');
    if (clipData.isEmpty || clipData.length > 5000) {
      throw const FormatException('A course needs 1–5000 clips.');
    }
    final ids = <String>{};
    final itemIds = <String>{};
    final clips = <CourseClip>[];
    for (final raw in clipData) {
      final j = jsonObject(raw, 'clip');
      final clipId = nonEmpty(j['id'], 'clip.id');
      if (!ids.add(clipId)) throw FormatException('Duplicate clip id: $clipId');
      final start = parseTimestamp(j['start']);
      final end = j['end'] == null && root['tinglang_untranscribed'] == true
          ? null
          : parseTimestamp(j['end']);
      if (end != null && end <= start) {
        throw FormatException('$clipId: end must be later than start.');
      }
      final transcript = jsonString(j['transcript'], 'transcript', fallback: '');
      final learning = jsonObject(j['learning'] ?? <String, Object?>{}, 'learning');
      final items = <LearningItem>[];
      for (final kind in ['words', 'phrases', 'sentences']) {
        for (final item in jsonList(learning[kind] ?? <Object?>[], kind)) {
          final parsed = LearningItem.fromJson(jsonObject(item, kind), kind);
          if (!itemIds.add(parsed.id)) {
            throw FormatException('Duplicate learning item id: ${parsed.id}');
          }
          if (parsed.original.isNotEmpty && !_inSource(transcript, parsed.original)) {
            throw FormatException('${parsed.id}: original_example is not in transcript.');
          }
          items.add(parsed);
        }
      }
      final blind = jsonObject(j['blind_listening'] ?? <String, Object?>{}, 'blind');
      final template = jsonString(blind['template'], 'blind.template', fallback: '');
      final blanks = <ListeningBlank>[];
      final blankIds = <String>{};
      var reconstructed = template;
      for (final b in jsonList(blind['blanks'] ?? <Object?>[], 'blanks')) {
        final entry = jsonObject(b, 'blank');
        final blankId = nonEmpty(entry['id'], 'blank.id');
        final answer = nonEmpty(entry['answer'], 'blank.answer');
        if (!blankIds.add(blankId)) throw FormatException('Duplicate blank: $blankId');
        final type = jsonString(entry['type'], 'blank.type', fallback: 'word');
        final itemId = entry['learning_item_id'];
        final token = '{{$blankId}}';
        if (token.allMatches(template).length != 1) {
          throw FormatException('$clipId: $token must appear exactly once.');
        }
        reconstructed = reconstructed.replaceFirst(token, answer);
        blanks.add(
          ListeningBlank(
            blankId,
            answer,
            type: const {'word', 'phrase', 'sentence'}.contains(type) ? type : 'word',
            itemId: itemId is String && itemId.isNotEmpty ? itemId : null,
          ),
        );
      }
      if (template.isNotEmpty &&
          (_space(reconstructed) != _space(transcript) ||
              RegExp(r'\{\{[^}]+\}\}').hasMatch(reconstructed))) {
        throw FormatException('$clipId: blind answers do not reconstruct the transcript.');
      }
      final shadowing = <String>[];
      final passages = <ShadowPassage>[];
      for (final value in jsonList(j['shadowing'] ?? <Object?>[], 'shadowing')) {
        final entry = value is String
            ? <String, Object?>{'text': value}
            : jsonObject(value, 'shadowing item');
        final passage = jsonString(entry['text'], 'shadowing.text');
        if (!_inSource(transcript, passage)) {
          throw FormatException('$clipId: shadowing passage is not source text.');
        }
        shadowing.add(passage);
        passages.add(
          ShadowPassage(passage, jsonString(entry['reason'], 'shadowing.reason', fallback: '')),
        );
      }
      final retell = jsonObject(j['retelling'] ?? <String, Object?>{}, 'retelling');
      final outline = jsonList(
        retell['outline'] ?? <Object?>[],
        'outline',
      ).map((e) => jsonString(e, 'outline item')).toList();
      final evidence = jsonList(
        retell['source_evidence'] ?? <Object?>[],
        'source_evidence',
      ).map((e) => jsonString(e, 'source evidence')).toList();
      if (evidence.isNotEmpty &&
          (evidence.length != outline.length ||
              evidence.any((text) => !_inSource(transcript, text)))) {
        throw FormatException('$clipId: invalid retelling source evidence.');
      }
      final cues = <Sentence>[];
      for (final rawCue in jsonList(j['tinglang_cues'] ?? <Object?>[], 'tinglang_cues')) {
        final cue = Sentence.fromJson(jsonObject(rawCue, 'cue'));
        if (cue.startTime.inMilliseconds < start ||
            cue.duration <= Duration.zero ||
            (end != null && cue.endTime.inMilliseconds > end)) {
          throw FormatException('$clipId: subtitle cue outside clip.');
        }
        cues.add(cue);
      }
      cues.sort((a, b) => a.startTime.compareTo(b.startTime));
      clips.add(
        CourseClip(
          id: clipId,
          title: jsonString(j['title'], 'clip.title', fallback: clipId),
          startMs: start,
          endMs: end,
          transcript: transcript,
          sentences: List.unmodifiable(cues),
          items: List.unmodifiable(items),
          blanks: List.unmodifiable(blanks),
          blindTemplate: template,
          shadowing: List.unmodifiable(shadowing),
          retellPrompt: jsonString(
            retell['prompt'],
            'prompt',
            fallback: 'Retell this scene in your own words.',
          ),
          followUp: jsonString(
            retell['follow_up'],
            'follow_up',
            fallback: 'How does this connect to your own life?',
          ),
          outline: List.unmodifiable(outline),
          shadowPassages: List.unmodifiable(passages),
          evidence: List.unmodifiable(evidence),
          targetItemIds: List.unmodifiable(
            jsonList(
              retell['target_item_ids'] ?? <Object?>[],
              'target_item_ids',
            ).whereType<String>(),
          ),
          topic: jsonString(j['topic'], 'clip.topic', fallback: ''),
          difficulty: j['difficulty'] is num ? (j['difficulty']! as num).round() : null,
        ),
      );
    }
    return Course(
      id: id,
      title: title,
      area: area,
      clips: List.unmodifiable(clips),
      raw: Map.unmodifiable(root),
      importedAt: importedAt ?? DateTime.now().toUtc(),
      mediaPath: mediaPath,
      sourceLabel:
          sourceLabel ??
          jsonString(root['tinglang_source'], 'tinglang_source', fallback: 'Imported course'),
    );
  }
}

/// 读取 SRT / WebVTT 的 cue。保留真实时间，不凭文本长度捏造词级时间戳。
List<Sentence> parseSubtitles(String source) {
  final normalized = source
      .replaceAll('\uFEFF', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final cues = <Sentence>[];
  for (final block in normalized.split(RegExp(r'\n\s*\n'))) {
    final lines = block.trim().split('\n');
    if (lines.isEmpty ||
        lines.first.startsWith('NOTE') ||
        lines.first == 'STYLE' ||
        lines.first == 'REGION') {
      continue;
    }
    final timeLine = lines.indexWhere((line) => line.contains('-->'));
    if (timeLine < 0) continue;
    final times = lines[timeLine].split('-->');
    if (times.length != 2) throw const FormatException('Invalid subtitle cue.');
    final start = parseTimestamp(times[0].trim());
    final end = parseTimestamp(times[1].trim().split(RegExp(r'\s+')).first);
    if (end <= start) throw const FormatException('Subtitle ends before it starts.');
    final text = lines
        .skip(timeLine + 1)
        .join(' ')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .trim();
    if (text.isEmpty) continue;
    cues.add(
      Sentence(
        index: cues.length,
        text: text,
        startTime: Duration(milliseconds: start),
        endTime: Duration(milliseconds: end),
      ),
    );
  }
  if (cues.isEmpty) throw const FormatException('No timed SRT/VTT cues were found.');
  cues.sort((a, b) => a.startTime.compareTo(b.startTime));
  return cues;
}

/// 本地媒体按字幕 cue 组合成约一分钟的片段，不伪造 AI 教学内容。
Map<String, Object?> courseForMedia({
  required String id,
  required String title,
  List<Sentence> cues = const [],
}) {
  final groups = <List<Sentence>>[];
  for (final cue in cues) {
    if (groups.isEmpty ||
        cue.startTime.inMilliseconds - groups.last.first.startTime.inMilliseconds >= 60000) {
      groups.add([]);
    }
    groups.last.add(cue);
  }
  return {
    'schema_version': 2,
    'design_version': 3,
    'podcast_id': id,
    'title': title,
    'tinglang_untranscribed': cues.isEmpty,
    'tinglang_source': 'Your local media',
    'clips': cues.isEmpty
        ? <Object?>[
            {
              'id': 'clip_001',
              'title': 'Full recording',
              'start': 0,
              'end': null,
              'transcript': '',
            },
          ]
        : [
            for (var i = 0; i < groups.length; i++)
              {
                'id': 'clip_${(i + 1).toString().padLeft(3, '0')}',
                'title': 'Scene ${i + 1}',
                'start': groups[i].first.startTime.inMilliseconds / 1000,
                'end':
                    groups[i].map((s) => s.endTime.inMilliseconds).reduce((a, b) => a > b ? a : b) /
                    1000,
                'transcript': groups[i].map((s) => s.text).join(' '),
                'tinglang_cues': groups[i].map((s) => s.toJson()).toList(),
              },
          ],
  };
}
