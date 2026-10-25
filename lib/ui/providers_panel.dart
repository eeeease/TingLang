import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import '../core/providers/llm_client.dart';
import '../core/providers/provider_repository.dart';
import 'brand.dart';

/// Settings → AI providers: BYOK OpenAI-compatible endpoints. Keys go to the
/// Keychain; the list only shows whether one is saved.
class ProvidersPanel extends StatefulWidget {
  const ProvidersPanel({super.key, required this.providers});
  final ProviderRepository providers;
  @override
  State<ProvidersPanel> createState() => _ProvidersPanelState();
}

class _ProvidersPanelState extends State<ProvidersPanel> {
  List<LlmProvider> _list = const [];
  String? _defaultId;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final list = await widget.providers.list();
    final route = await widget.providers.routedId(Features.courseGeneration);
    if (mounted) {
      setState(() {
        _list = list;
        _defaultId = route;
      });
    }
  }

  Future<void> _edit(LlmProvider? provider) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProviderDialog(providers: widget.providers, provider: provider),
    );
    if (saved != true) return;
    // The first provider becomes the course-generation default.
    if (_defaultId == null) {
      final list = await widget.providers.list();
      if (list.isNotEmpty) {
        await widget.providers.setRoute(Features.courseGeneration, list.first.id);
      }
    }
    await _reload();
  }

  Future<void> _delete(LlmProvider provider) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.providerDeleteTitle(provider.label)),
        content: Text(l.providerDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await reportAction(context, () => widget.providers.delete(provider.id));
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    final theme = Theme.of(context);
    return SlPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(l.providersTitle, style: theme.textTheme.titleLarge)),
              FilledButton.tonalIcon(
                key: const ValueKey('provider-add'),
                onPressed: () => _edit(null),
                icon: const Icon(Icons.add),
                label: Text(l.providerAdd),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(l.providersBody, style: TextStyle(color: c.muted)),
          const SizedBox(height: 14),
          if (_list.isEmpty)
            SlNotice(l.providersEmpty)
          else
            RadioGroup<String>(
              groupValue: _defaultId,
              onChanged: (id) => reportAction(context, () async {
                await widget.providers.setRoute(Features.courseGeneration, id);
                await _reload();
              }),
              child: Column(
                children: [
                  for (final p in _list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Tooltip(
                        message: l.providerDefault,
                        child: Radio<String>(value: p.id, enabled: p.enabled),
                      ),
                      title: Row(
                        children: [
                          Flexible(child: Text(p.label, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          p.cloud
                              ? SlBadge.cloud(l.providerCloud)
                              : SlBadge(l.providerLocal, icon: Icons.computer_outlined),
                        ],
                      ),
                      subtitle: Text(
                        '${p.model.isEmpty ? '—' : p.model} · ${Uri.tryParse(p.baseUrl)?.host ?? p.baseUrl}'
                        '${widget.providers.catalog.preset(p.preset).needsKey ? ' · ${p.hasKey ? l.providerKeySaved : l.providerKeyMissing}' : ''}',
                        style: TextStyle(color: c.muted, fontSize: 13),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: p.enabled,
                            onChanged: (v) => reportAction(context, () async {
                              await widget.providers.save(
                                LlmProvider(
                                  id: p.id,
                                  preset: p.preset,
                                  label: p.label,
                                  baseUrl: p.baseUrl,
                                  model: p.model,
                                  enabled: v,
                                ),
                              );
                              await _reload();
                            }),
                          ),
                          IconButton(
                            tooltip: l.edit,
                            onPressed: () => _edit(p),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: l.delete,
                            onPressed: () => _delete(p),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SlNotice(l.providersPrivacy),
        ],
      ),
    );
  }
}

String _usd(double v) => formatUsd(v);
String _tokens(int n) => formatTokens(n);
String _price(CatalogModel m) =>
    m.priced ? '${_usd(m.inputPerMTok!)} / ${_usd(m.outputPerMTok!)}' : '';

class _ProviderDialog extends StatefulWidget {
  const _ProviderDialog({required this.providers, this.provider});
  final ProviderRepository providers;
  final LlmProvider? provider;
  @override
  State<_ProviderDialog> createState() => _ProviderDialogState();
}

class _ProviderDialogState extends State<_ProviderDialog> {
  ProviderCatalog get _catalog => widget.providers.catalog;
  late String _preset = widget.provider?.preset ?? _catalog.presets.first.id;
  late final _label = TextEditingController(
    text: widget.provider?.label ?? _catalog.preset(_preset).label,
  );
  late final _url = TextEditingController(
    text: widget.provider?.baseUrl ?? _catalog.preset(_preset).baseUrl,
  );
  late final _model = TextEditingController(
    text: widget.provider?.model ?? _catalog.preset(_preset).model,
  );
  final _key = TextEditingController();
  List<String> _models = const [];
  String? _test;
  bool _testOk = false, _busy = false;

  @override
  void dispose() {
    for (final c in [_label, _url, _model, _key]) {
      c.dispose();
    }
    super.dispose();
  }

  void _choosePreset(String id) {
    final preset = _catalog.preset(id);
    setState(() {
      _preset = id;
      _label.text = preset.label;
      _url.text = preset.baseUrl;
      _model.text = preset.model;
      _models = const [];
      _test = null;
    });
  }

  Future<String?> _keyForTest() async {
    if (_key.text.trim().isNotEmpty) return _key.text.trim();
    final id = widget.provider?.id;
    return id == null ? null : widget.providers.apiKey(id);
  }

  Future<void> _testConnection() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _test = null;
    });
    final client = LlmClient(
      baseUrl: _url.text.trim(),
      model: _model.text.trim(),
      apiKey: await _keyForTest(),
      protocol: _catalog.preset(_preset).protocol,
      timeout: const Duration(seconds: 30),
    );
    try {
      final models = await client.models();
      if (!mounted) return;
      setState(() {
        _models = models;
        _testOk = true;
        _test = l.providerTestOk(models.length);
        if (_model.text.trim().isEmpty && models.isNotEmpty) _model.text = models.first;
      });
    } on LlmException catch (e) {
      if (mounted) {
        setState(() {
          _testOk = false;
          _test = e.unauthorized ? l.providerTestUnauthorized : '$e';
        });
      }
    } finally {
      client.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final id = widget.provider?.id ?? 'llm-${DateTime.now().microsecondsSinceEpoch}';
    final provider = LlmProvider(
      id: id,
      preset: _preset,
      label: _label.text.trim().isEmpty ? _catalog.preset(_preset).label : _label.text.trim(),
      baseUrl: _url.text.trim(),
      model: _model.text.trim(),
      enabled: widget.provider?.enabled ?? true,
    );
    await reportAction(context, () async {
      if (Uri.tryParse(provider.baseUrl)?.hasScheme != true) {
        throw FormatException(context.l10n.providerUrlInvalid);
      }
      if (provider.model.isEmpty) throw FormatException(context.l10n.providerModelRequired);
      await widget.providers.save(provider, apiKey: _key.text.trim().isEmpty ? null : _key.text);
      if (mounted) Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final preset = _catalog.preset(_preset);
    final local = isLocalUrl(_url.text);
    final listed = _catalog.models(_preset);
    final info = _catalog.model(_preset, _model.text.trim());
    final serverOnly = _models.where((m) => !listed.any((c) => c.id == m)).toList();
    return AlertDialog(
      title: Text(widget.provider == null ? l.providerAdd : l.providerEdit),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _preset,
                decoration: InputDecoration(labelText: l.providerPreset),
                items: [
                  for (final p in _catalog.presets)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(p.id == 'custom' ? l.providerCustom : p.label),
                    ),
                ],
                onChanged: widget.provider == null && !_busy ? (v) => _choosePreset(v!) : null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _label,
                decoration: InputDecoration(labelText: l.providerName),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                decoration: InputDecoration(labelText: l.providerBaseUrl, hintText: 'https://…/v1'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('provider-model'),
                controller: _model,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l.providerModel,
                  // Catalog models with prices, then any extra ids the server
                  // listed after "Test connection".
                  suffixIcon: listed.isEmpty && serverOnly.isEmpty
                      ? null
                      : PopupMenuButton<String>(
                          tooltip: l.providerModelPick,
                          icon: const Icon(Icons.arrow_drop_down),
                          onSelected: (v) => setState(() => _model.text = v),
                          itemBuilder: (_) => [
                            for (final m in listed)
                              PopupMenuItem(
                                value: m.id,
                                child: Row(
                                  children: [
                                    Expanded(child: Text(m.id, overflow: TextOverflow.ellipsis)),
                                    const SizedBox(width: 12),
                                    Text(
                                      _price(m),
                                      style: TextStyle(color: context.sl.muted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            if (listed.isNotEmpty && serverOnly.isNotEmpty)
                              const PopupMenuDivider(),
                            for (final m in serverOnly.take(200))
                              PopupMenuItem(value: m, child: Text(m)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                info == null
                    ? (local ? l.providerModelLocal : l.providerModelUnlisted)
                    : [
                        if (info.context != null) l.providerModelContext(_tokens(info.context!)),
                        if (info.priced)
                          l.providerModelPrice(_usd(info.inputPerMTok!), _usd(info.outputPerMTok!)),
                      ].join(' · '),
                style: TextStyle(color: context.sl.muted, fontSize: 12),
              ),
              if (_preset == 'litellm') ...[
                const SizedBox(height: 10),
                SlNotice(l.providerLitellmHint),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _key,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: preset.needsKey ? l.providerApiKey : l.providerApiKeyOptional,
                  helperText: widget.provider?.hasKey == true
                      ? l.providerKeyKeep
                      : l.providerKeyKeychain,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _testConnection,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check),
                    label: Text(l.providerTest),
                  ),
                  const SizedBox(width: 10),
                  local
                      ? SlBadge(l.providerLocal, icon: Icons.computer_outlined)
                      : SlBadge.cloud(l.providerCloud),
                ],
              ),
              if (_test != null) ...[const SizedBox(height: 10), SlNotice(_test!, error: !_testOk)],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
        FilledButton(
          key: const ValueKey('provider-save'),
          onPressed: _busy ? null : _save,
          child: Text(l.save),
        ),
      ],
    );
  }
}
