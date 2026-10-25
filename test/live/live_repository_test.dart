import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/live_repository.dart';

void main() {
  late TinglangDatabase db;
  late LiveRepository repo;
  setUp(() {
    db = TinglangDatabase.memory();
    repo = LiveRepository(db);
  });
  tearDown(() => db.close());

  Future<void> session(String id, {String origin = 'live_system'}) => repo.createSession(
    id: id,
    origin: origin,
    language: 'en',
    title: '',
    startedAt: DateTime.utc(2026, 10, 21, 9),
  );

  test('each session previews its first saved line', () async {
    await session('a');
    await session('b');
    await session('c');
    await repo.addSegments('a', [
      (id: 'a-0', startMs: 0, endMs: 900, text: 'First words.', language: 'en', wordsJson: null),
      (id: 'a-1', startMs: 1000, endMs: 1900, text: 'Then more.', language: 'en', wordsJson: null),
    ]);
    await repo.addSegments('b', [
      (id: 'b-0', startMs: 0, endMs: 900, text: 'Only line.', language: 'en', wordsJson: null),
    ]);
    expect(await repo.firstLines(['a', 'b', 'c']), {'a': 'First words.', 'b': 'Only line.'});
    expect(await repo.firstLines([]), isEmpty);
  });

  test('finals append across batches with increasing seq; translations join', () async {
    await session('s1');
    await repo.addSegments('s1', [
      (id: 's1-0', startMs: 0, endMs: 900, text: 'Hello there.', language: 'en', wordsJson: null),
    ]);
    await repo.addSegments('s1', [
      (
        id: 's1-1',
        startMs: 1000,
        endMs: 2000,
        text: 'General Kenobi.',
        language: 'en',
        wordsJson: null,
      ),
    ]);
    await repo.addTranslations([
      (segmentId: 's1-1', target: 'zh-Hans', text: '肯诺比将军。', provider: 'apple_translation'),
    ]);
    final lines = await repo.lines('s1');
    expect(lines.map((l) => l.text), ['Hello there.', 'General Kenobi.']);
    expect(lines.map((l) => l.translation), [null, '肯诺比将军。']);
    final seqs = await (db.select(db.segments)..orderBy([(s) => OrderingTerm.asc(s.seq)])).get();
    expect(seqs.map((s) => s.seq), [0, 1]);
  });

  test('a re-sent final is ignored rather than failing the batch', () async {
    await session('s1');
    final seg = (
      id: 's1-0',
      startMs: 0,
      endMs: 900,
      text: 'Hello.',
      language: 'en',
      wordsJson: null,
    );
    await repo.addSegments('s1', [seg]);
    await repo.addSegments('s1', [seg]);
    expect(await repo.lines('s1'), hasLength(1));
  });

  test('active sessions become interrupted on the next launch', () async {
    await session('crashed');
    await session('done');
    await repo.endSession('done', status: 'completed', endedAt: DateTime.utc(2026));
    expect(await repo.markInterrupted(), 1);
    final rows = {for (final s in await repo.recentSessions()) s.id: s.status};
    expect(rows, {'crashed': 'interrupted', 'done': 'completed'});
  });

  test('delete cascades to segments, translations and the search index', () async {
    await session('s1');
    await repo.addSegments('s1', [
      (
        id: 's1-0',
        startMs: 0,
        endMs: 900,
        text: 'Searchable sentence here.',
        language: 'en',
        wordsJson: null,
      ),
    ]);
    await repo.addTranslations([
      (segmentId: 's1-0', target: 'zh-Hans', text: '可搜索的句子。', provider: 'apple_translation'),
    ]);
    expect(await db.searchSegments('sentence'), hasLength(1));
    await repo.deleteSession('s1');
    expect(await db.select(db.segments).get(), isEmpty);
    expect(await db.select(db.translations).get(), isEmpty);
    expect(await db.searchSegments('sentence'), isEmpty);
  });

  test('recent sessions list live and imported-file sessions, newest first', () async {
    await session('old');
    await repo.createSession(
      id: 'new',
      origin: 'live_mic',
      language: 'zh-Hans',
      title: 'Mic',
      startedAt: DateTime.utc(2026, 10, 22),
    );
    await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            id: 'file',
            origin: 'file',
            timeBase: 'media',
            startedAt: DateTime.utc(2027),
          ),
        );
    expect((await repo.recentSessions()).map((s) => s.id), ['file', 'new', 'old']);
  });
}
