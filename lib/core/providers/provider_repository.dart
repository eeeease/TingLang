import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

import '../db/database.dart';
import 'catalog.dart';
import 'llm_client.dart';

export 'catalog.dart';

/// True when [baseUrl] points at this computer: transcripts never leave it.
bool isLocalUrl(String baseUrl) {
  final host = Uri.tryParse(baseUrl)?.host.toLowerCase() ?? '';
  return host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host == '[::1]' ||
      host.endsWith('.localhost');
}

class LlmProvider {
  const LlmProvider({
    required this.id,
    required this.preset,
    required this.label,
    required this.baseUrl,
    required this.model,
    required this.enabled,
    this.hasKey = false,
  });
  final String id, preset, label, baseUrl, model;
  final bool enabled, hasKey;

  /// Cloud providers receive transcript text; shown as a label in the UI.
  bool get cloud => !isLocalUrl(baseUrl);
}

/// Features that can be routed to a provider.
abstract final class Features {
  static const courseGeneration = 'course_generation';
}

/// BYOK provider settings in SQLite; API keys live only in the OS secret
/// store under `provider:<id>` (Keychain on macOS).
class ProviderRepository {
  ProviderRepository(this.db, this.secrets, this.catalog);
  final TinglangDatabase db;
  final SecretStore? secrets;
  final ProviderCatalog catalog;

  static String secretKey(String id) => 'provider:$id';

  Future<List<LlmProvider>> list() async {
    final rows =
        await (db.select(db.providerConfigs)
              ..where((p) => p.kind.equals('llm'))
              ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
            .get();
    return [
      for (final r in rows)
        LlmProvider(
          id: r.id,
          preset: r.preset,
          label: r.label,
          baseUrl: r.baseUrl ?? '',
          model: r.model ?? '',
          enabled: r.enabled,
          hasKey: r.secretRef != null,
        ),
    ];
  }

  Future<LlmProvider?> byId(String id) async => (await list()).where((p) => p.id == id).firstOrNull;

  /// Saves settings; [apiKey] (when given) goes to the secret store, an
  /// empty string removes it. The database only records that a key exists.
  Future<void> save(LlmProvider provider, {String? apiKey}) async {
    var secretRef = (await byId(provider.id))?.hasKey == true ? secretKey(provider.id) : null;
    if (apiKey != null) {
      final store = secrets;
      if (apiKey.trim().isEmpty) {
        await store?.delete(secretKey(provider.id));
        secretRef = null;
      } else {
        if (store == null) throw StateError('No secure key storage on this computer');
        await store.write(secretKey(provider.id), apiKey.trim());
        secretRef = secretKey(provider.id);
      }
    }
    final now = DateTime.now().toUtc();
    await db
        .into(db.providerConfigs)
        .insert(
          ProviderConfigsCompanion.insert(
            id: provider.id,
            kind: 'llm',
            preset: provider.preset,
            label: provider.label,
            baseUrl: Value(provider.baseUrl.trim()),
            model: Value(provider.model.trim()),
            secretRef: Value(secretRef),
            cloud: Value(provider.cloud),
            enabled: Value(provider.enabled),
            createdAt: now,
            updatedAt: now,
          ),
          onConflict: DoUpdate(
            (old) => ProviderConfigsCompanion(
              preset: Value(provider.preset),
              label: Value(provider.label),
              baseUrl: Value(provider.baseUrl.trim()),
              model: Value(provider.model.trim()),
              secretRef: Value(secretRef),
              cloud: Value(provider.cloud),
              enabled: Value(provider.enabled),
              updatedAt: Value(now),
            ),
          ),
        );
  }

  Future<void> delete(String id) async {
    await secrets?.delete(secretKey(id));
    await (db.delete(db.providerConfigs)..where((p) => p.id.equals(id))).go();
  }

  Future<String?> apiKey(String id) async => secrets?.read(secretKey(id));

  LlmProtocol protocolOf(LlmProvider provider) => catalog.preset(provider.preset).protocol;

  /// Catalog facts (price, context) for the provider's model, if listed.
  CatalogModel? modelInfo(LlmProvider provider) => catalog.model(provider.preset, provider.model);

  Future<LlmClient> client(LlmProvider provider) async => LlmClient(
    baseUrl: provider.baseUrl,
    model: provider.model,
    apiKey: await apiKey(provider.id),
    protocol: protocolOf(provider),
  );

  /// The provider a feature uses, if the user picked an enabled one.
  Future<LlmProvider?> routed(String feature) async {
    final route = await (db.select(
      db.featureRoutes,
    )..where((r) => r.feature.equals(feature))).getSingleOrNull();
    if (route == null || !route.enabled || route.providerId == null) return null;
    final provider = await byId(route.providerId!);
    return provider != null && provider.enabled ? provider : null;
  }

  Future<String?> routedId(String feature) async => (await (db.select(
    db.featureRoutes,
  )..where((r) => r.feature.equals(feature))).getSingleOrNull())?.providerId;

  Future<void> setRoute(String feature, String? providerId) => db
      .into(db.featureRoutes)
      .insertOnConflictUpdate(
        FeatureRoutesCompanion.insert(
          feature: feature,
          providerId: Value(providerId),
          enabled: Value(providerId != null),
        ),
      );
}

/// LLM replies keyed by sha256(provider, model, prompt version, messages):
/// regenerating the same transcript makes no requests.
class LlmCacheStore {
  LlmCacheStore(this.db);
  final TinglangDatabase db;

  static String key(String providerId, String model, String version, String system, String user) =>
      sha256
          .convert(utf8.encode(jsonEncode([providerId, model, version, system, user])))
          .toString();

  Future<Map<String, Object?>?> read(String key) async {
    final row = await (db.select(db.llmCache)..where((c) => c.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    final json = jsonDecode(row.responseJson);
    return json is Map<String, Object?> ? json : null;
  }

  Future<void> write(String key, String providerId, String model, Map<String, Object?> response) =>
      db
          .into(db.llmCache)
          .insertOnConflictUpdate(
            LlmCacheCompanion.insert(
              key: key,
              providerId: providerId,
              model: model,
              responseJson: jsonEncode(response),
              createdAt: DateTime.now().toUtc(),
            ),
          );
}
