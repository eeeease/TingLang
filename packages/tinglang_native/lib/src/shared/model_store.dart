import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

/// One file as recorded in a pack's `.receipt.json`.
typedef ReceiptEntry = ({int bytes, String sha256});

/// Downloaded model packs under `<data>/models/<pack id>/`.
///
/// A pack is installed when its `.receipt.json` lists every catalog file with
/// the catalog's size and SHA-256 and each file has that size on disk. Probes
/// trust the receipt and never re-hash; [verify] does.
final class ModelStore implements ModelInventory {
  ModelStore(String dataDirectory, {Iterable<ModelPack>? catalog})
    : root = p.join(p.absolute(dataDirectory), 'models'),
      catalog = List.unmodifiable(catalog ?? SpeechModels.packs);

  static const receiptName = '.receipt.json';
  static const partSuffix = '.part';

  /// `<data>/models`.
  final String root;

  /// Packs [installed] considers.
  final List<ModelPack> catalog;

  Set<String>? _installed;
  final _changes = StreamController<Set<String>>.broadcast();

  /// Cached; scanned on first use and by [refresh], [delete], [writeReceipt].
  @override
  Set<String> get installed => _installed ??= _scan();

  /// The new [installed] set whenever it changes.
  Stream<Set<String>> get changes => _changes.stream;

  @override
  String directoryOf(String packId) => p.join(root, checkName(packId));

  ModelPack? packById(String packId) {
    for (final pack in catalog) {
      if (pack.id == packId) return pack;
    }
    return null;
  }

  /// Re-scans the disk (cheap: one small JSON read and a stat per file).
  Set<String> refresh() {
    final previous = _installed;
    final next = _scan();
    _installed = next;
    if (previous == null || previous.length != next.length || !previous.containsAll(next)) {
      _changes.add(next);
    }
    return next;
  }

  /// Everything in the pack's folder, including partial downloads.
  int bytesOnDisk(String packId) {
    final dir = Directory(directoryOf(packId));
    if (!dir.existsSync()) return 0;
    var total = 0;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) total += entity.lengthSync();
    }
    return total;
  }

  /// Re-hashes an installed pack (in a worker isolate). On a mismatch the
  /// receipt is removed, so the pack is no longer installed; intact files
  /// stay and a reinstall keeps them.
  Future<bool> verify(String packId) async {
    final pack = packById(packId);
    if (pack == null || !_complete(pack)) return false;
    for (final file in pack.files) {
      final actual = await hashFile(p.join(directoryOf(packId), file.name));
      if (actual != file.sha256.toLowerCase()) {
        final receipt = File(p.join(directoryOf(packId), receiptName));
        if (await receipt.exists()) await receipt.delete();
        refresh();
        return false;
      }
    }
    return true;
  }

  /// Removes the pack's folder, partial downloads included. Cancel a
  /// running download first ([ModelDownloader.delete] does both).
  Future<void> delete(String packId) async {
    final path = directoryOf(packId);
    if (!p.isWithin(root, path)) throw ArgumentError.value(packId, 'packId', 'outside $root');
    switch (await FileSystemEntity.type(path, followLinks: false)) {
      case FileSystemEntityType.notFound:
        break;
      case FileSystemEntityType.link:
        await Link(path).delete();
      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: true);
      default:
        await File(path).delete();
    }
    refresh();
  }

  /// The receipt's files, or null when it is missing or unreadable.
  Map<String, ReceiptEntry>? readReceipt(String packId) {
    try {
      final file = File(p.join(directoryOf(packId), receiptName));
      if (!file.existsSync()) return null;
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map<String, Object?> || json['pack'] != packId) return null;
      final files = json['files'];
      if (files is! Map<String, Object?>) return null;
      return {
        for (final MapEntry(:key, :value) in files.entries)
          if (value case {'bytes': final int bytes, 'sha256': final String sha256})
            key: (bytes: bytes, sha256: sha256),
      };
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// Marks [pack] installed. Only the downloader calls this, after it has
  /// verified every file. Written to a temp file and renamed (atomic).
  Future<void> writeReceipt(ModelPack pack, {DateTime? installedAt}) async {
    final dir = directoryOf(pack.id);
    final tmp = File(p.join(dir, '$receiptName.tmp'));
    await tmp.writeAsString(
      jsonEncode({
        'pack': pack.id,
        'files': {
          for (final file in pack.files)
            file.name: {'bytes': file.bytes, 'sha256': file.sha256.toLowerCase()},
        },
        'installedAt': (installedAt ?? DateTime.now()).toUtc().toIso8601String(),
      }),
      flush: true,
    );
    await tmp.rename(p.join(dir, receiptName));
    refresh();
  }

  Set<String> _scan() => Set.unmodifiable({
    for (final pack in catalog)
      if (_complete(pack)) pack.id,
  });

  bool _complete(ModelPack pack) {
    if (pack.files.isEmpty) return false;
    try {
      final dir = directoryOf(pack.id);
      final receipt = readReceipt(pack.id);
      if (receipt == null) return false;
      for (final file in pack.files) {
        final entry = receipt[checkName(file.name)];
        if (entry == null ||
            entry.bytes != file.bytes ||
            entry.sha256.toLowerCase() != file.sha256.toLowerCase()) {
          return false;
        }
        final stat = FileStat.statSync(p.join(dir, file.name));
        if (stat.type != FileSystemEntityType.file || stat.size != file.bytes) return false;
      }
      return true;
    } on ArgumentError {
      return false;
    }
  }

  /// Rejects anything but a plain file or folder name: no separators, `..`,
  /// leading dot (reserved for receipts and partials), `:` or NUL.
  static String checkName(String name) {
    if (name.isEmpty ||
        name.startsWith('.') ||
        name.contains('..') ||
        name.contains('/') ||
        name.contains(r'\') ||
        name.contains(':') ||
        name.contains('\x00') ||
        name.endsWith(partSuffix)) {
      throw ArgumentError.value(name, 'name', 'not a plain file name');
    }
    return name;
  }

  /// Lower-case hex SHA-256 of a file, hashed in a worker isolate.
  static Future<String> hashFile(String path) => Isolate.run(() => _hash(path));

  static Future<String> _hash(String path) async =>
      (await sha256.bind(File(path).openRead()).first).toString();
}
