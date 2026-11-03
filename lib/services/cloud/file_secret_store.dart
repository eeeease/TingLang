import 'dart:convert';
import 'dart:io';

import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

/// The TingLang account's refresh token, in a file only this user can read
/// (mode 600) inside the data folder. Not the Keychain: builds are signed
/// ad hoc, so macOS asks for the Keychain password after every update
/// before an item written by an older build can be read. Nothing else is
/// kept here; provider keys stay in the Keychain.
final class FileSecretStore implements SecretStore {
  FileSecretStore(this.file);
  final File file;

  Map<String, String> _read() {
    if (!file.existsSync()) return {};
    try {
      final json = jsonDecode(file.readAsStringSync());
      return json is Map
          ? {
              for (final e in json.entries)
                if (e.value is String) '${e.key}': e.value as String,
            }
          : {};
    } on FormatException {
      return {};
    }
  }

  Future<void> _write(Map<String, String> values) async {
    if (values.isEmpty) {
      if (file.existsSync()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    // Written beside it, made private, then moved over: never readable by
    // others, never half-written.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(values), flush: true);
    final chmod = await Process.run('chmod', ['600', temp.path]);
    if (chmod.exitCode != 0) {
      await temp.delete();
      throw FileSystemException('Could not make the token file private', temp.path);
    }
    await temp.rename(file.path);
  }

  @override
  Future<String?> read(String key) async => _read()[key];

  @override
  Future<void> write(String key, String value) => _write({..._read(), key: value});

  @override
  Future<void> delete(String key) => _write(_read()..remove(key));
}
