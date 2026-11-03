import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang_api/tinglang_api.dart';

import '../core/course_codec.dart';
import '../core/models.dart';
import 'app_controller.dart';

/// The cloud account, as far as the official library needs it
/// ([CloudController] in the app).
abstract interface class LibraryAccount implements Listenable {
  bool get signedIn;

  /// The last sign-in's failure, if any.
  Object? get error;

  /// Opens the server's sign-in page in the browser.
  Future<void> signIn();
}

/// The official library (Library → Official): text-only courses on
/// api.tinglang.app. Signed in, every course can be added; signed out, the
/// server lists a preview (a few per category). Nothing is requested until
/// the user opens it. A course's cover is saved next to the library
/// (`covers/<id>.jpg`), so its card has it offline too.
class OfficialLibraryService extends ChangeNotifier {
  OfficialLibraryService({
    required this.app,
    required this.api,
    this.account,
    HttpClient Function()? httpClient,
  }) : _httpClient = httpClient ?? HttpClient.new {
    account?.addListener(_accountChanged);
  }

  final AppController app;

  /// A client for the library's server, carrying the account's tokens when
  /// signed in; each request closes its own.
  final TinglangApi Function() api;

  /// Signing in or out asks an opened library again.
  final LibraryAccount? account;
  final HttpClient Function() _httpClient;

  /// Whether [library] was asked for while signed in.
  bool? _loadedSignedIn;

  bool get signedIn => account?.signedIn ?? false;

  /// `app_meta`: JSON `{course id: version}` of the courses added from here,
  /// so a newer version can be offered.
  static const versionsKey = 'official_versions';

  OfficialLibrary? library;
  bool loading = false;
  Object? error;

  /// Courses being added right now.
  final adding = <String>{};

  /// Where [coverFor] files live.
  static String coverPath(String libraryRoot, String courseId) =>
      p.join(libraryRoot, 'covers', '$courseId.jpg');

  /// The saved cover of [courseId], if any (or the user's own picture).
  File? coverFor(String courseId) => app.covers.image(courseId);

  Map<String, String> get _versions {
    try {
      final json = jsonDecode(app.setting(versionsKey, '{}'));
      return json is Map ? {for (final e in json.entries) '${e.key}': '${e.value}'} : {};
    } on FormatException {
      return {};
    }
  }

  bool added(LibraryEntry entry) => app.state.courses.any((c) => c.id == entry.id);

  /// Added from here before and changed on the server since.
  bool updatable(LibraryEntry entry) {
    final version = _versions[entry.id];
    return added(entry) && version != null && version != entry.version;
  }

  /// Reads the list (once per open; [force] asks again). Courses already in
  /// the library get their cover now, so the cards there have it too.
  Future<void> load({bool force = false}) async {
    if (loading || (library != null && !force)) return;
    loading = true;
    error = null;
    _loadedSignedIn = signedIn;
    notifyListeners();
    final server = api();
    try {
      library = await server.getLibrary();
    } on Object catch (e) {
      error = e;
    } finally {
      server.close();
      loading = false;
      notifyListeners();
    }
    // Signed in or out while this was on its way.
    if (_loadedSignedIn != signedIn) return load(force: true);
    for (final entry in library?.courses ?? const <LibraryEntry>[]) {
      if (added(entry) && coverFor(entry.id) == null) unawaited(_saveCover(entry));
    }
  }

  /// Signs in from the library; throws the account's error when it failed.
  Future<void> signIn() async {
    final account = this.account;
    if (account == null) return;
    await account.signIn();
    final failure = account.error;
    if (!account.signedIn && failure != null) throw failure;
  }

  void _accountChanged() {
    // Only a library already opened is asked again.
    if (_loadedSignedIn == null || _loadedSignedIn == signedIn) return;
    unawaited(load(force: true));
  }

  @override
  void dispose() {
    account?.removeListener(_accountChanged);
    super.dispose();
  }

  /// Adds (or updates) [entry] in the user's library; learning progress,
  /// drafts and review cards are kept, as for any re-import.
  Future<Course> add(LibraryEntry entry) async {
    adding.add(entry.id);
    notifyListeners();
    final server = api();
    try {
      final json = await server.getLibraryCourse(entry.id);
      final course = const CourseCodec().fromMap(
        json,
        area: Area.parse(entry.area ?? Area.podcasts.name),
        sourceLabel: entry.sourceLabel,
      );
      if (course.id != entry.id) {
        throw FormatException('The server sent ${course.id}, not ${entry.id}');
      }
      await _saveCover(entry);
      await app.upsertCourse(course);
      await app.setSetting(versionsKey, jsonEncode({..._versions, entry.id: entry.version}));
      return course;
    } finally {
      server.close();
      adding.remove(entry.id);
      notifyListeners();
    }
  }

  /// Downloads [entry]'s cover; only from the library's own server.
  Future<void> _saveCover(LibraryEntry entry) async {
    final url = entry.coverUrl;
    if (url == null || url.scheme != 'https' && !_loopback(url)) return;
    final server = api();
    final sameServer = url.origin == server.server.origin.toString();
    server.close();
    if (!sameServer) return;
    final client = _httpClient();
    try {
      final response = await (await client.getUrl(url)).close();
      if (response.statusCode != 200) return;
      final bytes = await response.fold<BytesBuilder>(BytesBuilder(), (b, chunk) => b..add(chunk));
      // A cover, not a download of anything else: JPEG and under 2 MB.
      final data = bytes.takeBytes();
      if (data.length > 2 * 1024 * 1024 || data.length < 3 || data[0] != 0xFF || data[1] != 0xD8) {
        return;
      }
      if (await app.covers.saveOwn(entry.id, data)) notifyListeners();
    } on Object catch (e) {
      debugPrint('Cover not saved: $e');
    } finally {
      client.close(force: true);
    }
  }

  static bool _loopback(Uri uri) => uri.scheme == 'http' && ServerUrl.isLoopback(uri.host);
}
