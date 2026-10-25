import 'dart:convert';

import 'llm_client.dart';

/// A model from the bundled catalog (LiteLLM data). Prices are USD per
/// million tokens as published by the provider; null when unknown.
class CatalogModel {
  const CatalogModel(
    this.id, {
    this.context,
    this.inputPerMTok,
    this.outputPerMTok,
    this.jsonSchema = false,
  });
  final String id;
  final int? context;
  final double? inputPerMTok, outputPerMTok;

  /// Native JSON-schema structured output.
  final bool jsonSchema;
  bool get priced => inputPerMTok != null && outputPerMTok != null;

  double cost(int inputTokens, int outputTokens) =>
      (inputTokens * (inputPerMTok ?? 0) + outputTokens * (outputPerMTok ?? 0)) / 1e6;
}

/// A ready-made endpoint. Every one is BYOK: Tinglang never ships or proxies
/// a key.
class ProviderPreset {
  const ProviderPreset(
    this.id,
    this.label,
    this.baseUrl, {
    this.protocol = LlmProtocol.openai,
    this.model = '',
    this.needsKey = true,
  });
  final String id, label, baseUrl, model;
  final LlmProtocol protocol;
  final bool needsKey;

  static const custom = ProviderPreset('custom', 'Custom', '', needsKey: false);
}

/// Providers and models from `assets/providers/catalog.v1.json`, built from
/// LiteLLM's model catalog by `tools/build_provider_catalog.py`.
class ProviderCatalog {
  ProviderCatalog(this.presets, this._models, {this.built = ''});

  factory ProviderCatalog.fromJson(String text) {
    final json = jsonDecode(text) as Map<String, Object?>;
    final presets = [
      for (final p in (json['providers']! as List).cast<Map<String, Object?>>())
        ProviderPreset(
          p['id']! as String,
          p['label']! as String,
          p['base_url']! as String,
          protocol: LlmProtocol.parse(p['protocol'] as String?),
          model: (p['default_model'] as String?) ?? '',
          needsKey: p['needs_key'] == true,
        ),
      ProviderPreset.custom,
    ];
    final models = <String, List<CatalogModel>>{};
    (json['models']! as Map<String, Object?>).forEach((provider, rows) {
      models[provider] = [
        for (final r in (rows! as List).cast<List<Object?>>())
          CatalogModel(
            r[0]! as String,
            context: (r[1] as num?)?.toInt(),
            inputPerMTok: (r[2] as num?)?.toDouble(),
            outputPerMTok: (r[3] as num?)?.toDouble(),
            jsonSchema: r[4] == 1,
          ),
      ];
    });
    final meta = json['meta'];
    return ProviderCatalog(
      presets,
      models,
      built: meta is Map && meta['built'] is String ? meta['built'] as String : '',
    );
  }

  /// Presets in display order; `custom` is last.
  final List<ProviderPreset> presets;
  final Map<String, List<CatalogModel>> _models;

  /// Date the catalog was built from LiteLLM.
  final String built;

  ProviderPreset preset(String id) =>
      presets.firstWhere((p) => p.id == id, orElse: () => ProviderPreset.custom);
  List<CatalogModel> models(String presetId) => _models[presetId] ?? const [];
  CatalogModel? model(String presetId, String modelId) =>
      models(presetId).where((m) => m.id == modelId).firstOrNull;
}

/// Approximate token cost of an AI course, before running it. Generous on
/// output: reasoning models also spend output tokens on thinking.
class CostEstimate {
  const CostEstimate({
    required this.calls,
    required this.inputTokens,
    required this.outputTokens,
    this.usd,
  });
  final int calls, inputTokens, outputTokens;

  /// Null when the model has no published price (or runs locally).
  final double? usd;

  static CostEstimate forCourse({
    required int windows,
    required int clips,
    required int transcriptChars,
    CatalogModel? model,
  }) {
    // ~4 characters per token; prompts add ~800 tokens of instructions.
    final selection = windows > clips ? 1 : 0;
    final selectionIn = selection * (800 + windows * 160);
    final clipIn = clips == 0 ? 0 : clips * 900 + transcriptChars ~/ 4;
    // One clip plan is ~2.5k JSON tokens plus thinking; repairs add ~25 %.
    final clipOut = (clips * 4000 * 1.25).round();
    final input = selectionIn + (clipIn * 1.25).round();
    final output = selection * 600 + clipOut;
    return CostEstimate(
      calls: selection + clips,
      inputTokens: input,
      outputTokens: output,
      usd: model != null && model.priced ? model.cost(input, output) : null,
    );
  }
}

/// `$4`, `$0.28`, `$0.012`.
String formatUsd(double v) {
  if (v >= 1) return '\$${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}';
  return '\$${v.toStringAsFixed(v >= 0.1 ? 2 : 3)}';
}

/// `200K`, `1M`, `12.3K`.
String formatTokens(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M';
  if (n >= 10000) return '${(n / 1000).round()}K';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}
