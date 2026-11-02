import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../core/captions.dart';

import 'app_controller.dart';
import 'course_covers.dart';
import 'course_generation.dart';
import 'transcription_controller.dart';
import 'update_service.dart' show UpdateEndpoints;

/// Why a link could not be imported. [detail] is yt-dlp's own message.
enum LinkProblem { notALink, live, unsupported, network, tool, noAudio }

final class LinkImportFailure implements Exception {
  const LinkImportFailure(this.problem, [this.detail]);
  final LinkProblem problem;
  final String? detail;
  @override
  String toString() => detail == null ? problem.name : '${problem.name}: $detail';
}

/// The yt-dlp build on offer: GitHub's latest release of yt-dlp/yt-dlp.
@immutable
final class LinkToolOffer {
  const LinkToolOffer({
    required this.version,
    required this.binary,
    required this.bytes,
    required this.checksums,
  });
  final String version;
  final Uri binary, checksums;
  final int bytes;
}

/// What a page holds, as yt-dlp reads it.
@immutable
final class LinkInfo {
  const LinkInfo({
    required this.url,
    required this.title,
    this.duration,
    this.site,
    this.thumbnail,
    this.captions,
  });
  final String url, title;
  final Duration? duration;

  /// yt-dlp's name for the site (`Youtube`, `BiliBili`…).
  final String? site;

  /// The page's picture, which becomes the course cover.
  final Uri? thumbnail;

  /// English captions the page offers; read instead of transcribing.
  final CaptionTrack? captions;
}

/// Where a page's video plays from right now (such addresses expire) and
/// the headers its site wants with each request.
@immutable
final class LinkStream {
  const LinkStream({required this.url, this.headers = const {}, this.hasVideo = true});
  final String url;
  final Map<String, String> headers;
  final bool hasVideo;
}

/// Imports the sound of a video page (YouTube, Bilibili and the other sites
/// yt-dlp knows): only the audio is downloaded, transcribed like a file and
/// turned into a Basic course. The audio is deleted afterwards: the course
/// plays the page itself, YouTube in its own player and other sites from
/// the stream [stream] finds. yt-dlp (Unlicense) is not shipped: it is
/// downloaded from its GitHub releases when the user agrees, checked
/// against the release's SHA2-256SUMS and kept in `<data>/tools`. What is
/// imported is the user's own choice and responsibility.
class LinkImportService extends ChangeNotifier {
  LinkImportService({
    required this.app,
    required this.transcription,
    required this.toolsFolder,
    this.generation,
    HttpClient Function()? httpClient,
    Future<Directory> Function()? workFolder,
    Uri? releaseApi,
    bool Function(Uri uri)? allowDownload,
  }) : releaseApi = releaseApi ?? Uri.parse(latestRelease),
       _allowDownload = allowDownload ?? UpdateEndpoints.isGitHubDownload,
       _httpClient = httpClient ?? HttpClient.new,
       _workFolder = workFolder ?? (() => Directory.systemTemp.createTemp('tinglang-link-'));

  final AppController app;
  final TranscriptionController transcription;

  /// `<data>/tools`; yt-dlp lives there once downloaded.
  final Directory toolsFolder;

  /// Makes a Basic course once the transcript is done; null leaves it.
  final CourseGenerationService? generation;
  final HttpClient Function() _httpClient;
  final Future<Directory> Function() _workFolder;

  /// GitHub's latest-release answer for yt-dlp (a loopback server in tests).
  final Uri releaseApi;
  final bool Function(Uri uri) _allowDownload;

  static const latestRelease = 'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest';
  static const binaryName = 'yt-dlp_macos';

  /// Audio only, in a container AVFoundation reads without converting:
  /// AAC in m4a first, then an mp4 with sound.
  static const audioFormat = 'bestaudio[ext=m4a]/bestaudio[acodec^=mp4a]/best[ext=mp4]';

  File get tool => File(p.join(toolsFolder.path, 'yt-dlp'));
  bool get installed => tool.existsSync();

  /// Download progress of yt-dlp itself or of a page's audio, 0–1.
  double? progress;
  Process? _running;
  bool _cancelled = false;

  /// Asks GitHub which yt-dlp is current, for the consent question.
  Future<LinkToolOffer> offer() async {
    final client = _httpClient();
    try {
      final request = await client.getUrl(releaseApi);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'Tinglang (macos)');
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw LinkImportFailure(LinkProblem.network, 'HTTP ${response.statusCode}');
      }
      final json = jsonDecode(text) as Map<String, Object?>;
      Map<String, Object?>? asset(String name) => (json['assets'] as List? ?? const [])
          .whereType<Map<String, Object?>>()
          .where((a) => a['name'] == name)
          .firstOrNull;
      final binary = asset(binaryName), sums = asset('SHA2-256SUMS');
      final binaryUrl = Uri.tryParse('${binary?['browser_download_url']}');
      final sumsUrl = Uri.tryParse('${sums?['browser_download_url']}');
      if (binary == null || binaryUrl == null || sumsUrl == null) {
        throw const LinkImportFailure(LinkProblem.tool, 'no macOS build in the latest release');
      }
      for (final uri in [binaryUrl, sumsUrl]) {
        if (!_allowDownload(uri)) {
          throw LinkImportFailure(LinkProblem.tool, 'unexpected download address ${uri.host}');
        }
      }
      return LinkToolOffer(
        version: '${json['tag_name']}',
        binary: binaryUrl,
        bytes: (binary['size'] as num?)?.toInt() ?? 0,
        checksums: sumsUrl,
      );
    } on SocketException catch (e) {
      throw LinkImportFailure(LinkProblem.network, e.message);
    } on FormatException catch (e) {
      throw LinkImportFailure(LinkProblem.network, e.message);
    } finally {
      client.close(force: true);
    }
  }

  /// Downloads [offer] (the user agreed to its size), checks it against the
  /// release's checksums and makes it runnable.
  Future<void> install(LinkToolOffer offer) async {
    final client = _httpClient();
    await toolsFolder.create(recursive: true);
    final part = File('${tool.path}.part');
    try {
      final sums = await _text(client, offer.checksums);
      final expected = RegExp(
        r'^([0-9a-f]{64})\s+\*?' + RegExp.escape(binaryName) + r'\s*$',
        multiLine: true,
      ).firstMatch(sums)?.group(1);
      if (expected == null) {
        throw const LinkImportFailure(LinkProblem.tool, 'no checksum for the macOS build');
      }
      final request = await client.getUrl(offer.binary);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw LinkImportFailure(LinkProblem.network, 'HTTP ${response.statusCode}');
      }
      final total = response.contentLength > 0 ? response.contentLength : offer.bytes;
      final sink = part.openWrite();
      final digest = _DigestSink();
      final hash = sha256.startChunkedConversion(digest);
      var received = 0;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          hash.add(chunk);
          received += chunk.length;
          if (total > 0) _setProgress(received / total);
        }
      } finally {
        await sink.close();
        hash.close();
      }
      if ('${digest.value}' != expected) {
        throw const LinkImportFailure(LinkProblem.tool, 'the download does not match its checksum');
      }
      await Process.run('/bin/chmod', ['755', part.path]);
      await part.rename(tool.path);
    } on SocketException catch (e) {
      throw LinkImportFailure(LinkProblem.network, e.message);
    } finally {
      client.close(force: true);
      if (await part.exists()) await part.delete();
      _setProgress(null);
    }
  }

  /// Reads the page at [url]: title and length; refuses live streams.
  Future<LinkInfo> inspect(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      throw const LinkImportFailure(LinkProblem.notALink);
    }
    final result = await Process.run(
      tool.path,
      ['-J', '--no-playlist', '--no-warnings', '$uri'],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) throw _failure('${result.stderr}');
    final Map<String, Object?> json;
    try {
      json = jsonDecode('${result.stdout}') as Map<String, Object?>;
    } on FormatException {
      throw const LinkImportFailure(LinkProblem.unsupported);
    }
    if (json['is_live'] == true) throw const LinkImportFailure(LinkProblem.live);
    final seconds = json['duration'];
    final title = '${json['title'] ?? ''}'.trim();
    final thumbnail = Uri.tryParse('${json['thumbnail'] ?? ''}');
    return LinkInfo(
      url: '${json['webpage_url'] ?? uri}',
      title: title.isEmpty ? uri.host : title,
      duration: seconds is num ? Duration(milliseconds: (seconds * 1000).round()) : null,
      site: json['extractor_key'] as String?,
      thumbnail: thumbnail != null && thumbnail.isScheme('https') ? thumbnail : null,
      captions: englishCaptions(json),
    );
  }

  /// Imports [info]: its English captions when the page has them (nothing
  /// to download or transcribe), otherwise its audio, downloaded into a
  /// temporary folder and handed to [transcription] (which reads it there,
  /// keeping no copy). Once the transcript is done the folder goes and a
  /// Basic course is made. The page's picture becomes the cover.
  Future<ImportJob> import(LinkInfo info) async {
    _cancelled = false;
    final work = await _workFolder();
    try {
      final lines = info.captions == null ? null : await _captions(info, work);
      final job = lines != null
          ? await transcription.importLines(
              lines,
              language: 'en',
              origin: 'link',
              sourceRef: info.url,
              title: info.title,
            )
          : await transcribeMedia(
              app,
              transcription,
              await _download(info.url, work),
              origin: 'link',
              sourceRef: info.url,
              title: info.title,
              keepMedia: false,
            );
      final thumbnail = info.thumbnail;
      if (thumbnail != null) {
        unawaited(_saveCover(CourseGenerationService.courseIdFor(job.sessionId), thumbnail));
      }
      void cleanUp() {
        if (job.status == ImportStatus.copying || job.status == ImportStatus.transcribing) return;
        job.removeListener(cleanUp);
        unawaited(work.delete(recursive: true).catchError((Object _) => work));
      }

      job.addListener(cleanUp);
      cleanUp();
      final make = generation;
      if (make != null) {
        void course() {
          if (job.status == ImportStatus.transcribing || job.status == ImportStatus.copying) return;
          job.removeListener(course);
          if (job.status == ImportStatus.done) make.start(job.sessionId);
        }

        job.addListener(course);
        course();
      }
      return job;
    } on Object {
      unawaited(work.delete(recursive: true).catchError((Object _) => work));
      rethrow;
    }
  }

  /// Saves the page's picture as the cover of [courseId]; a cover is not worth
  /// failing an import for.
  Future<void> _saveCover(String courseId, Uri url) async {
    final client = _httpClient();
    try {
      final response = await (await client.getUrl(url)).close();
      if (response.statusCode != 200) return;
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response) {
        bytes.add(chunk);
        if (bytes.length > CourseCovers.maxBytes) return;
      }
      await app.covers.saveOwn(courseId, bytes.takeBytes());
    } on Object catch (e) {
      debugPrint('Cover not saved: $e');
    } finally {
      client.close(force: true);
    }
  }

  /// Playback formats: one file with picture and sound (mp4 first), else
  /// sound alone; never two streams that would need merging.
  static const streamFormat =
      'best[ext=mp4][vcodec!=none][acodec!=none]/best[vcodec!=none][acodec!=none]/'
      'bestaudio[ext=m4a]/bestaudio';

  final _streams = <String, ({LinkStream stream, DateTime at})>{};

  /// Where [page]'s video plays from: asked of yt-dlp, kept for half an hour
  /// (sites' stream addresses expire after a few hours).
  Future<LinkStream> stream(Uri page) async {
    final cached = _streams['$page'];
    if (cached != null && DateTime.now().difference(cached.at) < const Duration(minutes: 30)) {
      return cached.stream;
    }
    if (!installed) throw const LinkImportFailure(LinkProblem.tool, 'yt-dlp is not installed');
    final result = await Process.run(
      tool.path,
      ['-J', '-f', streamFormat, '--no-playlist', '--no-warnings', '$page'],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) throw _failure('${result.stderr}');
    final Map<String, Object?> json;
    try {
      json = jsonDecode('${result.stdout}') as Map<String, Object?>;
    } on FormatException {
      throw const LinkImportFailure(LinkProblem.unsupported);
    }
    final url = Uri.tryParse('${json['url'] ?? ''}');
    if (url == null || !(url.isScheme('https') || url.isScheme('http'))) {
      throw const LinkImportFailure(LinkProblem.noAudio);
    }
    final headers = json['http_headers'];
    final stream = LinkStream(
      url: '$url',
      headers: headers is Map
          ? {for (final e in headers.entries) '${e.key}': '${e.value}'}
          : const {},
      hasVideo: json['vcodec'] != null && json['vcodec'] != 'none',
    );
    _streams['$page'] = (stream: stream, at: DateTime.now());
    return stream;
  }

  /// Stops a download of yt-dlp's audio.
  void cancel() {
    _cancelled = true;
    _running?.kill();
  }

  /// Fewest words a caption track needs to be used instead of the audio.
  static const minCaptionWords = 20;

  /// [info]'s captions as lines, or null when they cannot be read (the
  /// audio is transcribed instead).
  Future<List<({int startMs, int endMs, String text, String? wordsJson})>?> _captions(
    LinkInfo info,
    Directory work,
  ) async {
    final track = info.captions!;
    final result = await Process.run(
      tool.path,
      [
        '--skip-download',
        if (track.automatic) '--write-auto-subs' else '--write-subs',
        '--sub-langs',
        track.language,
        '--sub-format',
        'json3',
        '--no-playlist',
        '--no-warnings',
        '-o',
        p.join(work.path, 'captions'),
        info.url,
      ],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (_cancelled) throw const LinkImportFailure(LinkProblem.network, 'cancelled');
    final file = File(p.join(work.path, 'captions.${track.language}.json3'));
    if (result.exitCode != 0 || !await file.exists()) return null;
    final lines = captionLines(await file.readAsString());
    final words = lines.fold(0, (n, l) => n + l.text.split(' ').length);
    if (words < minCaptionWords) return null;
    return [
      for (final l in lines)
        (startMs: l.startMs, endMs: l.endMs, text: l.text, wordsJson: l.wordsJson),
    ];
  }

  Future<File> _download(String url, Directory work) async {
    final process = _running = await Process.start(tool.path, [
      '-f',
      audioFormat,
      '--no-playlist',
      '--no-warnings',
      '--newline',
      '--progress-template',
      'download:%(progress._percent_str)s',
      '--print',
      'after_move:filepath',
      '-o',
      p.join(work.path, 'audio.%(ext)s'),
      url,
    ]);
    String? path;
    final errors = StringBuffer();
    final out = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((
      line,
    ) {
      final percent = RegExp(r'([\d.]+)%').firstMatch(line);
      if (percent != null && !line.startsWith('/')) {
        _setProgress((double.tryParse(percent.group(1)!) ?? 0) / 100);
      } else if (line.startsWith('/')) {
        path = line.trim();
      }
    });
    final err = process.stderr.transform(utf8.decoder).listen(errors.write);
    final code = await process.exitCode;
    await out.cancel();
    await err.cancel();
    _running = null;
    _setProgress(null);
    if (_cancelled) throw const LinkImportFailure(LinkProblem.network, 'cancelled');
    if (code != 0) throw _failure('$errors');
    final file = path == null ? null : File(path!);
    if (file == null || !await file.exists()) throw const LinkImportFailure(LinkProblem.noAudio);
    return file;
  }

  static LinkImportFailure _failure(String stderr) {
    final message = stderr
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('ERROR:'))
        .map((l) => l.substring(6).trim())
        .lastOrNull;
    if (message == null) return LinkImportFailure(LinkProblem.tool, stderr.trim());
    if (message.contains('Unsupported URL')) {
      return LinkImportFailure(LinkProblem.unsupported, message);
    }
    if (message.contains('Requested format is not available')) {
      return LinkImportFailure(LinkProblem.noAudio, message);
    }
    return LinkImportFailure(LinkProblem.tool, message);
  }

  Future<String> _text(HttpClient client, Uri uri) async {
    final request = await client.getUrl(uri);
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw LinkImportFailure(LinkProblem.network, 'HTTP ${response.statusCode}');
    }
    return text;
  }

  void _setProgress(double? value) {
    progress = value;
    notifyListeners();
  }
}

final class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
