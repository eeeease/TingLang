import 'package:flutter/material.dart';
import 'package:tinglang_native/tinglang_native.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import '../services/speech_model_service.dart';
import 'brand.dart';
import 'errors.dart';
import 'speech_model_names.dart';

/// Settings → Speech recognition → Cloud API: the service, its credentials
/// (kept in the Keychain; secrets are never shown again), where audio goes,
/// "Test connection" and a link to the service's console.
class CloudSpeechPanel extends StatefulWidget {
  const CloudSpeechPanel({super.key, required this.models, this.openUrl});
  final SpeechModelService models;
  final Future<void> Function(Uri url)? openUrl;

  @override
  State<CloudSpeechPanel> createState() => _CloudSpeechPanelState();
}

class _CloudSpeechPanelState extends State<CloudSpeechPanel> {
  final _text = <String, TextEditingController>{};
  final _choice = <String, String>{};

  /// What is saved for the shown service (secrets are not put in fields).
  CloudCredentials _saved = const {};
  String? _loadedFor;
  bool _busy = false;
  String? _status;
  bool _statusOk = false;

  SpeechModelService get _models => widget.models;

  CloudAsrProvider? get _provider => _models.cloudProvider ?? _models.cloudProviders.firstOrNull;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final provider = _provider;
    if (provider == null) return;
    final id = provider.info.id;
    _loadedFor = id;
    final saved = await _models.cloudCredentials(id) ?? const {};
    if (!mounted || _loadedFor != id) return;
    setState(() {
      _saved = saved;
      _status = null;
      for (final c in _text.values) {
        c.dispose();
      }
      _text.clear();
      _choice.clear();
      for (final field in provider.info.fields) {
        final value = saved[field.key] ?? field.defaultValue ?? '';
        switch (field.kind) {
          case CloudFieldKind.choice:
            _choice[field.key] = field.choices.contains(value)
                ? value
                : field.defaultValue ?? field.choices.first;
          case CloudFieldKind.text:
            _text[field.key] = TextEditingController(text: value);
          case CloudFieldKind.secret:
            // Saved secrets stay in the Keychain; empty keeps them.
            _text[field.key] = TextEditingController();
        }
      }
    });
  }

  /// The values to use: what is typed, else what is saved.
  CloudCredentials? _values(CloudAsrInfo info) {
    final l = context.l10n;
    final out = <String, String>{};
    for (final field in info.fields) {
      final value = switch (field.kind) {
        CloudFieldKind.choice => _choice[field.key] ?? '',
        _ => _text[field.key]?.text.trim() ?? '',
      };
      final effective = value.isEmpty ? _saved[field.key] ?? '' : value;
      if (effective.isEmpty && !field.optional) {
        setState(() {
          _status = l.cloudSpeechFieldRequired(cloudFieldLabel(l, field.key));
          _statusOk = false;
        });
        return null;
      }
      if (effective.isNotEmpty) out[field.key] = effective;
    }
    return out;
  }

  Future<void> _run(Future<void> Function(CloudCredentials values) action, String ok) async {
    final provider = _provider;
    if (provider == null) return;
    final values = _values(provider.info);
    if (values == null) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await action(values);
      if (mounted) {
        setState(() {
          _status = ok;
          _statusOk = true;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _status = describeError(context.l10n, e);
          _statusOk = false;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() {
    final id = _provider!.info.id;
    return _run((values) async {
      await _models.saveCloudCredentials(id, values);
      if (_models.cloudProvider?.info.id != id) await _models.chooseCloudProvider(id);
      _saved = values;
      for (final field in _provider!.info.fields) {
        if (field.kind == CloudFieldKind.secret) _text[field.key]?.clear();
      }
    }, context.l10n.cloudSpeechSaved);
  }

  Future<void> _forget() async {
    final l = context.l10n;
    final provider = _provider!;
    final name = cloudServiceName(l, provider.info.id);
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.cloudSpeechForgetTitle(name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(
            key: const ValueKey('cloud-forget-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.cloudSpeechForget),
          ),
        ],
      ),
    );
    if (agreed != true || !mounted) return;
    await reportAction(context, () => _models.forgetCloudCredentials(provider.info.id));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    final provider = _provider;
    if (provider == null) return const SizedBox.shrink();
    if (_loadedFor != provider.info.id) _load();
    final info = provider.info;
    final name = cloudServiceName(l, info.id);
    final saved = _models.savedCloud.contains(info.id);
    final hosts = provider.hosts({
      ..._saved,
      for (final f in info.fields)
        if (f.kind == CloudFieldKind.text && (_text[f.key]?.text.trim() ?? '').isNotEmpty)
          f.key: _text[f.key]!.text.trim(),
      ..._choice,
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l.cloudSpeechService, style: SlType.body.copyWith(color: c.text)),
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                key: ValueKey('cloud-service-${info.id}'),
                initialValue: info.id,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: [
                  // TingLang's own API is not open yet.
                  DropdownMenuItem(
                    value: '',
                    enabled: false,
                    child: Text(
                      l.cloudOfficialSoon,
                      overflow: TextOverflow.ellipsis,
                      style: SlType.body.copyWith(color: c.muted),
                    ),
                  ),
                  for (final p in _models.cloudProviders)
                    DropdownMenuItem(
                      value: p.info.id,
                      child: Text(cloudServiceName(l, p.info.id), overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (id) {
                        if (id == null || id.isEmpty || id == info.id) return;
                        reportAction(context, () async {
                          await _models.chooseCloudProvider(id);
                          await _load();
                        });
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: SlSpace.sm),
        Row(
          children: [
            SlBadge.cloud(l.providerCloud),
            const SizedBox(width: SlSpace.sm),
            Expanded(
              child: Text(
                l.cloudSpeechSendsTo(hosts.join(', ')),
                style: SlType.caption.copyWith(color: c.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: SlSpace.md),
        for (final field in info.fields)
          Padding(
            padding: const EdgeInsets.only(bottom: SlSpace.sm),
            child: switch (field.kind) {
              CloudFieldKind.choice => DropdownButtonFormField<String>(
                key: ValueKey('cloud-field-${info.id}-${field.key}'),
                initialValue: _choice[field.key] ?? field.defaultValue ?? field.choices.first,
                isExpanded: true,
                decoration: InputDecoration(labelText: cloudFieldLabel(l, field.key)),
                items: [
                  for (final id in field.choices)
                    DropdownMenuItem(value: id, child: Text(cloudRegionLabel(l, id))),
                ],
                onChanged: (v) => setState(() => _choice[field.key] = v ?? ''),
              ),
              _ => TextField(
                key: ValueKey('cloud-field-${info.id}-${field.key}'),
                controller: _text[field.key],
                obscureText: field.kind == CloudFieldKind.secret,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: cloudFieldLabel(l, field.key),
                  hintText: field.key == CloudFieldKeys.region ? l.cloudRegionExample : null,
                  helperText: field.kind == CloudFieldKind.secret && _saved[field.key] != null
                      ? l.providerKeyKeep
                      : null,
                ),
              ),
            },
          ),
        if (!info.live) _note(context, l.cloudSpeechNoLive(name)),
        if (!info.file) _note(context, l.cloudSpeechNoFile(name)),
        const SizedBox(height: SlSpace.sm),
        Wrap(
          spacing: SlSpace.sm,
          runSpacing: SlSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              key: const ValueKey('cloud-save'),
              onPressed: _busy ? null : _save,
              child: Text(l.save),
            ),
            OutlinedButton.icon(
              key: const ValueKey('cloud-test'),
              onPressed: _busy
                  ? null
                  : () =>
                        _run((values) => _models.verifyCloud(info.id, values), l.cloudSpeechTestOk),
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.network_check, size: 18),
              label: Text(l.providerTest),
            ),
            if (widget.openUrl != null)
              TextButton.icon(
                onPressed: () => reportAction(context, () => widget.openUrl!(info.consoleUrl)),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(l.cloudSpeechGetKey),
              ),
            if (saved)
              TextButton(
                key: const ValueKey('cloud-forget'),
                onPressed: _busy ? null : _forget,
                child: Text(l.cloudSpeechForget),
              ),
          ],
        ),
        if (_status != null) ...[
          const SizedBox(height: SlSpace.sm),
          SlNotice(_status!, error: !_statusOk),
        ],
      ],
    );
  }

  Widget _note(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: SlSpace.sm),
    child: Text(text, style: SlType.caption.copyWith(color: context.sl.muted)),
  );
}
