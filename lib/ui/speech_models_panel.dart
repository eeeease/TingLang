import 'package:flutter/material.dart';
import 'package:tinglang_native/tinglang_native.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import '../l10n/app_localizations.dart';
import '../services/app_controller.dart';
import '../services/speech_model_service.dart';
import 'brand.dart';
import 'cloud_speech_panel.dart';
import 'speech_model_names.dart';

/// Settings → Speech recognition: models on this Mac or a cloud API. Local:
/// the latency tier, the recommended models for live captions and for files
/// (accuracy, speed, CPU, size), downloads with consent and progress,
/// deletion, accents and dictation hints. Cloud: [CloudSpeechPanel]. Until
/// the user has chosen either, a card asks first.
class SpeechModelsPanel extends StatefulWidget {
  const SpeechModelsPanel({super.key, required this.app, required this.models, this.openUrl});
  final AppController app;
  final SpeechModelService models;
  final Future<void> Function(Uri url)? openUrl;

  @override
  State<SpeechModelsPanel> createState() => _SpeechModelsPanelState();
}

class _SpeechModelsPanelState extends State<SpeechModelsPanel> {
  late final Listenable _changes = Listenable.merge([widget.app, widget.models]);

  @override
  void initState() {
    super.initState();
    widget.models.refresh();
  }

  SpeechModelService get _models => widget.models;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListenableBuilder(
      listenable: _changes,
      builder: (context, _) {
        final cloud = _models.mode == RecognitionMode.cloud;
        final hasCloud = _models.cloudProviders.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_models.setupChosen && hasCloud) ...[
              _chooser(context),
              const SizedBox(height: SlSpace.lg),
            ],
            SlPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasCloud) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.speechMode,
                            style: SlType.body.copyWith(color: context.sl.text),
                          ),
                        ),
                        SegmentedButton<RecognitionMode>(
                          key: const ValueKey('speech-mode'),
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: RecognitionMode.local,
                              icon: const Icon(Icons.computer_outlined, size: 16),
                              label: Text(l.speechModeLocal),
                            ),
                            ButtonSegment(
                              value: RecognitionMode.cloud,
                              icon: const Icon(Icons.cloud_outlined, size: 16),
                              label: Text(l.speechModeCloud),
                            ),
                          ],
                          selected: {_models.mode},
                          onSelectionChanged: (value) =>
                              reportAction(context, () => _models.setMode(value.single)),
                        ),
                      ],
                    ),
                    const SizedBox(height: SlSpace.lg),
                  ],
                  if (cloud)
                    CloudSpeechPanel(models: _models, openUrl: widget.openUrl)
                  else
                    ..._local(context),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// First start: local models or a cloud API.
  Widget _chooser(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    Widget option(RecognitionMode mode, IconData icon, String title, String body) => Expanded(
      child: OutlinedButton(
        key: ValueKey('speech-choose-${mode.name}'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(SlSpace.lg),
          alignment: Alignment.topLeft,
        ),
        onPressed: () => reportAction(context, () => _models.setMode(mode)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: c.accentInk),
            const SizedBox(height: SlSpace.sm),
            Text(
              title,
              style: SlType.body.copyWith(color: c.text, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: SlSpace.xxs),
            Text(body, style: SlType.caption.copyWith(color: c.muted)),
          ],
        ),
      ),
    );
    return SlPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.speechChooseTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: SlSpace.lg),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                option(
                  RecognitionMode.local,
                  Icons.computer_outlined,
                  l.speechChooseLocal,
                  l.speechChooseLocalBody,
                ),
                const SizedBox(width: SlSpace.md),
                option(
                  RecognitionMode.cloud,
                  Icons.cloud_outlined,
                  l.speechChooseCloud,
                  l.speechChooseCloudBody,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _local(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    final tier =
        LatencyTier.values.asNameMap()[widget.app.setting(SpeechKeys.latency, '')] ??
        LatencyTier.balanced;
    final appleChosen = SpeechUse.values.any((use) {
      final id = _models.localModelFor(use);
      return id == null
          ? _autoModel(use)?.isApple ?? false
          : SpeechModels.byId(id)?.isApple ?? false;
    });
    final dictationChosen = SpeechUse.values.any(
      (use) => _models.localModelFor(use) == SpeechModels.appleDictation.id,
    );
    return [
      Text(l.speechLatency, style: SlType.label.copyWith(color: c.text)),
      const SizedBox(height: SlSpace.sm),
      SegmentedButton<LatencyTier>(
        key: const ValueKey('speech-latency'),
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: LatencyTier.powerSaver, label: Text(l.latencyPowerSaver)),
          ButtonSegment(value: LatencyTier.balanced, label: Text(l.latencyBalanced)),
          ButtonSegment(value: LatencyTier.fastest, label: Text(l.latencyFastest)),
        ],
        selected: {tier},
        onSelectionChanged: (value) => reportAction(
          context,
          () => widget.app.setSetting(SpeechKeys.latency, value.single.name),
        ),
      ),
      const SizedBox(height: SlSpace.xs),
      Text(switch (tier) {
        LatencyTier.powerSaver => l.latencyPowerSaverHelp,
        LatencyTier.balanced => l.latencyBalancedHelp,
        LatencyTier.fastest => l.latencyFastestHelp,
      }, style: SlType.caption.copyWith(color: c.muted)),
      const SizedBox(height: SlSpace.xl),
      _useSection(context, SpeechUse.live, l.speechForLive),
      const SizedBox(height: SlSpace.lg),
      _useSection(context, SpeechUse.file, l.speechForFiles),
      if (appleChosen && _models.appleAssets != null) ...[
        const SizedBox(height: SlSpace.lg),
        _accents(context, dictation: dictationChosen),
      ],
      if (dictationChosen) ...[
        _switch(context, l.speechFarField, SpeechKeys.farField),
        _switch(context, l.speechShortForm, SpeechKeys.shortForm),
      ],
    ];
  }

  /// What "automatic" resolves to right now.
  SpeechModel? _autoModel(SpeechUse use) {
    final probe = _models.probe;
    if (probe == null || !TinglangPlatform.isInstalled) return null;
    final platform = TinglangPlatform.instance;
    final choice = (use == SpeechUse.live ? platform.liveAsr : platform.fileAsr).pick(probe);
    final id = choice.id;
    return id == null ? null : SpeechModels.all.where((m) => m.backendId(use) == id).firstOrNull;
  }

  Widget _useSection(BuildContext context, SpeechUse use, String title) {
    final l = context.l10n;
    final c = context.sl;
    final chosen = _models.localModelFor(use);
    final auto = _autoModel(use);
    final models = [
      for (final model in SpeechModels.forUse(use))
        // Hide what can never run on this OS family (e.g. Apple on Windows).
        if (_models.availability(model, use) is! Unsupported ||
            model.minMacos != null ||
            model.isSherpa)
          model,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: SlType.label.copyWith(color: c.text)),
        const SizedBox(height: SlSpace.xs),
        RadioGroup<String>(
          groupValue: chosen ?? SpeechKeys.auto,
          onChanged: (value) => reportAction(
            context,
            () => _models.choose(use, value == SpeechKeys.auto ? null : value),
          ),
          child: Column(
            children: [
              _row(
                context,
                key: ValueKey('speech-${use.name}-auto'),
                value: SpeechKeys.auto,
                enabled: true,
                title: auto == null
                    ? l.speechAuto
                    : '${l.speechAuto} · ${speechModelName(l, auto) ?? auto.id}',
              ),
              for (final model in models) _modelRow(context, model, use),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required Key key,
    required String value,
    required bool enabled,
    required String title,
    Widget? subtitle,
    Widget? trailing,
  }) {
    final c = context.sl;
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: SlSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Radio<String>(value: value, enabled: enabled),
          const SizedBox(width: SlSpace.xs),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: SlSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SlType.body.copyWith(
                      color: enabled ? c.text : c.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[const SizedBox(height: SlSpace.xxs), subtitle],
                ],
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: SlSpace.md), trailing],
        ],
      ),
    );
  }

  Widget _modelRow(BuildContext context, SpeechModel model, SpeechUse use) {
    final l = context.l10n;
    final c = context.sl;
    final availability = _models.availability(model, use);
    final unsupported = availability is Unsupported;
    final installed = model.isApple || _models.isInstalled(model);
    final download = _models.downloads[model.id];
    final name = speechModelName(l, model) ?? model.id;
    String dots(int n) => '●' * n + '○' * (3 - n);
    // Three ratings and the size, nothing else (the download dialog names
    // the source and licence).
    final facts = [
      '${l.speechAccuracy} ${dots(model.ratings.accuracy)}',
      '${l.speechSpeed} ${dots(model.ratings.speed)}',
      l.speechCpuLevel(cpuLevel(l, model.ratings.cpuPercent)),
      model.isApple ? l.speechSystemAsset : formatBytes(l, model.diskBytes),
    ].join('  ·  ');
    final Widget? trailing;
    if (unsupported) {
      trailing = SlBadge(l.speechNeedsMacos('${model.minMacos?.major ?? ''}'));
    } else if (download != null) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 96, child: LinearProgressIndicator(value: download.fraction)),
          const SizedBox(width: SlSpace.sm),
          Text(
            l.speechDownloading('${(download.fraction * 100).round()}'),
            style: SlType.caption.copyWith(color: c.muted),
          ),
          TextButton(
            onPressed: () => reportAction(context, () => _models.cancelDownload(model)),
            child: Text(l.speechCancel),
          ),
        ],
      );
    } else if (model.isSherpa && !installed) {
      trailing = FilledButton.tonal(
        key: ValueKey('speech-download-${model.id}'),
        onPressed: () => _confirmDownload(context, model),
        child: Text(l.speechDownload(formatBytes(l, _models.missingBytes(model)))),
      );
    } else if (model.isSherpa && _models.hasOwnPack(model)) {
      trailing = TextButton(
        key: ValueKey('speech-delete-${model.id}'),
        onPressed: () => _confirmDelete(context, model),
        child: Text(l.speechDelete),
      );
    } else {
      trailing = null;
    }
    return _row(
      context,
      key: ValueKey('speech-${use.name}-${model.id}'),
      value: model.id,
      enabled: !unsupported,
      title: name,
      trailing: trailing,
      subtitle: Text(facts, style: SlType.caption.copyWith(color: c.muted)),
    );
  }

  Future<void> _confirmDownload(BuildContext context, SpeechModel model) async {
    final l = context.l10n;
    final name = speechModelName(l, model) ?? model.id;
    final pack = model.pack!;
    final host = Uri.parse(pack.archive?.url ?? pack.files.first.url).host;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.speechDownloadTitle(name)),
        content: Text(
          l.speechDownloadBody(
            formatBytes(l, _models.missingBytes(model)),
            host,
            [model.license?.name, model.license?.attribution].whereType<String>().join(' — '),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.speechCancel)),
          FilledButton(
            key: const ValueKey('speech-download-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.speechDownload(formatBytes(l, _models.missingBytes(model)))),
          ),
        ],
      ),
    );
    if (agreed != true || !context.mounted) return;
    await reportAction(context, () async {
      try {
        await _models.download(model);
      } on DownloadCancelled {
        return;
      } on ChecksumMismatch {
        throw StateError(l.speechChecksumFailed);
      }
    });
  }

  Future<void> _confirmDelete(BuildContext context, SpeechModel model) async {
    final l = context.l10n;
    final name = speechModelName(l, model) ?? model.id;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.speechDeleteTitle(name)),
        content: Text(l.speechDeleteBody(formatBytes(l, model.pack!.bytes))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.speechCancel)),
          FilledButton(
            key: const ValueKey('speech-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.speechDelete),
          ),
        ],
      ),
    );
    if (agreed == true && context.mounted) {
      await reportAction(context, () => _models.delete(model));
    }
  }

  Widget _accents(BuildContext context, {required bool dictation}) {
    final l = context.l10n;
    final c = context.sl;
    final current = widget.app.setting(SpeechKeys.accent, 'en-US');
    final engine = dictation ? SpeechEngine.appleDictation : SpeechEngine.appleSpeech;
    final supported =
        (dictation ? _models.locales?.dictationSupported : _models.locales?.speechSupported) ??
        englishAccents.toSet();
    final accents = [
      for (final a in englishAccents)
        if (supported.contains(a)) a,
    ];
    final installed = _models.appleInstalled(current, engine);
    final installing = _models.appleInstalls[SpeechModelService.appleKey(current, engine)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l.speechAccent, style: SlType.body.copyWith(color: c.text)),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                key: ValueKey('speech-accent-$current'),
                initialValue: accents.contains(current) ? current : 'en-US',
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: [
                  for (final a in accents)
                    DropdownMenuItem(
                      value: a,
                      child: Text('${_accentName(l, a)} ($a)', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    reportAction(context, () => widget.app.setSetting(SpeechKeys.accent, value));
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: SlSpace.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                installed ? l.speechInstalled : '',
                style: SlType.caption.copyWith(color: c.muted),
              ),
            ),
            if (installing != null) ...[
              SizedBox(width: 96, child: LinearProgressIndicator(value: installing)),
              TextButton(
                onPressed: () => reportAction(context, () => _models.cancelApple(current, engine)),
                child: Text(l.speechCancel),
              ),
            ] else if (!installed)
              FilledButton.tonal(
                key: const ValueKey('speech-accent-download'),
                onPressed: () => reportAction(context, () async {
                  try {
                    await _models.installApple(current, engine);
                  } on Object catch (e) {
                    if (!'$e'.contains('Cancel')) rethrow;
                  }
                }),
                child: Text(l.speechAccentDownload),
              )
            else if (current != 'en-US')
              TextButton(
                onPressed: () => reportAction(context, () => _models.releaseApple(current, engine)),
                child: Text(l.speechAccentRemove),
              ),
          ],
        ),
      ],
    );
  }

  static String _accentName(AppLocalizations l, String locale) => switch (locale) {
    'en-US' => l.accentUS,
    'en-GB' => l.accentGB,
    'en-AU' => l.accentAU,
    'en-IN' => l.accentIN,
    'en-CA' => l.accentCA,
    'en-IE' => l.accentIE,
    'en-NZ' => l.accentNZ,
    'en-SG' => l.accentSG,
    'en-ZA' => l.accentZA,
    _ => locale,
  };

  Widget _switch(BuildContext context, String label, String key) {
    final c = context.sl;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: SlType.body.copyWith(color: c.text)),
      value: widget.app.setting(key, 'false') == 'true',
      onChanged: (value) => reportAction(context, () => widget.app.setSetting(key, '$value')),
    );
  }
}
