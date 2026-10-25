import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tinglang_native/tinglang_native.dart' show CaptionLayout, CaptionStyle;
import 'package:tinglang_ui/tinglang_ui.dart';

import '../app.dart' show appVersion;
import '../core/providers/provider_repository.dart';
import '../services/app_controller.dart';
import '../services/panel_settings.dart';
import '../services/speech_model_service.dart';
import 'brand.dart';
import 'file_picking.dart';
import 'providers_panel.dart';
import 'speech_models_panel.dart';

/// Languages offered for learning / translation, shown by their own names
/// so they need no translation.
const learningLanguages = {
  'en': 'English',
  'zh-Hans': '简体中文',
  'ja': '日本語',
  'ko': '한국어',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
};

/// The tabs of Settings, one kind of setting each.
enum SettingsTab {
  /// Interface and learning languages, appearance.
  general,

  /// The floating panel and what live captions keep.
  captions,

  /// Local models or a cloud API, downloads, latency, accents.
  speech,

  /// AI services for AI courses.
  ai,

  /// The data folder, exports (and iCloud Drive sync).
  data,
  about,
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.app,
    this.tab = SettingsTab.general,
    this.onTab,
    this.providers,
    this.onResetPanel,
    this.openUrl,
    this.speechModels,
    this.sync,
    this.updates,
  });
  final AppController app;
  final SettingsTab tab;
  final ValueChanged<SettingsTab>? onTab;

  /// Speech models and downloads; null where the app has none (tests).
  final SpeechModelService? speechModels;
  final ProviderRepository? providers;

  /// Opens a website page in the default browser.
  final Future<void> Function(Uri url)? openUrl;

  /// Moves the floating panel back to its default place.
  final Future<void> Function()? onResetPanel;

  /// iCloud Drive sync, shown first under Sync & data.
  final Widget? sync;

  /// Updates (automatic check, check now), shown under General.
  final Widget? updates;

  List<SettingsTab> get _tabs => [
    for (final t in SettingsTab.values)
      if ((t != SettingsTab.speech || speechModels != null) &&
          (t != SettingsTab.ai || providers != null))
        t,
  ];

  Future<void> _export(BuildContext context) => reportAction(context, () async {
    final l = context.l10n;
    final destination = await pickSaveLocation(
      dialogTitle: l.exportDialogTitle,
      fileName: 'tinglang-practice.md',
      extensions: ['md'],
    );
    if (destination == null) return;
    await File(destination).writeAsString(app.exportMarkdown(l), flush: true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.exported)));
    }
  });

  Widget _choice(
    BuildContext context, {
    required String label,
    required String settingKey,
    required String fallback,
    required Map<String, String> options,
  }) {
    final current = app.setting(settingKey, fallback);
    // Label on the left, control on the right, like the system settings.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: SlType.body.copyWith(color: context.sl.text)),
          ),
          const SizedBox(width: SlSpace.lg),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              key: ValueKey('$settingKey-$current'),
              initialValue: options.containsKey(current) ? current : fallback,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: [
                for (final e in options.entries)
                  DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) {
                if (value != null && value != current) {
                  reportAction(context, () => app.setSetting(settingKey, value));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _switch(
    BuildContext context, {
    required String label,
    String? help,
    required String settingKey,
    required bool fallback,
  }) {
    final c = context.sl;
    final on = app.setting(settingKey, '$fallback') == 'true';
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: SlType.body.copyWith(color: c.text)),
      subtitle: help == null ? null : Text(help, style: SlType.caption.copyWith(color: c.muted)),
      value: on,
      onChanged: (value) => reportAction(context, () => app.setSetting(settingKey, '$value')),
    );
  }

  /// A group of settings; [title] only where a tab holds several groups.
  Widget _section(BuildContext context, List<Widget> children, {String? title}) => Padding(
    padding: const EdgeInsets.only(bottom: SlSpace.lg),
    child: SlPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: SlSpace.lg),
          ],
          ...children,
        ],
      ),
    ),
  );

  String _label(BuildContext context, SettingsTab tab) {
    final l = context.l10n;
    return switch (tab) {
      SettingsTab.general => l.settingsGeneral,
      SettingsTab.captions => l.settingsCaptions,
      SettingsTab.speech => l.settingsSpeechModels,
      SettingsTab.ai => l.providersTitle,
      SettingsTab.data => sync == null ? l.settingsData : l.settingsSyncData,
      SettingsTab.about => l.settingsAbout,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tabs = _tabs;
    final current = tabs.contains(tab) ? tab : SettingsTab.general;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SlPageHeader(
          title: l.navSettings,
          tabs: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SlTabs<SettingsTab>(
              key: const ValueKey('settings-tabs'),
              tabs: [for (final t in tabs) (value: t, label: _label(context, t), count: null)],
              selected: current,
              onChanged: (t) => onTab?.call(t),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            key: ValueKey('settings-${current.name}'),
            padding: const EdgeInsets.fromLTRB(SlSpace.page, 0, SlSpace.page, SlSpace.page),
            children: switch (current) {
              SettingsTab.general => [
                ..._general(context),
                if (updates != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SlSpace.lg),
                    child: updates,
                  ),
              ],
              SettingsTab.captions => _captions(context),
              SettingsTab.speech => [
                SpeechModelsPanel(app: app, models: speechModels!, openUrl: openUrl),
              ],
              SettingsTab.ai => [ProvidersPanel(providers: providers!)],
              SettingsTab.data => [
                if (sync != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SlSpace.lg),
                    child: sync,
                  ),
                ..._data(context),
              ],
              SettingsTab.about => _about(context),
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _general(BuildContext context) {
    final l = context.l10n;
    return [
      _section(context, [
        _choice(
          context,
          label: l.uiLanguage,
          settingKey: AppController.uiLocaleKey,
          fallback: 'system',
          options: {'system': l.followSystem, 'en': 'English', 'zh': '简体中文'},
        ),
        _choice(
          context,
          label: l.appearance,
          settingKey: AppController.themeKey,
          fallback: 'system',
          options: {'system': l.followSystem, 'light': l.themeLight, 'dark': l.themeDark},
        ),
        _choice(
          context,
          label: l.learningLanguage,
          settingKey: AppController.learningLanguageKey,
          fallback: 'en',
          options: learningLanguages,
        ),
        _choice(
          context,
          label: l.nativeLanguage,
          settingKey: AppController.nativeLanguageKey,
          fallback: 'zh-Hans',
          options: learningLanguages,
        ),
      ]),
    ];
  }

  List<Widget> _captions(BuildContext context) {
    final l = context.l10n;
    return [
      _section(context, [
        _switch(context, label: l.settingsShowPanel, settingKey: PanelKeys.visible, fallback: true),
        _choice(
          context,
          label: l.settingsPanelLayout,
          settingKey: PanelKeys.layout,
          fallback: CaptionLayout.stacked.name,
          options: {
            CaptionLayout.stacked.name: l.panelLayoutStacked,
            CaptionLayout.sideBySide.name: l.panelLayoutSideBySide,
          },
        ),
        _choice(
          context,
          label: l.settingsPanelScrollback,
          settingKey: PanelKeys.scrollback,
          fallback: '${CaptionStyle.defaultScrollback}',
          options: {
            for (final n in CaptionStyle.scrollbackChoices) '$n': l.settingsScrollbackLines('$n'),
          },
        ),
        _switch(
          context,
          label: l.settingsKeepSystemAudio,
          help: l.settingsKeepSystemAudioHelp,
          settingKey: keepSystemAudioKey,
          fallback: false,
        ),
        if (onResetPanel != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => reportAction(context, onResetPanel!),
              child: Text(l.panelResetPosition),
            ),
          ),
      ]),
    ];
  }

  List<Widget> _data(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    return [
      _section(context, title: sync == null ? null : l.settingsData, [
        SelectableText(
          app.store.root.path,
          style: SlType.body.copyWith(color: c.inkSoft, fontSize: 13),
        ),
        const SizedBox(height: SlSpace.md),
        Wrap(
          spacing: SlSpace.sm,
          runSpacing: SlSpace.sm,
          children: [
            OutlinedButton.icon(
              onPressed: () => reportAction(context, () async {
                final result = await Process.run('open', [app.store.root.path]);
                if (result.exitCode != 0) {
                  throw StateError(l.finderFailed('${result.stderr}'));
                }
              }),
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: Text(l.openInFinder),
            ),
            OutlinedButton.icon(
              onPressed: () => reportAction(
                context,
                () => Clipboard.setData(ClipboardData(text: app.store.root.path)),
                success: l.dataFolderCopied,
              ),
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: Text(l.copyDataFolder),
            ),
            OutlinedButton.icon(
              onPressed: () => _export(context),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(l.exportMarkdown),
            ),
          ],
        ),
        const SizedBox(height: SlSpace.md),
        Text(l.settingsBackupHint, style: SlType.caption.copyWith(color: c.muted)),
      ]),
    ];
  }

  List<Widget> _about(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    return [
      _section(context, [
        Row(
          children: [
            const BrandMark(size: 44),
            const SizedBox(width: SlSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.appTitle, style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    l.appVersionLine(appVersion),
                    style: SlType.caption.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: SlSpace.md),
        Text(l.openSourceBody, style: SlType.body.copyWith(color: c.inkSoft)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: context.l10n.appTitle,
              applicationVersion: appVersion,
              applicationLegalese: l.legalese,
            ),
            child: Text(l.viewLicenses),
          ),
        ),
      ]),
    ];
  }
}
