import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'course_codec.dart';
import 'json_helpers.dart';
import 'models.dart';
import 'review.dart';

String newId() {
  final random = Random.secure();
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
      '${random.nextInt(1 << 30).toRadixString(36)}';
}

class LibraryState {
  LibraryState({
    List<Course>? courses,
    List<PracticeAttempt>? attempts,
    Map<String, Set<String>>? completed,
    Map<String, String>? drafts,
    List<ReviewCard>? reviews,
    Map<String, String>? settings,
    this.lastCourseId,
    this.lastClipId,
  }) : courses = courses ?? [],
       attempts = attempts ?? [],
       completed = completed ?? {},
       drafts = drafts ?? {},
       reviews = reviews ?? [],
       settings = settings ?? {};
  final List<Course> courses;
  final List<PracticeAttempt> attempts;
  final Map<String, Set<String>> completed;
  final Map<String, String> drafts;
  final List<ReviewCard> reviews;

  /// UI preferences (interface language, theme, learning language).
  final Map<String, String> settings;
  String? lastCourseId, lastClipId;

  LibraryState clone() => LibraryState(
    courses: [...courses],
    attempts: [...attempts],
    completed: {
      for (final e in completed.entries) e.key: {...e.value},
    },
    drafts: {...drafts},
    reviews: [...reviews],
    settings: {...settings},
    lastCourseId: lastCourseId,
    lastClipId: lastClipId,
  );

  Map<String, Object?> toJson() => {
    'store_version': 1,
    'courses': courses.map((c) => c.toJson()).toList(),
    'attempts': attempts.map((a) => a.toJson()).toList(),
    'completed': {for (final e in completed.entries) e.key: e.value.toList()},
    'drafts': drafts,
    'reviews': reviews.map((r) => r.toJson()).toList(),
    'settings': settings,
    'lastCourseId': lastCourseId,
    'lastClipId': lastClipId,
  };

  factory LibraryState.fromJson(Map<String, Object?> json) {
    if (jsonInt(json['store_version'], 'store_version') != 1) {
      throw const FormatException('Unsupported library version; do not overwrite it.');
    }
    const codec = CourseCodec();
    return LibraryState(
      courses: jsonList(json['courses'], 'courses').map((entry) {
        final j = jsonObject(entry, 'stored course');
        return codec.fromMap(
          jsonObject(j['raw'], 'raw'),
          area: Area.parse(jsonString(j['area'], 'area')),
          importedAt: DateTime.parse(jsonString(j['importedAt'], 'importedAt')),
          mediaPath: j['mediaPath'] == null ? null : jsonString(j['mediaPath'], 'mediaPath'),
          sourceLabel: jsonString(j['sourceLabel'], 'sourceLabel', fallback: ''),
        );
      }).toList(),
      attempts: jsonList(
        json['attempts'],
        'attempts',
      ).map((entry) => PracticeAttempt.fromJson(jsonObject(entry, 'attempt'))).toList(),
      completed: jsonObject(json['completed'], 'completed').map(
        (key, value) => MapEntry(
          key,
          jsonList(value, 'completed steps').map((v) => jsonString(v, 'step')).toSet(),
        ),
      ),
      drafts: jsonObject(
        json['drafts'],
        'drafts',
      ).map((key, value) => MapEntry(key, jsonString(value, 'draft'))),
      reviews: jsonList(
        json['reviews'],
        'reviews',
      ).map((entry) => ReviewCard.fromJson(jsonObject(entry, 'review'))).toList(),
      // Added after store_version 1 shipped; optional so older files still load.
      settings: jsonObject(
        json['settings'] ?? <String, Object?>{},
        'settings',
      ).map((key, value) => MapEntry(key, jsonString(value, 'setting'))),
      lastCourseId: json['lastCourseId'] == null
          ? null
          : jsonString(json['lastCourseId'], 'lastCourseId'),
      lastClipId: json['lastClipId'] == null ? null : jsonString(json['lastClipId'], 'lastClipId'),
    );
  }
}

class LibraryReadException implements Exception {
  const LibraryReadException(this.path, this.cause);
  final String path;
  final Object cause;
  @override
  String toString() => 'Cannot read $path. The original file was NOT changed. $cause';
}

/// 单个进程通过 AppController 串行写入。以临时文件 + rename 提交，保留上一版备份。
class LibraryStore {
  LibraryStore(this.root);
  final Directory root;
  File get stateFile => File(p.join(root.path, 'library.json'));

  /// Releases the backing storage before the process exits (no-op for
  /// the JSON store).
  Future<void> close() async {}

  Future<LibraryState> load() async {
    await root.create(recursive: true);
    if (!await stateFile.exists()) return LibraryState();
    try {
      final loaded = LibraryState.fromJson(
        jsonObject(jsonDecode(await stateFile.readAsString()), 'library'),
      );
      for (final course in loaded.courses) {
        final media = course.mediaPath;
        if (media != null) resolve(media);
      }
      for (final attempt in loaded.attempts) {
        final recording = attempt.recordingPath;
        if (recording != null) resolve(recording);
      }
      return loaded;
    } catch (error) {
      throw LibraryReadException(stateFile.path, error);
    }
  }

  Future<void> save(LibraryState state) async {
    await root.create(recursive: true);
    final temporary = File('${stateFile.path}.${newId()}.tmp');
    try {
      await temporary.writeAsString(
        const JsonEncoder.withIndent('  ').convert(state.toJson()),
        flush: true,
      );
      if (await stateFile.exists()) {
        await stateFile.copy('${stateFile.path}.bak');
      }
      // 同文件系统的 rename 在 macOS 上替换现有文件，不先删除旧记录。
      await temporary.rename(stateFile.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  String resolve(String relative) {
    if (p.isAbsolute(relative) || relative.contains('\\')) {
      throw const FormatException('Only app-owned relative file paths are allowed.');
    }
    final result = p.normalize(p.join(root.absolute.path, relative));
    if (!p.isWithin(root.absolute.path, result)) {
      throw const FormatException('File path escapes the library directory.');
    }
    return result;
  }

  /// 对大文件进行流式哈希并复制到应用目录；不保留外部路径或依赖安全书签。
  Future<String> importMedia(File source) async {
    if (!await source.exists()) throw const FileSystemException('Selected media no longer exists.');
    final digest = await sha256.bind(source.openRead()).first;
    final extension = p.extension(source.path).toLowerCase();
    const allowed = {
      '.mp4',
      '.mov',
      '.m4v',
      '.mkv',
      '.webm',
      '.mp3',
      '.wav',
      '.m4a',
      '.qta',
      '.aac',
      '.flac',
      '.ogg',
      '.aiff',
      '.aif',
    };
    if (!allowed.contains(extension)) throw const FormatException('Unsupported media extension.');
    final relative = 'media/$digest$extension';
    final target = File(resolve(relative));
    if (await target.exists()) return relative;
    await target.parent.create(recursive: true);
    final part = File('${target.path}.${newId()}.partial');
    try {
      await source.copy(part.path);
      // 拷贝过程中源文件可能被录音软件修改，避免把变化内容记到旧哈希名下。
      final copiedDigest = await sha256.bind(part.openRead()).first;
      if (copiedDigest.toString() != digest.toString()) {
        throw const FileSystemException('Source changed while copying. Please retry.');
      }
      if (await target.exists()) return relative;
      await part.rename(target.path);
    } finally {
      if (await part.exists()) await part.delete();
    }
    return relative;
  }

  Future<String> installDemo(List<int> bytes) async {
    final relative = 'media/${sha256.convert(bytes)}.wav';
    final file = File(resolve(relative));
    await file.parent.create(recursive: true);
    if (await file.exists()) {
      final current = await sha256.bind(file.openRead()).first;
      if (current.toString() == sha256.convert(bytes).toString()) return relative;
    }
    final part = File('${file.path}.${newId()}.partial');
    try {
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(file.path);
    } finally {
      if (await part.exists()) await part.delete();
    }
    return relative;
  }

  Future<String> recordingDestination() async {
    final relative = 'recordings/${newId()}.wav';
    await File(resolve(relative)).parent.create(recursive: true);
    return relative;
  }
}
