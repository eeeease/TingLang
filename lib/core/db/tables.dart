import 'package:drift/drift.dart';

// Schema v1. Times inside media are integer milliseconds on the session's
// time base; wall-clock timestamps are stored as ISO-8601 text (UTC).
// Learner records (progress, attempt, card) deliberately have no foreign key
// to course content: removing or re-importing a course must not delete them.

/// App-owned media files (and remote media referenced by URL).
@DataClassName('MediaRow')
class Media extends Table {
  @override
  String get tableName => 'media';
  TextColumn get id => text()();

  /// `audio` or `video`.
  TextColumn get kind => text()();

  /// Relative to the library root; null for not-yet-downloaded remote media.
  TextColumn get relPath => text().nullable()();
  TextColumn get sha256 => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get sourceUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

/// One recording/recognition run: live captions, an import, a dictation.
@DataClassName('SessionRow')
class Sessions extends Table {
  @override
  String get tableName => 'session';
  TextColumn get id => text()();
  TextColumn get mediaId => text().nullable().references(Media, #id, onDelete: KeyAction.setNull)();

  /// `live_system`, `live_mic`, `file`, `voice_memo`, `shared`, `recording`,
  /// `youtube`.
  TextColumn get origin => text()();

  /// `media` (offsets into [mediaId]) or `wallclock` (from [startedAt]).
  TextColumn get timeBase => text()();
  TextColumn get language => text().nullable()();
  TextColumn get title => text().withDefault(const Constant(''))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// `active`, `completed`, `interrupted` (set on next launch after a crash).
  TextColumn get status => text().withDefault(const Constant('active'))();

  /// What an import came from, so it is not imported twice: `voicememo:<id>`
  /// for Apple Voice Memos. Null for captures and plain files.
  TextColumn get sourceRef => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Maps session time to media time (e.g. ASR clock → YouTube clock).
@DataClassName('TimeAnchorRow')
class TimeAnchors extends Table {
  @override
  String get tableName => 'time_anchor';
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text().references(Sessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get sessionMs => integer()();
  IntColumn get mediaMs => integer().nullable()();
  DateTimeColumn get wallclock => dateTime().nullable()();
}

/// Finalised recognised sentences. Partials are never stored. Indexed by
/// the `segment_fts` FTS5 trigram table (see database.dart).
@DataClassName('SegmentRow')
class Segments extends Table {
  @override
  String get tableName => 'segment';
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(Sessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get seq => integer()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
  TextColumn get body => text()();
  TextColumn get language => text().nullable()();

  /// `[{"w":"word","s":ms,"e":ms}]` only when the backend produced it.
  TextColumn get wordsJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {sessionId, seq},
  ];
}

@DataClassName('TranslationRow')
class Translations extends Table {
  @override
  String get tableName => 'translation';
  IntColumn get id => integer().autoIncrement()();
  TextColumn get segmentId => text().references(Segments, #id, onDelete: KeyAction.cascade)();
  TextColumn get targetLang => text()();
  TextColumn get body => text()();
  TextColumn get provider => text()();

  /// `preview` (debounced partial context) or `final`.
  TextColumn get quality => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  List<Set<Column>> get uniqueKeys => [
    {segmentId, targetLang, quality},
  ];
}

/// Imported course; [rawJson] is the full original document (source of
/// truth). clip/item rows are a queryable projection of it.
@DataClassName('CourseRow')
class Courses extends Table {
  @override
  String get tableName => 'course';
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get area => text()();
  TextColumn get rawJson => text()();
  TextColumn get mediaPath => text().nullable()();
  TextColumn get sourceLabel => text().withDefault(const Constant(''))();
  DateTimeColumn get importedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ClipRow')
class Clips extends Table {
  @override
  String get tableName => 'clip';
  TextColumn get courseId => text().references(Courses, #id, onDelete: KeyAction.cascade)();
  TextColumn get id => text()();
  IntColumn get ord => integer()();
  TextColumn get title => text()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer().nullable()();
  TextColumn get transcript => text()();
  @override
  Set<Column> get primaryKey => {courseId, id};
}

@DataClassName('ItemRow')
class Items extends Table {
  @override
  String get tableName => 'item';
  TextColumn get courseId => text().references(Courses, #id, onDelete: KeyAction.cascade)();
  TextColumn get clipId => text()();
  TextColumn get id => text()();

  /// `words`, `phrases`, `sentences`.
  TextColumn get kind => text()();
  TextColumn get body => text()();
  TextColumn get meaning => text().withDefault(const Constant(''))();
  @override
  Set<Column> get primaryKey => {courseId, id};
}

/// Generated or authored exercises (cloze, recall, dictation…), from M4.
@DataClassName('ExerciseRow')
class Exercises extends Table {
  @override
  String get tableName => 'exercise';
  TextColumn get id => text()();
  TextColumn get courseId => text().nullable()();
  TextColumn get clipId => text().nullable()();
  TextColumn get sessionId => text().nullable()();
  TextColumn get kind => text()();
  TextColumn get dataJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Learner's own completion marks per clip step.
@DataClassName('ProgressRow')
class Progress extends Table {
  @override
  String get tableName => 'progress';
  TextColumn get courseId => text()();
  TextColumn get clipId => text()();
  TextColumn get step => text()();
  @override
  Set<Column> get primaryKey => {courseId, clipId, step};
}

@DataClassName('AttemptRow')
class Attempts extends Table {
  @override
  String get tableName => 'attempt';
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get kind => text()();
  TextColumn get note => text()();
  IntColumn get durationMs => integer()();
  TextColumn get courseId => text().nullable()();
  TextColumn get clipId => text().nullable()();
  TextColumn get recordingPath => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Review card. [scheduler] is `ladder` (MVP self-rated intervals) until
/// the FSRS fields are filled by M4.
@DataClassName('CardRow')
class Cards extends Table {
  @override
  String get tableName => 'card';
  TextColumn get id => text()();
  TextColumn get courseId => text()();
  TextColumn get clipId => text()();
  TextColumn get body => text()();
  TextColumn get meaning => text()();
  DateTimeColumn get dueAt => dateTime()();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  TextColumn get scheduler => text().withDefault(const Constant('ladder'))();
  RealColumn get stability => real().nullable()();
  RealColumn get difficulty => real().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ReviewLogRow')
class ReviewLogs extends Table {
  @override
  String get tableName => 'review_log';
  TextColumn get cardId => text().references(Cards, #id, onDelete: KeyAction.cascade)();
  IntColumn get seq => integer()();
  DateTimeColumn get reviewedAt => dateTime().nullable()();
  TextColumn get rating => text()();

  /// The original history entry, kept verbatim.
  TextColumn get dataJson => text()();
  @override
  Set<Column> get primaryKey => {cardId, seq};
}

/// A user-configured provider (BYOK LLM, cloud ASR, local server). Secrets
/// live in the OS secret store; [secretRef] is only the lookup key.
@DataClassName('ProviderConfigRow')
class ProviderConfigs extends Table {
  @override
  String get tableName => 'provider_config';
  TextColumn get id => text()();

  /// `llm`, `asr`, `translation`.
  TextColumn get kind => text()();
  TextColumn get preset => text()();
  TextColumn get label => text()();
  TextColumn get baseUrl => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get secretRef => text().nullable()();
  BoolColumn get cloud => boolean().withDefault(const Constant(true))();

  /// Off until the user explicitly enables it.
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Which provider a feature (course generation, live translation…) uses.
@DataClassName('FeatureRouteRow')
class FeatureRoutes extends Table {
  @override
  String get tableName => 'feature_route';
  TextColumn get feature => text()();
  TextColumn get providerId =>
      text().nullable().references(ProviderConfigs, #id, onDelete: KeyAction.setNull)();
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {feature};
}

/// LLM responses keyed by a hash of (provider, model, prompt, input).
@DataClassName('LlmCacheRow')
class LlmCache extends Table {
  @override
  String get tableName => 'llm_cache';
  TextColumn get key => text()();
  TextColumn get providerId => text()();
  TextColumn get model => text()();
  TextColumn get responseJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('PodcastFeedRow')
class PodcastFeeds extends Table {
  @override
  String get tableName => 'podcast_feed';
  TextColumn get id => text()();
  TextColumn get url => text().unique()();
  TextColumn get title => text()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get etag => text().nullable()();
  DateTimeColumn get lastFetchedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('EpisodeRow')
class Episodes extends Table {
  @override
  String get tableName => 'episode';
  TextColumn get id => text()();
  TextColumn get feedId => text().references(PodcastFeeds, #id, onDelete: KeyAction.cascade)();
  TextColumn get guid => text()();
  TextColumn get title => text()();
  TextColumn get audioUrl => text()();
  DateTimeColumn get publishedAt => dateTime().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get mediaId => text().nullable().references(Media, #id, onDelete: KeyAction.setNull)();

  /// `new`, `downloaded`, `transcribed`, `course`.
  TextColumn get status => text().withDefault(const Constant('new'))();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {feedId, guid},
  ];
}

@DataClassName('DraftRow')
class Drafts extends Table {
  @override
  String get tableName => 'draft';
  TextColumn get key => text()();
  TextColumn get body => text()();
  @override
  Set<Column> get primaryKey => {key};
}

/// Small key/value store: last opened clip, UI settings, migration marks.
@DataClassName('MetaRow')
class AppMeta extends Table {
  @override
  String get tableName => 'app_meta';
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

/// Dictation answers for transcript sentences (schema v2). Like other
/// learner records it survives deleting nothing but its own session.
@DataClassName('DictationAttemptRow')
class DictationAttempts extends Table {
  @override
  String get tableName => 'dictation_attempt';
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(Sessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get segmentId => text()();
  TextColumn get answer => text()();

  /// `correct`, `close` or `incorrect`.
  TextColumn get result => text()();
  RealColumn get similarity => real()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

/// What iCloud Drive sync last knew about each synced item and learner
/// record (schema v4). On this Mac only: the database itself never goes to
/// iCloud. One row per (kind, key); see docs/ARCHITECTURE.md "iCloud Drive
/// sync".
@DataClassName('SyncRecordRow')
class SyncRecords extends Table {
  @override
  String get tableName => 'sync_record';

  /// `course`, `session`, `progress`, `draft`, `card`, `attempt`,
  /// `dictation`.
  TextColumn get kind => text()();
  TextColumn get key => text()();

  /// Hash of the local copy as it was when it matched this version; null
  /// once deleted. A different hash later means a change made on this Mac.
  TextColumn get localHash => text().nullable()();

  /// The version this Mac has: when it was made (ms since the epoch, UTC)
  /// and on which device. Newer (time, then device id) wins.
  IntColumn get updatedAt => integer()();
  TextColumn get device => text()();

  /// The version is a deletion (a tombstone).
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// Content hash published with the version; packages are checked against it.
  TextColumn get hash => text().nullable()();
  @override
  Set<Column> get primaryKey => {kind, key};
}
