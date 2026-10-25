import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang_native/tinglang_native.dart';

List<int> _bytes(int n, int seed) => List.generate(n, (i) => (i * 31 + seed * 7 + (i >> 8)) & 0xff);

void main() {
  late Directory data;
  late ModelPack pack;
  late ModelStore store;
  final a = _bytes(3000, 1);
  final b = _bytes(500, 2);

  ModelFile file(String name, List<int> bytes) => ModelFile(
    name: name,
    url: 'https://example.invalid/$name',
    bytes: bytes.length,
    sha256: sha256.convert(bytes).toString(),
  );

  setUp(() async {
    data = await Directory.systemTemp.createTemp('tinglang-store-');
    pack = ModelPack(
      id: 'test-pack',
      license: const ModelLicense('MIT', 'https://example.invalid'),
      files: [file('a.onnx', a), file('tokens.txt', b)],
    );
    store = ModelStore(data.path, catalog: [pack]);
  });
  tearDown(() => data.delete(recursive: true));

  String path(String name) => p.join(store.directoryOf(pack.id), name);

  Future<void> install() async {
    await Directory(store.directoryOf(pack.id)).create(recursive: true);
    await File(path('a.onnx')).writeAsBytes(a);
    await File(path('tokens.txt')).writeAsBytes(b);
    await store.writeReceipt(pack);
  }

  Future<void> editReceipt(void Function(Map<String, dynamic> json) edit) async {
    final receipt = File(path(ModelStore.receiptName));
    final json = jsonDecode(await receipt.readAsString()) as Map<String, dynamic>;
    edit(json);
    await receipt.writeAsString(jsonEncode(json));
  }

  test('lays packs out under <data>/models/<id>', () {
    expect(store.root, p.join(data.path, 'models'));
    expect(store.directoryOf('test-pack'), p.join(data.path, 'models', 'test-pack'));
    expect(store.installed, isEmpty);
  });

  test('a pack with a matching receipt and file sizes is installed', () async {
    await install();
    expect(store.installed, {'test-pack'});
    final receipt =
        jsonDecode(await File(path(ModelStore.receiptName)).readAsString()) as Map<String, dynamic>;
    expect(receipt['pack'], 'test-pack');
    expect(receipt['files'], {
      'a.onnx': {'bytes': 3000, 'sha256': sha256.convert(a).toString()},
      'tokens.txt': {'bytes': 500, 'sha256': sha256.convert(b).toString()},
    });
    expect(DateTime.parse(receipt['installedAt'] as String).isUtc, isTrue);
    expect(File(path('${ModelStore.receiptName}.tmp')).existsSync(), isFalse);
    expect(await store.verify(pack.id), isTrue);
  });

  test('installed is cached until refresh', () async {
    await install();
    expect(store.installed, {'test-pack'});
    await File(path('a.onnx')).delete();
    expect(store.installed, {'test-pack'});
    expect(store.refresh(), isEmpty);
    expect(store.installed, isEmpty);
  });

  test('no receipt, a missing file or a size mismatch is not installed', () async {
    await install();
    await File(path(ModelStore.receiptName)).delete();
    expect(store.refresh(), isEmpty);

    await install();
    await File(path('a.onnx')).writeAsBytes([1], mode: FileMode.append);
    expect(store.refresh(), isEmpty);

    await install();
    await File(path('tokens.txt')).delete();
    expect(store.refresh(), isEmpty);
  });

  test('a tampered receipt is not installed', () async {
    await install();
    await editReceipt((json) => json['files']['a.onnx']['sha256'] = '0' * 64);
    expect(store.refresh(), isEmpty);

    await install();
    await editReceipt((json) => json['files']['a.onnx']['bytes'] = 1);
    expect(store.refresh(), isEmpty);

    await install();
    await editReceipt((json) => (json['files'] as Map).remove('tokens.txt'));
    expect(store.refresh(), isEmpty);

    await install();
    await editReceipt((json) => json['pack'] = 'other');
    expect(store.refresh(), isEmpty);

    await install();
    await File(path(ModelStore.receiptName)).writeAsString('{not json');
    expect(store.refresh(), isEmpty);
  });

  test('a receipt for an older catalog checksum is not installed', () async {
    await install();
    final updated = ModelPack(
      id: pack.id,
      license: pack.license,
      files: [file('a.onnx', _bytes(3000, 9)), pack.files[1]],
    );
    expect(ModelStore(data.path, catalog: [updated]).installed, isEmpty);
  });

  test('verify re-hashes and drops the receipt on a same-size change', () async {
    await install();
    await File(path('a.onnx')).writeAsBytes(_bytes(3000, 5));
    expect(store.refresh(), {'test-pack'}, reason: 'probes trust size + receipt');
    expect(await store.verify(pack.id), isFalse);
    expect(store.installed, isEmpty);
    expect(File(path(ModelStore.receiptName)).existsSync(), isFalse);
    expect(File(path('tokens.txt')).existsSync(), isTrue);
  });

  test('a pack without catalog files is never installed', () async {
    final empty = ModelPack(id: 'empty', license: pack.license, files: const []);
    final store = ModelStore(data.path, catalog: [empty]);
    await Directory(store.directoryOf('empty')).create(recursive: true);
    await store.writeReceipt(empty);
    expect(store.refresh(), isEmpty);
  });

  test('bytesOnDisk counts partial downloads', () async {
    expect(store.bytesOnDisk(pack.id), 0);
    await install();
    await File(path('extra.onnx.part')).writeAsBytes(List.filled(100, 0));
    final receiptBytes = await File(path(ModelStore.receiptName)).length();
    expect(store.bytesOnDisk(pack.id), 3000 + 500 + 100 + receiptBytes);
  });

  test('delete removes everything and reports the change', () async {
    await install();
    await File(path('tokens.txt.part')).writeAsBytes([1, 2, 3]);
    final changes = <Set<String>>[];
    final sub = store.changes.listen(changes.add);
    await store.delete(pack.id);
    await pumpEventQueue();
    await sub.cancel();
    expect(Directory(store.directoryOf(pack.id)).existsSync(), isFalse);
    expect(store.installed, isEmpty);
    expect(changes, [<String>{}]);
    await store.delete(pack.id); // already gone
  });

  test('delete of a symlinked pack folder removes only the link', () async {
    final outside = await Directory(p.join(data.path, 'outside')).create();
    await File(p.join(outside.path, 'keep.txt')).writeAsString('keep');
    await Directory(store.root).create(recursive: true);
    await Link(store.directoryOf(pack.id)).create(outside.path);
    await store.delete(pack.id);
    expect(Link(store.directoryOf(pack.id)).existsSync(), isFalse);
    expect(File(p.join(outside.path, 'keep.txt')).existsSync(), isTrue);
  });

  test('rejects pack ids and file names that are not plain names', () async {
    for (final bad in [
      '',
      '..',
      '../x',
      'a/b',
      r'a\b',
      'x..y',
      '.receipt.json',
      'a.onnx.part',
      'c:x',
      'a\x00b',
    ]) {
      expect(() => store.directoryOf(bad), throwsArgumentError, reason: bad);
      expect(() => ModelStore.checkName(bad), throwsArgumentError, reason: bad);
      await expectLater(store.delete(bad), throwsArgumentError, reason: bad);
    }
    expect(ModelStore.checkName('encoder-epoch-99-avg-1.int8.onnx'), isNotEmpty);
  });

  test('a catalog file with an unsafe name never counts as installed', () async {
    await install();
    final evil = ModelPack(
      id: pack.id,
      license: pack.license,
      files: [...pack.files, file('../a.onnx', a)],
    );
    expect(ModelStore(data.path, catalog: [evil]).installed, isEmpty);
  });
}
