import 'package:flutter/material.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import '../services/app_controller.dart';
import '../services/live_controller.dart';
import '../services/panel_settings.dart';
import 'brand.dart';
import 'settings_page.dart' show learningLanguages;

/// Before the first live captions: the language to recognise and the one to
/// translate into (or none). A translation pack macOS still needs is
/// downloaded here, so starting captions never asks for it. True when the
/// user chose and captions may start.
Future<bool> showLanguageSetup(
  BuildContext context, {
  required AppController app,
  required LiveController live,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LanguageSetupDialog(app: app, live: live),
    ) ??
    false;

class LanguageSetupDialog extends StatefulWidget {
  const LanguageSetupDialog({super.key, required this.app, required this.live});
  final AppController app;
  final LiveController live;

  @override
  State<LanguageSetupDialog> createState() => _LanguageSetupDialogState();
}

class _LanguageSetupDialogState extends State<LanguageSetupDialog> {
  static const _off = 'off';
  late String _language = widget.app.setting(AppController.learningLanguageKey, 'en');
  late String _target = widget.app.setting(liveTranslateKey, 'true') == 'false'
      ? _off
      : widget.app.setting(AppController.nativeLanguageKey, 'zh-Hans');
  bool _working = false;

  Future<void> _start() async {
    setState(() => _working = true);
    final translate = _target != _off && _target != _language;
    await widget.app.setSettings({
      AppController.learningLanguageKey: _language,
      if (translate) AppController.nativeLanguageKey: _target,
      liveTranslateKey: '$translate',
      languagesChosenKey: 'true',
    });
    if (translate) {
      try {
        // macOS shows its own download sheet; captions start either way.
        if (await widget.live.translationPackMissing(_language, _target)) {
          await widget.live.installTranslationPack(_language, _target);
        }
      } on Object catch (e) {
        debugPrint('Translation pack not installed: $e');
      }
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    Widget picker(
      String label,
      String value,
      Map<String, String> options,
      Key key,
      ValueChanged<String> onChanged,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: SlSpace.lg),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: SlType.body.copyWith(color: c.text)),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              key: key,
              initialValue: options.containsKey(value) ? value : options.keys.first,
              isDense: true,
              isExpanded: true,
              items: [
                for (final e in options.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: _working ? null : (v) => v == null ? null : onChanged(v),
            ),
          ),
        ],
      ),
    );
    return AlertDialog(
      key: const ValueKey('language-setup'),
      title: Text(l.languageSetupTitle),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.languageSetupBody, style: SlType.body.copyWith(color: c.inkSoft)),
            const SizedBox(height: SlSpace.xl),
            picker(
              l.languageSetupRecognise,
              _language,
              learningLanguages,
              const ValueKey('language-setup-recognise'),
              (v) => setState(() => _language = v),
            ),
            picker(
              l.languageSetupTranslate,
              _target,
              {_off: l.panelTranslateOff, ...learningLanguages},
              const ValueKey('language-setup-translate'),
              (v) => setState(() => _target = v),
            ),
            Text(l.languageSetupLater, style: SlType.caption.copyWith(color: c.muted)),
            if (_working) ...[
              const SizedBox(height: SlSpace.lg),
              const LinearProgressIndicator(minHeight: 3),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _working ? null : () => Navigator.pop(context, false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('language-setup-start'),
          onPressed: _working ? null : _start,
          child: Text(l.languageSetupStart),
        ),
      ],
    );
  }
}
