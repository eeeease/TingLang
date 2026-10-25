import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

import 'model_store.dart';

/// The user agreed to download [packId] after being shown [bytes]. Create it
/// only in the confirmation UI, right after the user accepts.
final class DownloadConsent {
  const DownloadConsent({required this.packId, required this.bytes, required this.agreedAt});

  /// Consent for [pack] as shown: its id and [ModelPack.downloadBytes].
  DownloadConsent.forPack(ModelPack pack, {DateTime? at})
    : this(packId: pack.id, bytes: pack.downloadBytes, agreedAt: at ?? DateTime.now());

  final String packId;
  final int bytes;
  final DateTime agreedAt;
}

/// Bytes transferred so far for one pack install.
final class DownloadProgress {
  const DownloadProgress({required this.packId, required this.received, required this.total});
  final String packId;
  final int received;

  /// [ModelPack.downloadBytes].
  final int total;

  double get fraction => total == 0 ? 1 : received / total;
}

/// Why an install failed. Messages name catalog files and hosts only, never
/// local paths or signed URLs.
sealed class ModelDownloadException implements Exception {
  const ModelDownloadException(this.file);

  /// Catalog file (or archive) name involved, if any.
  final String? file;
}

/// The bytes did not match the catalog. Partial data has been deleted.
final class ChecksumMismatch extends ModelDownloadException {
  const ChecksumMismatch(String super.file, this.expected, this.actual);
  final String expected, actual;

  @override
  String toString() => 'ChecksumMismatch: $file (expected $expected, got $actual)';
}

/// [DownloadJob.cancel] was called. Partial files are kept for resume.
final class DownloadCancelled extends ModelDownloadException {
  const DownloadCancelled() : super(null);

  @override
  String toString() => 'DownloadCancelled';
}

final class DownloadHttpError extends ModelDownloadException {
  const DownloadHttpError(this.status, [super.file]);
  final int status;

  @override
  String toString() => 'DownloadHttpError: HTTP $status${file == null ? '' : ' for $file'}';
}

/// Connection failed, timed out or closed early. Partial files are kept.
final class DownloadNetworkError extends ModelDownloadException {
  const DownloadNetworkError(this.message, [super.file]);
  final String message;

  @override
  String toString() => 'DownloadNetworkError: $message${file == null ? '' : ' ($file)'}';
}

/// A URL or redirect that is not https (plain http only to loopback).
final class DownloadUrlRefused extends ModelDownloadException {
  const DownloadUrlRefused(this.scheme, this.host, [super.file]);
  final String scheme, host;

  @override
  String toString() => 'DownloadUrlRefused: $scheme://$host${file == null ? '' : ' ($file)'}';
}

/// Writing to disk failed (e.g. disk full).
final class DownloadDiskError extends ModelDownloadException {
  const DownloadDiskError(this.message, [super.file]);
  final String message;

  @override
  String toString() => 'DownloadDiskError: $message${file == null ? '' : ' ($file)'}';
}

/// `tar` could not extract the archive's files.
final class ModelArchiveError extends ModelDownloadException {
  const ModelArchiveError(this.message, [super.file]);
  final String message;

  @override
  String toString() => 'ModelArchiveError: $message${file == null ? '' : ' ($file)'}';
}

/// One running pack install. Completes [done] with null, or with a
/// [ModelDownloadException].
final class DownloadJob {
  DownloadJob._(this.pack, this._interval)
    : _latest = DownloadProgress(packId: pack.id, received: 0, total: pack.downloadBytes) {
    _done.future.ignore();
  }

  final ModelPack pack;
  final Duration _interval;
  final _progress = StreamController<DownloadProgress>.broadcast(sync: true);
  final _done = Completer<void>();
  final _clock = Stopwatch();
  DownloadProgress _latest;
  bool _cancelled = false;
  HttpClient? _client;
  Process? _process;

  /// At most one event per throttle interval, never decreasing.
  Stream<DownloadProgress> get progress => _progress.stream;
  DownloadProgress get latest => _latest;
  Future<void> get done => _done.future;
  bool get isCancelled => _cancelled;

  /// Aborts the transfer and keeps `.part` files for a later resume.
  void cancel() {
    if (_cancelled || _done.isCompleted) return;
    _cancelled = true;
    _client?.close(force: true);
    _process?.kill();
  }

  void _check() {
    if (_cancelled) throw const DownloadCancelled();
  }

  void _emit(int received, {bool force = false}) {
    if (received <= _latest.received) return;
    if (!force && _clock.isRunning && _clock.elapsed < _interval) return;
    _clock
      ..reset()
      ..start();
    _latest = DownloadProgress(packId: pack.id, received: received, total: _latest.total);
    _progress.add(_latest);
  }

  void _finish([Object? error]) {
    if (error == null) {
      _emit(_latest.total, force: true);
      _done.complete();
    } else {
      _done.completeError(error);
    }
    _progress.close();
  }
}

/// Resumable, checksum-verified model pack installs into a [ModelStore].
///
/// Nothing touches the network until [start] is called with the user's
/// [DownloadConsent]; the [HttpClient] is created per install.
final class ModelDownloader {
  ModelDownloader({
    required this.store,
    required this.appVersion,
    HttpClient Function()? httpClient,
    this.connectionTimeout = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 60),
    this.progressInterval = const Duration(milliseconds: 100),
    String? tar,
  }) : _httpClient = httpClient ?? HttpClient.new,
       _tar = tar ?? (Platform.isWindows ? 'tar' : '/usr/bin/tar');

  final ModelStore store;

  /// Sent as `User-Agent: Tinglang/<appVersion>`.
  final String appVersion;
  final Duration connectionTimeout, idleTimeout, progressInterval;
  final HttpClient Function() _httpClient;
  final String _tar;
  final _jobs = <String, DownloadJob>{};

  static const archiveName = '.archive';
  static const stagingName = '.staging';
  static const _maxRedirects = 5;

  /// The running install of [packId], if any.
  DownloadJob? jobFor(String packId) => _jobs[packId];

  /// Starts (or returns the running) install of [pack].
  ///
  /// Throws [StateError] without any network access unless [consent] is for
  /// this pack and its [ModelPack.downloadBytes]; [ArgumentError] for unsafe
  /// file names and [DownloadUrlRefused] for non-https URLs.
  DownloadJob start(ModelPack pack, {required DownloadConsent? consent}) {
    if (consent == null) throw StateError('Downloading ${pack.id} needs the user\'s consent');
    if (consent.packId != pack.id || consent.bytes != pack.downloadBytes) {
      throw StateError('Consent was given for ${consent.packId} (${consent.bytes} bytes)');
    }
    final running = _jobs[pack.id];
    if (running != null) return running;
    _validate(pack);
    final job = _jobs[pack.id] = DownloadJob._(pack, progressInterval);
    unawaited(_run(job));
    return job;
  }

  /// [start] and wait; [onProgress] gets the job's progress events.
  Future<void> install(
    ModelPack pack, {
    required DownloadConsent? consent,
    void Function(DownloadProgress)? onProgress,
  }) {
    final job = start(pack, consent: consent);
    if (onProgress != null) job.progress.listen(onProgress);
    return job.done;
  }

  /// Cancels a running install of [packId], then deletes its folder.
  Future<void> delete(String packId) async {
    final job = _jobs[packId];
    if (job != null) {
      job.cancel();
      await job.done.then<void>((_) {}, onError: (_) {});
    }
    await store.delete(packId);
  }

  void _validate(ModelPack pack) {
    ModelStore.checkName(pack.id);
    if (pack.files.isEmpty) throw StateError('${pack.id} has no files in the catalog');
    final names = <String>{};
    for (final file in pack.files) {
      if (!names.add(ModelStore.checkName(file.name))) {
        throw ArgumentError.value(file.name, 'name', 'listed twice');
      }
    }
    final archive = pack.archive;
    if (archive != null) {
      if (archive.folder.isNotEmpty) ModelStore.checkName(archive.folder);
      _checkUrl(Uri.tryParse(archive.url), _archiveLabel(archive));
    } else {
      for (final file in pack.files) {
        _checkUrl(Uri.tryParse(file.url), file.name);
      }
    }
  }

  static void _checkUrl(Uri? uri, String file) {
    if (uri == null) throw DownloadUrlRefused('', '', file);
    final ok =
        uri.userInfo.isEmpty &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'https' ||
            uri.scheme == 'http' && const {'127.0.0.1', 'localhost', '::1'}.contains(uri.host));
    if (!ok) throw DownloadUrlRefused(uri.scheme, uri.host, file);
  }

  static String _archiveLabel(ModelArchive archive) {
    final segments = Uri.tryParse(archive.url)?.pathSegments ?? const [];
    return segments.isEmpty || segments.last.isEmpty ? 'archive' : segments.last;
  }

  Future<void> _run(DownloadJob job) async {
    final pack = job.pack;
    try {
      if (store.refresh().contains(pack.id)) return job._finish();
      final dir = store.directoryOf(pack.id);
      await Directory(dir).create(recursive: true);
      final stale = File(p.join(dir, ModelStore.receiptName));
      if (await stale.exists()) await stale.delete();
      final archive = pack.archive;
      if (archive == null) {
        var base = 0;
        for (final file in pack.files) {
          await _fetch(job, _Target.file(file, dir), base);
          base += file.bytes;
          job._emit(base, force: true);
        }
      } else {
        final missing = [
          for (final file in pack.files)
            if (!await _present(p.join(dir, file.name), file.bytes, file.sha256)) file,
        ];
        if (missing.isNotEmpty) {
          final target = _Target.archive(archive, _archiveLabel(archive), dir);
          await _fetch(job, target, 0);
          job._check();
          await _extract(job, dir, archive.folder, missing);
          await File(target.path).delete();
        }
      }
      job._check();
      await store.writeReceipt(pack);
      job._finish();
    } catch (error) {
      job._finish(job._cancelled ? const DownloadCancelled() : _typed(error));
    } finally {
      job._client?.close(force: true);
      job._client = null;
      _jobs.remove(pack.id);
    }
  }

  static Object _typed(Object error) => switch (error) {
    ModelDownloadException() || StateError() || ArgumentError() => error,
    TimeoutException() => const DownloadNetworkError('timed out'),
    SocketException(:final osError, :final message) => DownloadNetworkError(
      osError?.message ?? message,
    ),
    TlsException(:final message) => DownloadNetworkError('TLS: $message'),
    HttpException(:final message) => DownloadNetworkError(message),
    FileSystemException(:final osError, :final message) => DownloadDiskError(
      osError?.message ?? message,
    ),
    _ => DownloadNetworkError(error.runtimeType.toString()),
  };

  /// Whether a finished file is already in place (hashed when no receipt
  /// vouches for it).
  static Future<bool> _present(String path, int bytes, String sha256) async {
    final stat = await FileStat.stat(path);
    if (stat.type != FileSystemEntityType.file || stat.size != bytes) return false;
    return await ModelStore.hashFile(path) == sha256.toLowerCase();
  }

  /// Downloads one [target] to `<path>.part`, verifies it and renames it.
  Future<void> _fetch(DownloadJob job, _Target target, int base) async {
    final dest = File(target.path);
    final part = File('${target.path}${ModelStore.partSuffix}');
    if (await dest.exists()) {
      if (await _present(dest.path, target.bytes, target.sha256)) return;
      await dest.delete();
    }
    var offset = await part.exists() ? await part.length() : 0;
    if (offset > target.bytes) {
      await part.delete();
      offset = 0;
    }
    if (offset == target.bytes && offset > 0) {
      // Complete but never verified (e.g. cancelled while hashing).
      if (await _present(part.path, target.bytes, target.sha256)) {
        await part.rename(dest.path);
        return;
      }
      await part.delete();
      offset = 0;
    }
    job._check();
    final response = await _open(job, Uri.parse(target.url), offset, target.name);
    final digest = _DigestSink();
    final hash = sha256.startChunkedConversion(digest);
    var received = 0;
    switch (response.statusCode) {
      case HttpStatus.ok:
        break;
      case HttpStatus.partialContent:
        final range = RegExp(r'^bytes (\d+)-')
            .firstMatch(response.headers.value(HttpHeaders.contentRangeHeader) ?? '');
        if (range == null || int.parse(range.group(1)!) != offset) {
          await response.listen(null).cancel();
          if (await part.exists()) await part.delete();
          throw DownloadNetworkError('unexpected range from server', target.name);
        }
        if (offset > 0) {
          await for (final chunk in part.openRead(0, offset)) {
            job._check();
            hash.add(chunk);
          }
        }
        received = offset;
        job._emit(base + received);
      case HttpStatus.requestedRangeNotSatisfiable:
        // The server has no more bytes: the part is all there is.
        await response.listen(null).cancel();
        final actual = offset == 0
            ? sha256.convert(const []).toString()
            : await ModelStore.hashFile(part.path);
        if (offset == target.bytes && actual == target.sha256.toLowerCase()) {
          await part.rename(dest.path);
          return;
        }
        if (await part.exists()) await part.delete();
        throw ChecksumMismatch(target.name, target.sha256.toLowerCase(), actual);
      default:
        await response.listen(null).cancel();
        throw DownloadHttpError(response.statusCode, target.name);
    }
    var oversize = false;
    final sink = await part.open(mode: received > 0 ? FileMode.append : FileMode.write);
    try {
      await for (final chunk in response.timeout(idleTimeout)) {
        job._check();
        hash.add(chunk);
        if (received + chunk.length > target.bytes) {
          oversize = true;
          break;
        }
        await sink.writeFrom(chunk);
        received += chunk.length;
        job._emit(base + received);
      }
    } finally {
      await sink.close();
    }
    job._check();
    if (!oversize && received < target.bytes) {
      throw DownloadNetworkError('connection closed early', target.name);
    }
    hash.close();
    final actual = digest.value.toString();
    if (oversize || actual != target.sha256.toLowerCase()) {
      await part.delete();
      throw ChecksumMismatch(target.name, target.sha256.toLowerCase(), actual);
    }
    await part.rename(dest.path);
  }

  /// GET with manual redirects, each hop checked by [_checkUrl].
  Future<HttpClientResponse> _open(DownloadJob job, Uri uri, int offset, String file) async {
    job._check();
    final client = job._client ??= _httpClient()
      ..connectionTimeout = connectionTimeout
      ..userAgent = 'Tinglang/$appVersion'
      ..autoUncompress = false;
    for (var hop = 0; ; hop++) {
      _checkUrl(uri, file);
      job._check();
      final request = await client.getUrl(uri);
      request
        ..followRedirects = false
        ..headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (offset > 0) request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
      final HttpClientResponse response;
      try {
        response = await request.close().timeout(idleTimeout);
      } on TimeoutException {
        request.abort();
        rethrow;
      }
      if (!response.isRedirect) return response;
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.listen(null).cancel();
      if (location == null || hop >= _maxRedirects) {
        throw DownloadHttpError(response.statusCode, file);
      }
      uri = uri.resolve(location);
    }
  }

  /// Extracts [files] from the verified archive with the system `tar`, checks
  /// each against the catalog and moves it into [dir].
  Future<void> _extract(DownloadJob job, String dir, String folder, List<ModelFile> files) async {
    final staging = Directory(p.join(dir, stagingName));
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create();
    try {
      // Relative paths only, so tar's messages never contain local folders.
      final process = job._process = await Process.start(_tar, [
        '-xjf',
        archiveName,
        '-C',
        stagingName,
        for (final file in files) folder.isEmpty ? file.name : '$folder/${file.name}',
      ], workingDirectory: dir);
      final errors = process.stderr.transform(utf8.decoder).join();
      await process.stdout.drain<void>();
      final code = await process.exitCode;
      job._process = null;
      job._check();
      if (code != 0) {
        final first = (await errors).trim().split('\n').first;
        throw ModelArchiveError('tar exited with $code: $first');
      }
      for (final file in files) {
        final extracted = p.join(staging.path, folder, file.name);
        final stat = await FileStat.stat(extracted);
        if (stat.type != FileSystemEntityType.file) {
          throw ModelArchiveError('not in the archive', file.name);
        }
        final actual = await ModelStore.hashFile(extracted);
        if (stat.size != file.bytes || actual != file.sha256.toLowerCase()) {
          throw ChecksumMismatch(file.name, file.sha256.toLowerCase(), actual);
        }
        await File(extracted).rename(p.join(dir, file.name));
        job._check();
      }
    } finally {
      job._process = null;
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }
}

final class _Target {
  _Target.file(ModelFile file, String dir)
    : name = file.name,
      url = file.url,
      bytes = file.bytes,
      sha256 = file.sha256,
      path = p.join(dir, file.name);

  _Target.archive(ModelArchive archive, this.name, String dir)
    : url = archive.url,
      bytes = archive.bytes,
      sha256 = archive.sha256,
      path = p.join(dir, ModelDownloader.archiveName);

  final String name, url, sha256, path;
  final int bytes;
}

final class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
