import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/services/cloud/file_secret_store.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('tinglang-tokens-'));
  tearDown(() => dir.delete(recursive: true));

  test('the account token is kept in a file only this user can read', () async {
    final file = File('${dir.path}/account/tokens.json');
    final store = FileSecretStore(file);
    expect(await store.read('account:https://api.tinglang.app'), isNull);

    await store.write('account:https://api.tinglang.app', 'refresh-1');
    await store.write('account:http://127.0.0.1:8787', 'refresh-local');
    expect(await FileSecretStore(file).read('account:https://api.tinglang.app'), 'refresh-1');
    expect((await file.stat()).modeString(), 'rw-------');
    expect(File('${file.path}.tmp').existsSync(), isFalse);

    await store.write('account:https://api.tinglang.app', 'refresh-2');
    expect(await store.read('account:https://api.tinglang.app'), 'refresh-2');

    await store.delete('account:https://api.tinglang.app');
    expect(await store.read('account:https://api.tinglang.app'), isNull);
    expect(await store.read('account:http://127.0.0.1:8787'), 'refresh-local');
    await store.delete('account:http://127.0.0.1:8787');
    expect(file.existsSync(), isFalse, reason: 'nothing left, no file');
  });

  test('a damaged file reads as signed out, not as an error', () async {
    final file = File('${dir.path}/tokens.json')..writeAsStringSync('{not json');
    expect(await FileSecretStore(file).read('account:x'), isNull);
  });
}
