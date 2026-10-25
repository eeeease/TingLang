import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang_native/tinglang_native.dart';

/// Downloads the real Silero VAD pack (0.6 MB) from k2-fsa's GitHub release
/// through the redirect to GitHub's object storage. Network access is opt-in:
/// `TINGLANG_NETWORK_TESTS=1 flutter test test/model_download_network_test.dart`.
void main() {
  final enabled = Platform.environment['TINGLANG_NETWORK_TESTS'] == '1';

  test('real download: redirect, size and SHA-256, then resume is a no-op', () async {
    final dir = await Directory.systemTemp.createTemp('tinglang-net-');
    addTearDown(() => dir.delete(recursive: true));
    final store = ModelStore(dir.path);
    var clients = 0;
    final downloader = ModelDownloader(
      store: store,
      appVersion: 'test',
      httpClient: () {
        clients++;
        return HttpClient();
      },
    );
    final pack = SpeechModels.vad;
    final seen = <DownloadProgress>[];
    await downloader.install(pack, consent: DownloadConsent.forPack(pack), onProgress: seen.add);
    expect(store.installed, contains(pack.id));
    expect(seen.last.received, pack.downloadBytes);
    expect(await store.verify(pack.id), isTrue);
    expect(clients, 1);

    // Installed: a second install makes no request.
    await downloader.install(pack, consent: DownloadConsent.forPack(pack));
    expect(clients, 1);
  }, skip: enabled ? false : 'set TINGLANG_NETWORK_TESTS=1 to download from GitHub');
}
