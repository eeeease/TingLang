import 'json_helpers.dart';
import 'sentence.dart';

/// Interest areas. Display names are localised in the UI (Brand.areaLabel).
enum Area {
  nba,
  gaming,
  cinema,
  life,
  podcasts,
  personal;

  static Area parse(String name) =>
      Area.values.firstWhere((area) => area.name == name, orElse: () => Area.life);
}

const learningSteps = ['words', 'phrases', 'sentences', 'blind', 'shadowing', 'retelling', 'quiz'];

class LearningItem {
  const LearningItem({
    required this.id,
    required this.kind,
    required this.text,
    this.meaning = '',
    this.explanation = '',
    this.original = '',
    this.example = '',
    this.frame = '',
    this.memory = '',
    this.subtype = '',
    this.cefr = '',
    this.whyUseful = '',
    this.memoryType = '',
    this.memoryNote = '',
    this.patterns = const [],
  });
  final String id, kind, text, meaning, explanation, original, example, frame, memory;

  /// V3 fields kept for display and quizzes (all optional in other formats).
  final String subtype, cefr, whyUseful, memoryType, memoryNote;
  final List<String> patterns;
  factory LearningItem.fromJson(Map<String, Object?> data, String kind) {
    final memory = data['memory_aid'];
    final aid = memory is Map<String, Object?> ? memory : const <String, Object?>{};
    final patterns = data['common_patterns'];
    return LearningItem(
      id: nonEmpty(data['id'], '$kind.id'),
      kind: kind,
      text: nonEmpty(data['text'], '$kind.text'),
      meaning: jsonString(data['meaning_zh'], 'meaning_zh', fallback: ''),
      explanation: jsonString(data['simple_explanation_en'], 'explanation', fallback: ''),
      original: jsonString(data['original_example'], 'original_example', fallback: ''),
      example: jsonString(data['learner_example'], 'learner_example', fallback: ''),
      frame: jsonString(data['reusable_frame'], 'reusable_frame', fallback: ''),
      memory: jsonString(aid['cue_zh'], 'memory_aid.cue_zh', fallback: ''),
      memoryType: jsonString(aid['type'], 'memory_aid.type', fallback: ''),
      memoryNote: jsonString(aid['note'], 'memory_aid.note', fallback: ''),
      subtype: jsonString(data['subtype'], 'subtype', fallback: ''),
      cefr: jsonString(data['cefr'], 'cefr', fallback: ''),
      whyUseful: jsonString(data['why_useful'], 'why_useful', fallback: ''),
      patterns: patterns is List
          ? [
              for (final p in patterns)
                if (p is String && p.trim().isNotEmpty) p,
            ]
          : const [],
    );
  }
}

class ListeningBlank {
  const ListeningBlank(this.id, this.answer, {this.type = 'word', this.itemId});
  final String id, answer;

  /// `word`, `phrase` or `sentence` (colours the inline input).
  final String type;
  final String? itemId;
}

/// A shadowing focus passage (exact source text) and why it was chosen.
class ShadowPassage {
  const ShadowPassage(this.text, [this.reason = '']);
  final String text, reason;
}

class CourseClip {
  const CourseClip({
    required this.id,
    required this.title,
    required this.startMs,
    required this.endMs,
    required this.transcript,
    required this.sentences,
    required this.items,
    required this.blanks,
    required this.blindTemplate,
    required this.shadowing,
    required this.retellPrompt,
    required this.followUp,
    required this.outline,
    this.shadowPassages = const [],
    this.targetItemIds = const [],
    this.evidence = const [],
    this.topic = '',
    this.difficulty,
  });
  final String id, title, transcript, blindTemplate, retellPrompt, followUp;
  final List<ShadowPassage> shadowPassages;

  /// Items the learner should try to use when retelling.
  final List<String> targetItemIds;

  /// Exact source quotes backing each outline point.
  final List<String> evidence;
  final String topic;
  final int? difficulty;
  final int startMs;

  /// null 仅用于没有字幕的新媒体；由播放器探测真实时长。
  final int? endMs;
  final List<Sentence> sentences;
  final List<LearningItem> items;
  final List<ListeningBlank> blanks;
  final List<String> shadowing, outline;
}

/// raw 是原始课程内容的完整副本，重导入时不丢弃未知字段。
class Course {
  const Course({
    required this.id,
    required this.title,
    required this.area,
    required this.clips,
    required this.raw,
    required this.importedAt,
    this.mediaPath,
    this.sourceLabel = '',
  });
  final String id, title, sourceLabel;
  final Area area;
  final List<CourseClip> clips;
  final Map<String, Object?> raw;
  final DateTime importedAt;

  /// YouTube video for courses without local media (courses that come with a YouTube id).
  String? get youtubeId {
    final id = raw['tinglang_youtube_id'];
    return id is String && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id) ? id : null;
  }

  String get summary {
    final overview = raw['overview'];
    return overview is Map<String, Object?> && overview['episode_summary_en'] is String
        ? overview['episode_summary_en']! as String
        : '';
  }

  /// 相对应用资料目录的受控路径，不接受外部 JSON 的绝对路径。
  final String? mediaPath;
  Course copyWith({Area? area, String? mediaPath}) => Course(
    id: id,
    title: title,
    area: area ?? this.area,
    clips: clips,
    raw: raw,
    importedAt: importedAt,
    mediaPath: mediaPath ?? this.mediaPath,
    sourceLabel: sourceLabel,
  );
  Map<String, Object?> toJson() => {
    'raw': raw,
    'area': area.name,
    'mediaPath': mediaPath,
    'importedAt': importedAt.toUtc().toIso8601String(),
    'sourceLabel': sourceLabel,
  };
}

class PracticeAttempt {
  const PracticeAttempt({
    required this.id,
    required this.createdAt,
    required this.kind,
    required this.note,
    required this.durationMs,
    this.courseId,
    this.clipId,
    this.recordingPath,
  });
  final String id, kind, note;
  final DateTime createdAt;
  final int durationMs;
  final String? courseId, clipId, recordingPath;
  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'kind': kind,
    'note': note,
    'durationMs': durationMs,
    'courseId': courseId,
    'clipId': clipId,
    'recordingPath': recordingPath,
  };
  factory PracticeAttempt.fromJson(Map<String, Object?> j) => PracticeAttempt(
    id: nonEmpty(j['id'], 'attempt.id'),
    createdAt: DateTime.parse(jsonString(j['createdAt'], 'createdAt')),
    kind: jsonString(j['kind'], 'attempt.kind'),
    note: jsonString(j['note'], 'attempt.note', fallback: ''),
    durationMs: jsonInt(j['durationMs'], 'durationMs', fallback: 0),
    courseId: j['courseId'] == null ? null : jsonString(j['courseId'], 'courseId'),
    clipId: j['clipId'] == null ? null : jsonString(j['clipId'], 'clipId'),
    recordingPath: j['recordingPath'] == null
        ? null
        : jsonString(j['recordingPath'], 'recordingPath'),
  );
}
