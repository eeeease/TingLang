import 'package:flutter/material.dart';

import 'theme.dart';
import 'tokens.dart';

/// Card surface: hairline edge and a whisper shadow tinted toward the ink. A
/// [Material] (not a decorated box) so ListTiles and InkWells inside keep
/// visible ink.
class SlPanel extends StatelessWidget {
  const SlPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Defaults to the theme's surface colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.sl;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: SlRadius.all(SlRadius.lg),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 3, offset: const Offset(0, 1))],
      ),
      child: Material(
        color: color ?? c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: SlRadius.all(SlRadius.lg),
          side: BorderSide(color: c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Top of a main-window page: title, optional tabs and actions. The top
/// inset leaves the transparent title bar (window dragging) free.
class SlPageHeader extends StatelessWidget {
  const SlPageHeader({super.key, required this.title, this.tabs, this.actions = const []});
  static const topInset = 40.0;
  final String title;
  final Widget? tabs;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(SlSpace.page, topInset, SlSpace.page, SlSpace.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineMedium)),
            for (final action in actions) ...[const SizedBox(width: SlSpace.sm), action],
          ],
        ),
        if (tabs != null) ...[const SizedBox(height: SlSpace.lg), tabs!],
      ],
    ),
  );
}

/// A page or section title with an optional one-line subtitle and a trailing
/// action. No eyebrow labels: the title says enough.
class SlSectionHeading extends StatelessWidget {
  const SlSectionHeading(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: SlSpace.xs),
              Text(subtitle!, style: SlType.body.copyWith(color: context.sl.muted)),
            ],
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: SlSpace.lg), trailing!],
    ],
  );
}

/// Inline note. Use only when the reader can act on it; errors say what
/// happened and what to do.
class SlNotice extends StatelessWidget {
  const SlNotice(this.message, {super.key, this.error = false, this.action});
  final String message;
  final bool error;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.sl;
    final tone = error ? c.danger : c.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: error ? c.danger.withValues(alpha: .08) : c.raised,
        borderRadius: SlRadius.all(SlRadius.md),
      ),
      child: Row(
        children: [
          Icon(error ? Icons.error_outline : Icons.info_outline, size: 18, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: SlType.body.copyWith(fontSize: 13, color: c.inkSoft)),
          ),
          if (action != null) ...[const SizedBox(width: SlSpace.md), action!],
        ],
      ),
    );
  }
}

/// Centered invitation for a section with nothing in it yet: what goes here
/// and the one thing to do next.
class SlEmptyState extends StatelessWidget {
  const SlEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.badges = const [],
    this.art,
  });
  final IconData icon;
  final String title, body;
  final Widget? action;

  /// Small labels such as a cloud badge.
  final List<Widget> badges;

  /// Replaces [icon], e.g. with the brand mark.
  final Widget? art;

  @override
  Widget build(BuildContext context) {
    final c = context.sl;
    return SlPanel(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(
        children: [
          art ??
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
                child: Icon(icon, size: 24, color: c.accentInk),
              ),
          const SizedBox(height: SlSpace.lg),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: SlSpace.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: SlType.body.copyWith(color: c.muted),
            ),
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: SlSpace.lg),
            Wrap(
              spacing: SlSpace.sm,
              runSpacing: SlSpace.sm,
              alignment: WrapAlignment.center,
              children: badges,
            ),
          ],
          if (action != null) ...[const SizedBox(height: SlSpace.xl - 4), action!],
        ],
      ),
    );
  }
}

/// Pill label. Use [SlBadge.cloud] wherever a feature sends data off the
/// device, so cloud use is always visible.
class SlBadge extends StatelessWidget {
  const SlBadge(this.label, {super.key, this.icon, this.warning = false});
  const SlBadge.cloud(this.label, {super.key}) : icon = Icons.cloud_outlined, warning = true;
  final String label;
  final IconData? icon;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final c = context.sl;
    final tone = warning ? c.warning : c.accentInk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .1),
        borderRadius: SlRadius.all(SlRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: tone),
            const SizedBox(width: SlSpace.xs),
          ],
          Text(
            label,
            style: SlType.micro.copyWith(color: tone, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Segmented tabs on an inset track; the selected tab is a raised chip.
class SlTabs<T> extends StatelessWidget {
  const SlTabs({super.key, required this.tabs, required this.selected, required this.onChanged});

  /// Value → label (and optional count shown after it).
  final List<({T value, String label, int? count})> tabs;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.sl;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.raised, borderRadius: SlRadius.all(SlRadius.md)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tab in tabs)
            _Tab(
              label: tab.label,
              count: tab.count,
              selected: tab.value == selected,
              onTap: () => onChanged(tab.value),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sl;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? c.surface : Colors.transparent,
          borderRadius: SlRadius.all(SlRadius.sm + 1),
          boxShadow: selected
              ? [BoxShadow(color: c.shadow, blurRadius: 3, offset: const Offset(0, 1))]
              : null,
        ),
        child: InkWell(
          borderRadius: SlRadius.all(SlRadius.sm + 1),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: SlType.label.copyWith(color: selected ? c.text : c.muted)),
                if (count != null && count! > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: SlType.caption.copyWith(
                      color: selected ? c.accentInk : c.muted,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
