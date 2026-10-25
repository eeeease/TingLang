import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/course_codec.dart';
import '../core/json_helpers.dart';
import '../core/library_store.dart';
import '../core/models.dart';
import '../core/review.dart';
import '../l10n/app_localizations.dart';

class AppController extends ChangeNotifier {
  AppController(this.store, this.state);
  final LibraryStore store;
  LibraryState state;
  Future<void> _tail = Future.value();
  String? persistenceError;
  PracticeAttempt? pendingAttempt;

  /// 所有修改按提交顺序执行；保存失败时不发布未持久化的 UI 状态。
  Future<void> change(void Function(LibraryState) edit) {
    final work = _tail.then((_) async {
      final next = state.clone();
      edit(next);
      await store.save(next);
      state = next;
      persistenceError = null;
      notifyListeners();
    });
    _tail = work.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        persistenceError = error.toString();
        notifyListeners();
      },
    );
    return work;
  }

  Future<void> flush() => _tail;

  // Settings. Interface language is independent of the learning language.
  static const uiLocaleKey = 'ui_locale';
  static const themeKey = 'theme';
  static const learningLanguageKey = 'learning_language';
  static const nativeLanguageKey = 'native_language';

  /// The first-start guide: `pending` in a library made by a version that
  /// has the guide, until the guide closes (`done`). Libraries from before it
  /// have no value and never open it by themselves (Settings → General can).
  static const onboardingKey = 'onboarding';
  static const onboardingPending = 'pending';
  static const onboardingDone = 'done';
  String setting(String key, String fallback) => state.settings[key] ?? fallback;
  Future<void> setSetting(String key, String value) => change((next) {
    next.settings[key] = value;
  });

  /// Several settings in one change (one transaction).
  Future<void> setSettings(Map<String, String> values) => change((next) {
    next.settings.addAll(values);
  });

  Future<void> installDemo() async {
    final data = await rootBundle.load('assets/demo/consistency.wav');
    final media = await store.installDemo(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final course = const CourseCodec()
        .decode(await rootBundle.loadString('assets/demo/course.json'), area: Area.nba)
        .copyWith(mediaPath: media);
    await upsertCourse(course);
  }

  static const learnerProfileKey = 'learner_profile';

  /// Imports or updates many courses in one save; learner records (done
  /// steps, drafts, attempts, review cards) are keyed separately and kept.
  Future<void> upsertCourses(List<Course> courses, {String? learnerProfile}) => change((next) {
    for (final course in courses) {
      final index = next.courses.indexWhere((c) => c.id == course.id);
      if (index < 0) {
        next.courses.add(course);
      } else {
        next.courses[index] = course.copyWith(mediaPath: next.courses[index].mediaPath);
        if (course.mediaPath != null) next.courses[index] = course;
      }
    }
    if (learnerProfile != null) next.settings[learnerProfileKey] = learnerProfile;
  });

  Future<void> upsertCourse(Course course) => change((next) {
    final index = next.courses.indexWhere((c) => c.id == course.id);
    if (index < 0) {
      next.courses.add(course);
    } else {
      // 重导入内容不动学习状态；缺失媒体时保留已关联文件。
      next.courses[index] = course.copyWith(mediaPath: next.courses[index].mediaPath);
      if (course.mediaPath != null) next.courses[index] = course;
    }
  });

  Future<void> attachMedia(Course course, File file) async {
    final relative = await store.importMedia(file);
    await change((next) {
      final index = next.courses.indexWhere((c) => c.id == course.id);
      if (index < 0) throw StateError('Course no longer exists.');
      next.courses[index] = next.courses[index].copyWith(mediaPath: relative);
    });
  }

  Future<void> visit(Course course, CourseClip clip) => change((next) {
    next.lastCourseId = course.id;
    next.lastClipId = clip.id;
  });

  Set<String> done(Course course, CourseClip clip) =>
      state.completed[entityKey(course.id, clip.id)] ?? {};

  Future<void> setDone(Course course, CourseClip clip, String step, bool value) => change((next) {
    final entry = next.completed.putIfAbsent(entityKey(course.id, clip.id), () => {});
    if (value) {
      entry.add(step);
    } else {
      entry.remove(step);
    }
  });

  String draftKey(String? course, String? clip, String kind) =>
      entityKey(entityKey(course ?? 'personal', clip ?? 'free'), kind);
  String draft(String? course, String? clip, String kind) =>
      state.drafts[draftKey(course, clip, kind)] ?? '';
  Future<void> saveDraft(String? course, String? clip, String kind, String text) => change((next) {
    next.drafts[draftKey(course, clip, kind)] = text;
  });

  Future<void> saveAttempt(PracticeAttempt attempt) async {
    pendingAttempt = attempt;
    notifyListeners();
    await change((next) {
      if (!next.attempts.any((a) => a.id == attempt.id)) next.attempts.add(attempt);
    });
    pendingAttempt = null;
    notifyListeners();
  }

  Future<void> retryPending() async {
    final attempt = pendingAttempt;
    if (attempt != null) await saveAttempt(attempt);
  }

  String cardId(Course course, CourseClip clip, String text) =>
      entityKey(entityKey(course.id, clip.id), text);
  bool isSaved(Course course, CourseClip clip, String text) =>
      state.reviews.any((r) => r.id == cardId(course, clip, text));
  Future<void> saveExpression(Course course, CourseClip clip, String text, String meaning) =>
      change((next) {
        final id = cardId(course, clip, text);
        if (next.reviews.any((r) => r.id == id)) return;
        next.reviews.add(
          ReviewCard(
            id: id,
            courseId: course.id,
            clipId: clip.id,
            text: text,
            meaning: meaning,
            dueAt: DateTime.now().toUtc(),
          ),
        );
      });
  Future<void> rateCard(ReviewCard card, Recall recall) => change((next) {
    final index = next.reviews.indexWhere((r) => r.id == card.id);
    if (index >= 0) next.reviews[index] = next.reviews[index].rate(recall, DateTime.now());
  });
  List<ReviewCard> get due =>
      state.reviews.where((r) => !r.dueAt.isAfter(DateTime.now().toUtc())).toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

  String exportMarkdown(AppLocalizations l) {
    final out = StringBuffer('${l.exportHeading}\n\n');
    out.writeln('${l.exportedAt(DateTime.now().toIso8601String())}\n');
    out.writeln('${l.exportTextOnly}\n');
    for (final attempt in state.attempts.reversed) {
      out.writeln('## ${attempt.createdAt.toLocal().toIso8601String()} · ${attempt.kind}\n');
      if (attempt.courseId != null) {
        out.writeln('Course: `${attempt.courseId}` · Clip: `${attempt.clipId}`\n');
      }
      out.writeln(attempt.note.isEmpty ? l.exportAudioOnly : attempt.note);
      out.writeln(
        '\n${attempt.recordingPath == null ? l.exportRecordingNone : l.exportRecordingSaved}\n',
      );
    }
    out.writeln('${l.exportExpressions}\n');
    for (final card in state.reviews) {
      out.writeln(
        '- **${card.text.replaceAll('\n', ' ')}** — ${card.meaning.replaceAll('\n', ' ')}',
      );
    }
    return out.toString();
  }

  String exportState() => const JsonEncoder.withIndent('  ').convert(state.toJson());
}
