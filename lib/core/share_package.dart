import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'course_codec.dart';
import 'library_store.dart';
import 'live_repository.dart';
import 'models.dart';

/// One recording or course in a single `.tinglang` file (a zip) that can be
/// sent by chat or AirDrop and imported on another Mac:
///
/// - `manifest.json`: format, version, kind (`session` or `course`), title,
///   language, dates and the media entry name (if any);
/// - `transcript.json` (session): timed lines, word timings, translations;
/// - `course.json` (course): the English V3 document as imported;
/// - `media/<file>`: the audio or video, optional, stored uncompressed.
///
/// Packages written for iCloud Drive sync add (version 1 readers ignore
/// them) a `sync` stamp (kind, key, content hash, time, device) and the
/// session's own ids, so another Mac keeps the same session and line ids.
///
/// Imports never trust names inside the zip: only these entries are read,
/// media keeps only its extension, and sizes are capped. Zip work runs in a
/// background isolate, so large media never blocks the window.
abstract final class SharePackage {
  static const extension = 'tinglang';
  static const format = 'tinglang.share';
  static const version = 1;
  static const maxJsonBytes = 20 * 1024 * 1024;
  static const maxMediaBytes = 4 * 1024 * 1024 * 1024;
}

enum ShareProblem { notAPackage, newerVersion, missingContent, tooLarge, unsupportedMedia }

final class ShareFailure implements Exception {
  const ShareFailure(this.problem);
  final ShareProblem problem;
  @override
  String toString() => 'Share package: ${problem.name}';
}

/// What an import produced.
sealed class SharedItem {
  const SharedItem();
}

final class SharedSession extends SharedItem {
  const SharedSession(this.sessionId);
  final String sessionId;
}

final class SharedCourse extends SharedItem {
  const SharedCourse(this.course);
  final Course course;
}

/// Packs a saved session (lines, translations, media) into [destination].
///
/// With [sync] (a stamp from the sync engine) the package also carries the
/// session's ids, origin, status and source reference, so the copy on
/// another Mac is the same session rather than a new shared one.
Future<void> exportSessionPackage({
  required LiveRepository repository,
  required LibraryStore store,
  required String sessionId,
  required String title,
  required String destination,
  Map<String, Object?>? sync,
}) async {
  final session = await repository.session(sessionId);
  if (session == null) throw const ShareFailure(ShareProblem.missingContent);
  final lines = await repository.lines(sessionId);
  final translations = await repository.translationsOf(sessionId);
  final targets = {for (final byTarget in translations.values) ...byTarget.keys};
  final single = targets.length == 1 ? targets.single : null;
  final media = session.mediaId == null ? null : await repository.media(session.mediaId!);
  final mediaFile = media?.relPath == null ? null : File(store.resolve(media!.relPath!));
  final mediaName = mediaFile != null && await mediaFile.exists()
      ? 'media/media${p.extension(mediaFile.path)}'
      : null;
  final manifest = {
    'format': SharePackage.format,
    'version': SharePackage.version,
    'kind': 'session',
    'title': title,
    'language': session.language,
    'translationLanguage': single,
    'recorded': session.startedAt.toUtc().toIso8601String(),
    'created': DateTime.now().toUtc().toIso8601String(),
    'media': mediaName,
    'mediaKind': media?.kind,
    'durationMs': media?.durationMs,
    if (sync != null) ...{
      'sync': sync,
      'session': {
        'id': session.id,
        'origin': session.origin,
        'status': session.status,
        'timeBase': mediaName == null ? 'wallclock' : session.timeBase,
        'started': session.startedAt.toUtc().toIso8601String(),
        'ended': session.endedAt?.toUtc().toIso8601String(),
        'sourceRef': session.sourceRef,
        'title': session.title,
      },
    },
  };
  final transcript = {
    'lines': [
      for (final line in lines)
        {
          if (sync != null) 'id': line.segmentId,
          'start': line.startMs,
          'end': line.endMs,
          'text': line.text,
          if (single != null && translations[line.segmentId]?[single] != null)
            'translation': translations[line.segmentId]![single],
          if (translations[line.segmentId]?.isNotEmpty ?? false)
            'translations': translations[line.segmentId],
          if (line.wordsJson != null) 'words': jsonDecode(line.wordsJson!),
        },
    ],
  };
  await writeSharePackage(
    destination,
    manifest,
    {'transcript.json': transcript},
    media: mediaName == null ? null : mediaFile!.path,
    mediaName: mediaName,
  );
}

/// Packs a course (its original JSON) and its media into [destination].
/// [sync] adds the sync stamp and the course's source label and import time.
Future<void> exportCoursePackage({
  required Course course,
  required LibraryStore store,
  required String destination,
  Map<String, Object?>? sync,
}) async {
  final mediaFile = course.mediaPath == null ? null : File(store.resolve(course.mediaPath!));
  final mediaName = mediaFile != null && await mediaFile.exists()
      ? 'media/media${p.extension(mediaFile.path)}'
      : null;
  final manifest = {
    'format': SharePackage.format,
    'version': SharePackage.version,
    'kind': 'course',
    'title': course.title,
    'area': course.area.name,
    'created': DateTime.now().toUtc().toIso8601String(),
    'media': mediaName,
    if (sync != null) ...{
      'sync': sync,
      'course': {
        'id': course.id,
        'sourceLabel': course.sourceLabel,
        'imported': course.importedAt.toUtc().toIso8601String(),
      },
    },
  };
  await writeSharePackage(
    destination,
    manifest,
    {'course.json': course.raw},
    media: mediaName == null ? null : mediaFile!.path,
    mediaName: mediaName,
  );
}

/// Writes a package in a background isolate: first to a temporary file, then
/// moved into place, so [destination] is never half written (which matters
/// in a synced folder).
Future<void> writeSharePackage(
  String destination,
  Map<String, Object?> manifest,
  Map<String, Object?> documents, {
  String? media,
  String? mediaName,
}) {
  final temp = Directory.systemTemp.path;
  return Isolate.run(() => _writePackage(temp, destination, manifest, documents, media, mediaName));
}

void _writePackage(
  String tempFolder,
  String destination,
  Map<String, Object?> manifest,
  Map<String, Object?> documents,
  String? media,
  String? mediaName,
) {
  final part = p.join(tempFolder, 'tinglang-${DateTime.now().microsecondsSinceEpoch}-$pid.partial');
  try {
    final encoder = ZipFileEncoder()..create(part);
    InputFileStream? input;
    try {
      encoder.addArchiveFile(ArchiveFile.string('manifest.json', jsonEncode(manifest)));
      for (final entry in documents.entries) {
        encoder.addArchiveFile(ArchiveFile.string(entry.key, jsonEncode(entry.value)));
      }
      if (media != null && mediaName != null) {
        // Audio and video are already compressed; storing them streams the
        // file instead of deflating it in memory.
        input = InputFileStream(media);
        encoder.addArchiveFile(
          ArchiveFile.stream(mediaName, input)..compression = CompressionType.none,
        );
      }
    } finally {
      encoder.closeSync();
      input?.closeSync();
    }
    try {
      File(part).renameSync(destination);
    } on FileSystemException {
      // Another volume: copy next to the destination, then rename there.
      final near = '$destination.${DateTime.now().microsecondsSinceEpoch}.partial';
      try {
        File(part).copySync(near);
        File(near).renameSync(destination);
      } finally {
        if (File(near).existsSync()) File(near).deleteSync();
      }
    }
  } finally {
    if (File(part).existsSync()) File(part).deleteSync();
  }
}

/// A package's checked contents. Media (if any) is extracted into a
/// temporary folder that [close] removes.
final class SharePackageContents {
  SharePackageContents._(this.manifest, this.documents, this.media, this._temp);
  final Map<String, Object?> manifest;
  final Map<String, Map<String, Object?>> documents;

  /// The extracted media (only the manifest's entry under `media/`).
  final File? media;
  final Directory _temp;

  String? get kind => manifest['kind'] as String?;
  String get title => (manifest['title'] as String?)?.trim() ?? '';

  /// The sync stamp of a package written by the sync engine, else null.
  Map<String, Object?>? get sync => _object(manifest['sync']);

  Map<String, Object?> document(String name) =>
      documents[name] ?? (throw const ShareFailure(ShareProblem.missingContent));

  Future<void> close() async {
    try {
      await _temp.delete(recursive: true);
    } on FileSystemException {
      // Already gone.
    }
  }
}

Map<String, Object?>? _object(Object? value) => value is Map<String, Object?> ? value : null;

/// Opens and checks [package] in a background isolate. Throws [ShareFailure].
Future<SharePackageContents> readSharePackage(File package) async {
  final temp = await Directory.systemTemp.createTemp('tinglang-share-');
  final path = package.path, folder = temp.path;
  try {
    final read = await Isolate.run(() => _readPackage(path, folder));
    return SharePackageContents._(
      read.manifest,
      read.documents,
      read.media == null ? null : File(read.media!),
      temp,
    );
  } catch (_) {
    await temp.delete(recursive: true);
    rethrow;
  }
}

({Map<String, Object?> manifest, Map<String, Map<String, Object?>> documents, String? media})
_readPackage(String path, String folder) {
  final input = InputFileStream(path);
  try {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeStream(input);
    } on Object {
      throw const ShareFailure(ShareProblem.notAPackage);
    }
    ArchiveFile? entry(String name) =>
        archive.files.where((f) => f.isFile && f.name == name).firstOrNull;
    Map<String, Object?> json(ArchiveFile file) {
      if (file.size > SharePackage.maxJsonBytes) throw const ShareFailure(ShareProblem.tooLarge);
      final Object? value;
      try {
        value = jsonDecode(utf8.decode(file.readBytes() ?? const []));
      } on FormatException {
        throw const ShareFailure(ShareProblem.notAPackage);
      }
      if (value is! Map<String, Object?>) throw const ShareFailure(ShareProblem.notAPackage);
      return value;
    }

    // Anything without a manifest (another zip, or not a zip at all, which
    // decodes as empty) is not a share file.
    final manifestEntry = entry('manifest.json');
    if (manifestEntry == null) throw const ShareFailure(ShareProblem.notAPackage);
    final manifest = json(manifestEntry);
    if (manifest['format'] != SharePackage.format) {
      throw const ShareFailure(ShareProblem.notAPackage);
    }
    if ((manifest['version'] as num? ?? 0) > SharePackage.version) {
      throw const ShareFailure(ShareProblem.newerVersion);
    }
    final documents = <String, Map<String, Object?>>{
      for (final name in const ['transcript.json', 'course.json'])
        if (entry(name) case final file?) name: json(file),
    };
    // Media: only the entry the manifest names, under media/, and only its
    // extension is kept (importMedia checks it against the allow-list).
    String? media;
    final mediaName = manifest['media'];
    if (mediaName is String && mediaName.startsWith('media/') && !mediaName.contains('..')) {
      final file = entry(mediaName);
      if (file != null) {
        if (file.size > SharePackage.maxMediaBytes) {
          throw const ShareFailure(ShareProblem.tooLarge);
        }
        media = p.join(folder, 'media${p.extension(mediaName).toLowerCase()}');
        final out = OutputFileStream(media);
        file.writeContent(out);
        out.closeSync();
      }
    }
    return (manifest: manifest, documents: documents, media: media);
  } finally {
    input.closeSync();
  }
}

/// Copies the package's media into the library (content-addressed); null
/// without media. Throws [ShareFailure] for a type the library refuses.
Future<String?> importPackageMedia(SharePackageContents contents, LibraryStore store) async {
  final media = contents.media;
  if (media == null) return null;
  try {
    return await store.importMedia(media);
  } on FormatException {
    throw const ShareFailure(ShareProblem.unsupportedMedia);
  }
}

/// The course in a package, with its media copied into [store].
Future<Course> coursePackageCourse(SharePackageContents contents, LibraryStore store) async {
  final document = contents.document('course.json');
  final mediaRelative = await importPackageMedia(contents, store);
  final extra = _object(contents.manifest['course']);
  final imported = DateTime.tryParse(extra?['imported'] as String? ?? '');
  // A course that does not validate throws the codec's FormatException.
  return const CourseCodec().fromMap(
    document,
    area: Area.values.asNameMap()[contents.manifest['area']] ?? Area.life,
    mediaPath: mediaRelative,
    sourceLabel: extra?['sourceLabel'] as String?,
    importedAt: imported?.toUtc(),
  );
}

/// Lines and translations of a session package. With [ids] the lines keep
/// the ids in the package (sync); otherwise they are numbered under it.
({
  List<NewSegment> segments,
  List<({String segmentId, String target, String text, String provider})> translations,
})
sessionPackageLines(
  SharePackageContents contents, {
  required String sessionId,
  required String language,
  required String provider,
  bool ids = false,
}) {
  final transcript = contents.document('transcript.json');
  final lines = (transcript['lines'] as List<Object?>? ?? const [])
      .whereType<Map<String, Object?>>()
      .toList();
  final segments = <NewSegment>[];
  final translations = <({String segmentId, String target, String text, String provider})>[];
  final target = contents.manifest['translationLanguage'] as String?;
  for (final (index, line) in lines.indexed) {
    final text = line['text'];
    final start = line['start'], end = line['end'];
    if (text is! String || start is! num || end is! num) continue;
    final ownId = line['id'];
    final id = ids && ownId is String && ownId.isNotEmpty ? ownId : '$sessionId-$index';
    final words = line['words'];
    segments.add((
      id: id,
      startMs: start.toInt(),
      endMs: end.toInt(),
      text: text,
      language: language,
      wordsJson: words is List ? jsonEncode(words) : null,
    ));
    final all = _object(line['translations']);
    if (all != null && all.isNotEmpty) {
      for (final MapEntry(key: lang, value: body) in all.entries) {
        if (body is String) {
          translations.add((segmentId: id, target: lang, text: body, provider: provider));
        }
      }
    } else if (line['translation'] case final String body when target != null) {
      translations.add((segmentId: id, target: target, text: body, provider: provider));
    }
  }
  return (segments: segments, translations: translations);
}

/// Registers the package's media in [repository] (idempotent); its id.
Future<String?> _registerMedia(
  SharePackageContents contents,
  String? mediaRelative,
  LiveRepository repository,
) async {
  if (mediaRelative == null) return null;
  final mediaId = p.basenameWithoutExtension(mediaRelative);
  if (await repository.media(mediaId) == null) {
    await repository.addMedia(
      id: mediaId,
      kind: contents.manifest['mediaKind'] == 'video' ? 'video' : 'audio',
      relPath: mediaRelative,
      sha256: mediaId,
      durationMs: (contents.manifest['durationMs'] as num?)?.toInt(),
      title: contents.title,
    );
  }
  return mediaId;
}

/// Reads a package: a session goes into [repository] with its media copied
/// into [store]; a course is returned for the caller to save (so learner
/// records are kept by the usual upsert).
Future<SharedItem> importSharePackage(
  File package, {
  required LiveRepository repository,
  required LibraryStore store,
  required String fallbackLanguage,
}) async {
  final contents = await readSharePackage(package);
  try {
    switch (contents.kind) {
      case 'course':
        return SharedCourse(await coursePackageCourse(contents, store));
      case 'session':
        contents.document('transcript.json');
        final mediaId = await _registerMedia(
          contents,
          await importPackageMedia(contents, store),
          repository,
        );
        final language = contents.manifest['language'] as String? ?? fallbackLanguage;
        final sessionId = newId();
        final recorded = DateTime.tryParse(contents.manifest['recorded'] as String? ?? '');
        await repository.createSession(
          id: sessionId,
          origin: 'shared',
          language: language,
          title: contents.title,
          startedAt: (recorded ?? DateTime.now()).toUtc(),
          timeBase: mediaId == null ? 'wallclock' : 'media',
          mediaId: mediaId,
        );
        final (:segments, :translations) = sessionPackageLines(
          contents,
          sessionId: sessionId,
          language: language,
          provider: 'shared',
        );
        await repository.addSegments(sessionId, segments);
        await repository.addTranslations(translations);
        final ended = segments.isEmpty
            ? Duration.zero
            : Duration(milliseconds: segments.last.endMs);
        await repository.endSession(
          sessionId,
          status: 'completed',
          endedAt: (recorded ?? DateTime.now()).toUtc().add(ended),
        );
        return SharedSession(sessionId);
      default:
        throw const ShareFailure(ShareProblem.notAPackage);
    }
  } finally {
    await contents.close();
  }
}

/// Writes the session in a sync package as the same session (same id, line
/// ids, origin, status and source reference), creating or updating it in
/// place so its dictation answers stay. Returns the session id.
Future<String> importSyncedSession(
  SharePackageContents contents, {
  required LiveRepository repository,
  required LibraryStore store,
  required String fallbackLanguage,
}) async {
  final info = _object(contents.manifest['session']);
  final id = info?['id'];
  if (contents.kind != 'session' || id is! String || id.isEmpty) {
    throw const ShareFailure(ShareProblem.missingContent);
  }
  contents.document('transcript.json');
  final mediaId = await _registerMedia(
    contents,
    await importPackageMedia(contents, store),
    repository,
  );
  final language = contents.manifest['language'] as String? ?? fallbackLanguage;
  final (:segments, :translations) = sessionPackageLines(
    contents,
    sessionId: id,
    language: language,
    provider: 'sync',
    ids: true,
  );
  final started =
      DateTime.tryParse(info!['started'] as String? ?? '') ??
      DateTime.tryParse(contents.manifest['recorded'] as String? ?? '') ??
      DateTime.now();
  final ended = DateTime.tryParse(info['ended'] as String? ?? '');
  final origin = info['origin'];
  final status = info['status'];
  await repository.importSessionCopy(
    id: id,
    origin: origin is String && origin.isNotEmpty ? origin : 'shared',
    language: language,
    title: info['title'] as String? ?? contents.title,
    startedAt: started.toUtc(),
    endedAt: ended?.toUtc(),
    status: status == 'interrupted' ? 'interrupted' : 'completed',
    timeBase: mediaId == null ? 'wallclock' : (info['timeBase'] as String? ?? 'media'),
    mediaId: mediaId,
    sourceRef: info['sourceRef'] as String?,
    segments: segments,
    translations: translations,
  );
  return id;
}
