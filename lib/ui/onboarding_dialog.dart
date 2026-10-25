import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tinglang_native/tinglang_native.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import '../services/app_controller.dart';
import '../services/speech_model_service.dart';
import 'brand.dart';
import 'speech_model_names.dart';
import 'speech_models_panel.dart' show confirmSpeechDownload;

/// What the first-start guide may do with the system's permissions; each
/// part is null where there is no such thing (tests, other systems).
class PermissionAccess {
  const PermissionAccess({this.probe, this.requestMicrophone, this.openSettings});

  /// Reads the permission states again (when the guide opens and whenever
  /// the app comes back to the front, e.g. from System Settings).
  final Future<PlatformProbe?> Function()? probe;

  /// Shows macOS's microphone question, which it asks only once; true when
  /// allowed.
  final Future<bool> Function()? requestMicrophone;
  final Future<void> Function(SystemSettingsPane pane)? openSettings;
}

/// How the guide was left.
enum OnboardingOutcome {
  finished,
  skipped,

  /// Finished with the cloud chosen and no key saved yet: Settings → Speech
  /// recognition should open next.
  setUpCloud,
}

/// Shows the first-start guide (permissions, the speech model, how to use
/// the panel). However it closes, [AppController.onboardingKey] becomes
/// [AppController.onboardingDone], so it opens by itself only once.
Future<OnboardingOutcome> showOnboarding(
  BuildContext context, {
  required AppController app,
  SpeechModelService? models,
  PermissionAccess access = const PermissionAccess(),
}) async {
  final outcome = await showDialog<OnboardingOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (_) => OnboardingDialog(models: models, access: access),
  );
  await app.setSetting(AppController.onboardingKey, AppController.onboardingDone);
  return outcome ?? OnboardingOutcome.skipped;
}

enum _Step { permissions, model, usage }

class OnboardingDialog extends StatefulWidget {
  const OnboardingDialog({super.key, this.models, this.access = const PermissionAccess()});

  /// Speech models; without them the model step only explains.
  final SpeechModelService? models;
  final PermissionAccess access;

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog> {
  var _step = _Step.permissions;
  PlatformProbe? _probe;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Back from System Settings: read the permissions again.
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_refresh()));
    unawaited(_refresh());
    unawaited(widget.models?.refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final probe = await widget.access.probe?.call();
    if (mounted) setState(() => _probe = probe);
  }

  void _finish() {
    final models = widget.models;
    final cloud = models != null && models.mode == RecognitionMode.cloud && models.cloudNeedsSetup;
    Navigator.pop(context, cloud ? OnboardingOutcome.setUpCloud : OnboardingOutcome.finished);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    const steps = _Step.values;
    final index = steps.indexOf(_step);
    final last = index == steps.length - 1;
    String label(_Step step) => switch (step) {
      _Step.permissions => l.onboardingStepPermissions,
      _Step.model => l.onboardingStepModel,
      _Step.usage => l.onboardingStepUsage,
    };
    return Dialog(
      key: const ValueKey('onboarding'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(SlSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const BrandMark(size: 36),
                  const SizedBox(width: SlSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.onboardingWelcome,
                          style: SlType.title.copyWith(color: c.text, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          l.onboardingStepOf('${index + 1}', '${steps.length}'),
                          style: SlType.caption.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SlSpace.lg),
              Row(
                children: [
                  for (final (i, step) in steps.indexed) ...[
                    if (i > 0) const SizedBox(width: SlSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: i <= index ? c.accent : c.line,
                              borderRadius: SlRadius.all(SlRadius.pill),
                            ),
                          ),
                          const SizedBox(height: SlSpace.xs),
                          Text(
                            label(step),
                            style: SlType.caption.copyWith(
                              color: i == index ? c.text : c.muted,
                              fontWeight: i == index ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: SlSpace.xl),
              Flexible(
                child: SingleChildScrollView(
                  child: switch (_step) {
                    _Step.permissions => _permissions(context),
                    _Step.model => _model(context),
                    _Step.usage => _usage(context),
                  },
                ),
              ),
              const SizedBox(height: SlSpace.xl),
              Row(
                children: [
                  if (!last)
                    TextButton(
                      key: const ValueKey('onboarding-skip'),
                      onPressed: () => Navigator.pop(context, OnboardingOutcome.skipped),
                      child: Text(l.onboardingSkip),
                    ),
                  const Spacer(),
                  if (index > 0) ...[
                    TextButton(
                      key: const ValueKey('onboarding-back'),
                      onPressed: () => setState(() => _step = steps[index - 1]),
                      child: Text(l.onboardingBack),
                    ),
                    const SizedBox(width: SlSpace.sm),
                  ],
                  FilledButton(
                    key: const ValueKey('onboarding-next'),
                    onPressed: last ? _finish : () => setState(() => _step = steps[index + 1]),
                    child: Text(last ? l.onboardingDone : l.onboardingNext),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String title, String body) {
    final c = context.sl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: SlType.subtitle.copyWith(color: c.text)),
        const SizedBox(height: SlSpace.xs),
        Text(body, style: SlType.body.copyWith(color: c.inkSoft)),
        const SizedBox(height: SlSpace.lg),
      ],
    );
  }

  // Permissions ------------------------------------------------------------

  Widget _permissions(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    final probe = _probe;
    final microphone = probe?.permission(PermissionKind.microphone);
    // macOS only says whether screen recording is allowed, never "denied".
    final screen = probe?.permission(PermissionKind.screenCapture) == PermissionState.granted
        ? PermissionState.granted
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(context, l.onboardingPermissionsTitle, l.onboardingPermissionsBody),
        _PermissionRow(
          key: const ValueKey('permission-system-audio'),
          icon: Icons.graphic_eq_rounded,
          title: l.permissionSystemAudio,
          body: l.permissionSystemAudioBody,
          required: true,
          // There is no way to ask macOS about it before the first capture.
          status: Text(l.permissionAskedLater, style: SlType.caption.copyWith(color: c.muted)),
          action: _settingsButton(context, SystemSettingsPane.screenRecording),
        ),
        _PermissionRow(
          key: const ValueKey('permission-microphone'),
          icon: Icons.mic_none_rounded,
          title: l.permissionMicrophone,
          body: l.permissionMicrophoneBody,
          required: true,
          status: _status(context, microphone),
          action: switch (microphone) {
            PermissionState.granted => null,
            PermissionState.notDetermined ||
            null when widget.access.requestMicrophone != null => FilledButton.tonal(
              key: const ValueKey('permission-microphone-allow'),
              onPressed: () => reportAction(context, () async {
                await widget.access.requestMicrophone!();
                await _refresh();
              }),
              child: Text(l.permissionAllow),
            ),
            _ => _settingsButton(context, SystemSettingsPane.microphone),
          },
        ),
        _PermissionRow(
          key: const ValueKey('permission-screen'),
          icon: Icons.screenshot_monitor_outlined,
          title: l.permissionScreen,
          body: l.permissionScreenBody,
          status: _status(context, screen),
          action: screen == PermissionState.granted
              ? null
              : _settingsButton(context, SystemSettingsPane.screenRecording),
        ),
        _PermissionRow(
          key: const ValueKey('permission-full-disk'),
          icon: Icons.folder_open_outlined,
          title: l.permissionFullDisk,
          body: l.permissionFullDiskBody,
          action: _settingsButton(context, SystemSettingsPane.fullDiskAccess),
        ),
        const SizedBox(height: SlSpace.sm),
        Text(l.onboardingPermissionsReturn, style: SlType.caption.copyWith(color: c.muted)),
      ],
    );
  }

  Widget? _settingsButton(BuildContext context, SystemSettingsPane pane) {
    final open = widget.access.openSettings;
    if (open == null) return null;
    return OutlinedButton(
      key: ValueKey('permission-settings-${pane.name}'),
      onPressed: () => reportAction(context, () => open(pane)),
      child: Text(context.l10n.permissionOpenSettings),
    );
  }

  Widget? _status(BuildContext context, PermissionState? state) {
    final l = context.l10n;
    final c = context.sl;
    final (icon, text, color) = switch (state) {
      PermissionState.granted => (Icons.check_circle_rounded, l.permissionGranted, c.success),
      PermissionState.denied ||
      PermissionState.restricted => (Icons.block_rounded, l.permissionDenied, c.warning),
      PermissionState.notDetermined || null => (null, null, null),
    };
    if (text == null) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: SlSpace.xs),
        Text(
          text,
          style: SlType.caption.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // Speech model -----------------------------------------------------------

  Widget _model(BuildContext context) {
    final l = context.l10n;
    final heading = _heading(context, l.onboardingModelTitle, l.onboardingModelBody);
    final models = widget.models;
    if (models == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [heading, _note(context, l.onboardingModelMore)],
      );
    }
    return ListenableBuilder(
      listenable: Listenable.merge([models, models.app]),
      builder: (context, _) {
        final chosen = models.app.setting(SpeechKeys.mode, '').isNotEmpty;
        final cloud = chosen && models.mode == RecognitionMode.cloud;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading,
            if (models.cloudProviders.isNotEmpty) ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _modeOption(
                      context,
                      models,
                      RecognitionMode.local,
                      selected: chosen && !cloud,
                      icon: Icons.computer_outlined,
                      title: l.speechChooseLocal,
                      body: l.speechChooseLocalBody,
                      recommended: true,
                    ),
                    const SizedBox(width: SlSpace.md),
                    _modeOption(
                      context,
                      models,
                      RecognitionMode.cloud,
                      selected: cloud,
                      icon: Icons.cloud_outlined,
                      title: l.speechChooseCloud,
                      body: l.speechChooseCloudBody,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SlSpace.lg),
            ],
            if (cloud)
              _note(context, l.onboardingCloudNext)
            else ...[
              _recommended(context, models),
              const SizedBox(height: SlSpace.md),
              _note(context, l.onboardingModelMore),
            ],
          ],
        );
      },
    );
  }

  Widget _note(BuildContext context, String text) =>
      Text(text, style: SlType.caption.copyWith(color: context.sl.muted));

  Widget _modeOption(
    BuildContext context,
    SpeechModelService models,
    RecognitionMode mode, {
    required bool selected,
    required IconData icon,
    required String title,
    required String body,
    bool recommended = false,
  }) {
    final c = context.sl;
    return Expanded(
      child: OutlinedButton(
        key: ValueKey('onboarding-mode-${mode.name}'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(SlSpace.lg),
          alignment: Alignment.topLeft,
          backgroundColor: selected ? c.accentSoft : null,
          side: BorderSide(color: selected ? c.accent : c.line, width: selected ? 1.5 : 1),
          shape: RoundedRectangleBorder(borderRadius: SlRadius.all(SlRadius.md)),
        ),
        onPressed: () => reportAction(context, () => models.setMode(mode)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: c.accentInk),
                const Spacer(),
                if (recommended) SlBadge(context.l10n.onboardingRecommended),
              ],
            ),
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
  }

  /// The model "automatic" picks for live captions on this Mac, with what
  /// it still needs (a download from Apple or from the model's publisher).
  Widget _recommended(BuildContext context, SpeechModelService models) {
    final l = context.l10n;
    final c = context.sl;
    final model = models.automaticModel(SpeechUse.live);
    if (model == null) return _note(context, l.onboardingModelNone);
    // Pressing a download here is choosing the local mode.
    Future<void> chooseLocal() async {
      if (models.app.setting(SpeechKeys.mode, '').isEmpty) {
        await models.setMode(RecognitionMode.local);
      }
    }

    final Widget action;
    if (model.isApple) {
      final locale = models.optionsFor('en').locale ?? 'en-US';
      final engine = model.engine;
      final installing = models.appleInstalls[SpeechModelService.appleKey(locale, engine)];
      action = models.appleInstalled(locale, engine)
          ? _ready(context)
          : installing != null
          ? SizedBox(width: 120, child: LinearProgressIndicator(value: installing))
          : FilledButton.tonal(
              key: const ValueKey('onboarding-model-apple'),
              onPressed: () => reportAction(context, () async {
                await chooseLocal();
                try {
                  await models.installApple(locale, engine);
                } on Object catch (e) {
                  if (!'$e'.contains('Cancel')) rethrow;
                }
              }),
              child: Text(l.speechAccentDownload),
            );
    } else {
      final download = models.downloads[model.id];
      action = models.isInstalled(model)
          ? _ready(context)
          : download != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 96, child: LinearProgressIndicator(value: download.fraction)),
                const SizedBox(width: SlSpace.sm),
                Text(
                  l.speechDownloading('${(download.fraction * 100).round()}'),
                  style: SlType.caption.copyWith(color: c.muted),
                ),
                TextButton(
                  onPressed: () => reportAction(context, () => models.cancelDownload(model)),
                  child: Text(l.speechCancel),
                ),
              ],
            )
          : FilledButton.tonal(
              key: const ValueKey('onboarding-model-download'),
              onPressed: () async {
                await reportAction(context, chooseLocal);
                if (context.mounted) await confirmSpeechDownload(context, models, model);
              },
              child: Text(l.speechDownload(formatBytes(l, models.missingBytes(model)))),
            );
    }
    return Container(
      key: const ValueKey('onboarding-model'),
      padding: const EdgeInsets.all(SlSpace.lg),
      decoration: BoxDecoration(
        color: c.raised,
        border: Border.all(color: c.line),
        borderRadius: SlRadius.all(SlRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.onboardingModelForMac, style: SlType.caption.copyWith(color: c.muted)),
                const SizedBox(height: SlSpace.xxs),
                Text(
                  speechModelName(l, model) ?? model.id,
                  style: SlType.body.copyWith(color: c.text, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: SlSpace.xxs),
                Text(speechModelFacts(l, model), style: SlType.caption.copyWith(color: c.muted)),
              ],
            ),
          ),
          const SizedBox(width: SlSpace.md),
          action,
        ],
      ),
    );
  }

  Widget _ready(BuildContext context) {
    final c = context.sl;
    return Row(
      key: const ValueKey('onboarding-model-ready'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_rounded, size: 16, color: c.success),
        const SizedBox(width: SlSpace.xs),
        Text(
          context.l10n.onboardingModelReady,
          style: SlType.caption.copyWith(color: c.success, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // How to use -------------------------------------------------------------

  Widget _usage(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    final items = [
      (Icons.mic_rounded, l.onboardingUseStartTitle, l.onboardingUseStartBody),
      (Icons.open_with_rounded, l.onboardingUsePanelTitle, l.onboardingUsePanelBody),
      (Icons.subtitles_outlined, l.onboardingUseHistoryTitle, l.onboardingUseHistoryBody),
      (Icons.upload_file_outlined, l.onboardingUseFilesTitle, l.onboardingUseFilesBody),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.onboardingUsageTitle, style: SlType.subtitle.copyWith(color: c.text)),
        const SizedBox(height: SlSpace.lg),
        for (final (icon, title, body) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: SlSpace.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
                  child: Icon(icon, size: 18, color: c.accentInk),
                ),
                const SizedBox(width: SlSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: SlType.body.copyWith(color: c.text, fontWeight: FontWeight.w600),
                      ),
                      Text(body, style: SlType.body.copyWith(color: c.inkSoft)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        _note(context, l.onboardingReopen),
      ],
    );
  }
}

/// One permission: what it is for, whether it is required, its state and
/// what to do about it.
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.required = false,
    this.status,
    this.action,
  });
  final IconData icon;
  final String title, body;
  final bool required;
  final Widget? status, action;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    return Padding(
      padding: const EdgeInsets.only(bottom: SlSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: c.accentInk),
          ),
          const SizedBox(width: SlSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: SlSpace.sm,
                  runSpacing: SlSpace.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: SlType.body.copyWith(color: c.text, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      required ? l.permissionRequired : l.permissionOptional,
                      style: SlType.caption.copyWith(color: required ? c.accentInk : c.muted),
                    ),
                    ?status,
                  ],
                ),
                const SizedBox(height: SlSpace.xxs),
                Text(body, style: SlType.caption.copyWith(color: c.inkSoft)),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: SlSpace.md), action!],
        ],
      ),
    );
  }
}
