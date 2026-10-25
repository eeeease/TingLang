import 'dart:async';
import 'dart:convert';

import 'package:tinglang_cloud_asr/tinglang_cloud_asr.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

import 'cloud_file_transcriber.dart';
import 'cloud_streaming_asr.dart';
import 'portable_pipeline.dart' show translatorReady;

/// Where a cloud speech service's credentials live: one JSON object per
/// service in the platform [SecretStore] (Keychain on macOS) under
/// `asr:<service id>`. Nothing is stored in the database.
final class CloudAsrSecrets {
  CloudAsrSecrets(this._store);
  final FutureOr<SecretStore?> Function() _store;

  static String keyFor(String providerId) => 'asr:$providerId';

  Future<CloudCredentials?> read(String providerId) async {
    final store = await _store();
    final text = await store?.read(keyFor(providerId));
    if (text == null || text.isEmpty) return null;
    try {
      final json = jsonDecode(text);
      if (json is! Map) return null;
      return {
        for (final e in json.entries)
          if (e.key is String && e.value is String) e.key as String: e.value as String,
      };
    } on FormatException {
      return null;
    }
  }

  Future<void> write(String providerId, CloudCredentials values) async {
    final store = await _store() ?? (throw StateError('No secret store on this platform.'));
    await store.write(keyFor(providerId), jsonEncode(values));
  }

  Future<void> delete(String providerId) async {
    await (await _store())?.delete(keyFor(providerId));
  }
}

/// The platform's secret store, or null where there is none.
Future<SecretStore?> platformSecretStore(TinglangPlatform platform) async {
  final choice = platform.secrets.pick(await platform.probe());
  return choice.hasSelection ? choice.create() : null;
}

/// Registers every [CloudAsrProviders.all] service as the `cloud.<id>` live
/// and/or file backend. Their specs are `cloud: true`, so the registry uses
/// one only when the user chose it and the app put it in
/// [TinglangPlatform.enabledCloudBackends]. Credentials are read when a
/// session or job starts.
void registerCloudBackends(TinglangPlatform platform, {List<CloudAsrProvider>? providers}) {
  final secrets = CloudAsrSecrets(() => platformSecretStore(platform));
  for (final provider in providers ?? CloudAsrProviders.all) {
    final id = 'cloud.${provider.info.id}';
    final spec = BackendCatalog.cloudAsr.where((s) => s.id == id).firstOrNull;
    if (spec == null) continue;
    Future<CloudCredentials?> credentials() => secrets.read(provider.info.id);
    if (provider.info.live) {
      platform.liveAsr.register(
        BackendFactory<StreamingAsrBackend>(
          spec,
          () => CloudStreamingAsr(provider, credentials: credentials),
        ),
      );
    }
    if (provider.info.file) {
      platform.fileAsr.register(
        BackendFactory<FileTranscriber>(
          spec,
          () => CloudFileTranscriber(
            provider,
            credentials: credentials,
            decoder: () async {
              final probe = await platform.probe();
              return platform.decoders.pick(probe).create();
            },
            translatorFor: (pair) async {
              final probe = await platform.probe();
              final choice = platform.translators.pick(probe);
              if (!choice.hasSelection) return null;
              final translator = choice.create();
              return translatorReady(translator, pair, probe) ? translator : null;
            },
          ),
        ),
      );
    }
  }
}
