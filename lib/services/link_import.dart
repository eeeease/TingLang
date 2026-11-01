import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'app_controller.dart';
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
  const LinkInfo({required this.url, required this.title, this.duration, this.site});
  final String url, title;
  final Duration? duration;

  /// yt-dlp's name for the site (`Youtube`, `BiliBili`…).
  final String? site;
}

/// Imports the sound of a video page (YouTube, Bilibili and the other sites
/// yt-dlp knows): only the audio is downloaded, transcribed like a file and
/// turned into a Basic course. yt-dlp (Unlicense) is not shipped: it is
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
    return LinkInfo(
      url: '${json['webpage_url'] ?? uri}',
      title: title.isEmpty ? uri.host : title,
      duration: seconds is num ? Duration(milliseconds: (seconds * 1000).round()) : null,
      site: json['extractor_key'] as String?,
    );
  }

  /// Imports [info]'s audio: downloads it into a temporary folder, hands it to
  /// [transcription] (which copies it into the library) and, once the
  /// transcript is done, makes a Basic course from it.
  Future<ImportJob> import(LinkInfo info) async {
    _cancelled = false;
    final work = await _workFolder();
    try {
      final audio = await _download(info.url, work);
      final job = await transcribeMedia(
        app,
        transcription,
        audio,
        origin: 'link',
        sourceRef: info.url,
        title: info.title,
      );
      // The library has its own copy once copying is over.
      void cleanUp() {
        if (job.status == ImportStatus.copying) return;
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

  /// Stops a download of yt-dlp's audio.
  void cancel() {
    _cancelled = true;
    _running?.kill();
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
