import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;

import 'app_controller.dart';

/// What kind of picture [bytes] hold, by their first bytes; null for
/// anything that is not a JPEG, PNG or WebP image.
String? coverImageType(List<int> bytes) {
  bool starts(List<int> magic, [int at = 0]) =>
      bytes.length >= at + magic.length &&
      [for (var i = 0; i < magic.length; i++) bytes[at + i] == magic[i]].every((same) => same);
  if (starts(const [0xFF, 0xD8, 0xFF])) return 'jpg';
  if (starts(const [0x89, 0x50, 0x4E, 0x47])) return 'png';
  if (starts(const [0x52, 0x49, 0x46, 0x46]) && starts(const [0x57, 0x45, 0x42, 0x50], 8)) {
    return 'webp';
  }
  return null;
}

/// A course's cover, next to the library in `covers/`: the picture the user
/// chose (`covers/mine/<id>.<ext>`), else the one that came with the course
/// (`covers/<id>.<ext>`: the official library's or a video page's
/// thumbnail), else a line pattern drawn from the course's seed.
class CourseCovers extends ChangeNotifier {
  CourseCovers(this.app);
  final AppController app;

  /// `app_meta`: JSON `{course id: seed}` of patterns the user reshuffled.
  static const seedsKey = 'cover_seeds';
  static const extensions = ['jpg', 'png', 'webp'];

  /// Pictures above this are refused (a cover, not a photo library).
  static const maxBytes = 10 * 1024 * 1024;

  String get _folder => p.join(app.store.root.path, 'covers');

  File? _find(String folder, String courseId) {
    for (final ext in extensions) {
      final file = File(p.join(folder, '$courseId.$ext'));
      if (file.existsSync()) return file;
    }
    return null;
  }

  /// The user's own picture for [courseId], if any.
  File? custom(String courseId) => _find(p.join(_folder, 'mine'), courseId);

  /// The picture to show for [courseId]; null draws the pattern.
  File? image(String courseId) => custom(courseId) ?? _find(_folder, courseId);

  Map<String, int> get _seeds {
    try {
      final json = jsonDecode(app.setting(seedsKey, '{}'));
      return json is Map
          ? {
              for (final e in json.entries)
                if (e.value is int) '${e.key}': e.value as int,
            }
          : {};
    } on FormatException {
      return {};
    }
  }

  /// The pattern's seed: a reshuffled one, else one from the id (FNV-1a), so
  /// a course keeps its pattern on every Mac.
  int seed(String courseId) {
    final saved = _seeds[courseId];
    if (saved != null) return saved;
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(courseId)) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Draws [courseId] a new pattern.
  Future<void> shuffle(String courseId, [math.Random? random]) => app.setSetting(
    seedsKey,
    jsonEncode({..._seeds, courseId: (random ?? math.Random()).nextInt(1 << 32)}),
  );

  /// Makes the picture at [source] the cover of [courseId] (copied).
  Future<void> choose(String courseId, File source) async {
    if (await source.length() > maxBytes) throw const FormatException('The picture is too large');
    final bytes = await source.readAsBytes();
    final type = coverImageType(bytes);
    if (type == null) throw const FormatException('Not a JPEG, PNG or WebP picture');
    await _write(p.join(_folder, 'mine'), courseId, bytes, type);
  }

  /// Back to the course's own cover or pattern.
  Future<void> clearCustom(String courseId) async {
    final file = custom(courseId);
    if (file == null) return;
    await file.delete();
    _evict(file);
    notifyListeners();
  }

  /// Saves the cover that came with [courseId] (a JPEG, PNG or WebP); other
  /// bytes are ignored.
  Future<bool> saveOwn(String courseId, List<int> bytes) async {
    final type = bytes.length > maxBytes ? null : coverImageType(bytes);
    if (type == null) return false;
    await _write(_folder, courseId, bytes, type);
    return true;
  }

  Future<void> _write(String folder, String courseId, List<int> bytes, String type) async {
    await Directory(folder).create(recursive: true);
    for (final ext in extensions) {
      final old = File(p.join(folder, '$courseId.$ext'));
      if (old.existsSync()) {
        await old.delete();
        _evict(old);
      }
    }
    final file = File(p.join(folder, '$courseId.$type'));
    await file.writeAsBytes(bytes, flush: true);
    _evict(file);
    notifyListeners();
  }

  /// Image.file caches by path; a replaced file must be read again.
  /// (There is no image cache without a Flutter binding: unit tests, tools.)
  static void _evict(File file) =>
      unawaited(FileImage(file).evict().catchError((Object _) => false));
}
