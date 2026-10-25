import 'package:flutter/material.dart';
import 'package:tinglang_ui/tinglang_ui.dart';
import 'package:tinglang_api/tinglang_api.dart';

import '../l10n/app_localizations.dart';
import '../services/cloud/cloud_controller.dart';
import 'brand.dart';
import 'errors.dart';

/// Opens the account in a dialog (from the sidebar).
Future<void> showAccountDialog(
  BuildContext context,
  CloudController cloud, {
  Future<void> Function(Uri url)? openUrl,
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SingleChildScrollView(
        child: AccountPanel(cloud: cloud, openUrl: openUrl),
      ),
    ),
  ),
);

/// The sidebar entry: "Sign in", or the account's name and plan.
class AccountEntry extends StatelessWidget {
  const AccountEntry({super.key, required this.cloud, this.openUrl});
  final CloudController cloud;
  final Future<void> Function(Uri url)? openUrl;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: cloud,
    builder: (context, _) {
      final l = context.l10n;
      final c = context.sl;
      final account = cloud.account;
      final name = account?.displayName ?? account?.email;
      final signedIn = cloud.signedIn && name != null;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        child: Material(
          color: Colors.transparent,
          borderRadius: SlRadius.all(10),
          child: InkWell(
            key: const ValueKey('nav-account'),
            borderRadius: SlRadius.all(10),
            onTap: () => showAccountDialog(context, cloud, openUrl: openUrl),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  if (signedIn)
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: c.accentSoft,
                      child: Text(
                        name.characters.first.toUpperCase(),
                        style: SlType.micro.copyWith(
                          color: c.accentInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    Icon(Icons.account_circle_outlined, size: 18, color: c.inkSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      signedIn ? name : l.navSignIn,
                      overflow: TextOverflow.ellipsis,
                      style: SlType.body.copyWith(color: c.text, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (signedIn) SlBadge(planName(l, cloud.entitlements)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// "Free", "Pro", or the plan id the server sent.
String planName(AppLocalizations l, Entitlements? plan) => switch (plan?.plan) {
  null || 'free' => l.planFree,
  'pro' => 'Pro',
  final other => other,
};

/// The optional TingLang account. Signing in happens in the browser; the app
/// shows the plan and usage. Buying and managing happen on the website, which
/// the buttons open; there is no payment in the app.
class AccountPanel extends StatelessWidget {
  const AccountPanel({super.key, required this.cloud, this.openUrl});
  final CloudController cloud;

  /// Opens a website page in the default browser.
  final Future<void> Function(Uri url)? openUrl;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: cloud,
    builder: (context, _) {
      final l = context.l10n;
      final server = cloud.server;
      return SlPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l.settingsAccount, style: Theme.of(context).textTheme.titleLarge),
                ),
                if (server != null) SlBadge.cloud(l.providerCloud),
              ],
            ),
            const SizedBox(height: SlSpace.md),
            if (server == null)
              const SizedBox.shrink()
            else if (!cloud.signedIn)
              ..._signedOut(context, l, server)
            else
              ..._signedIn(context, l, server),
            if (server != null && cloud.error != null) ...[
              const SizedBox(height: SlSpace.md),
              SlNotice(describeCloudError(l, cloud.error!, host: server.host), error: true),
            ],
          ],
        ),
      );
    },
  );

  List<Widget> _signedOut(BuildContext context, AppLocalizations l, ServerUrl server) {
    final c = context.sl;
    return [
      Text(l.accountSignedOutBody, style: SlType.body.copyWith(color: c.inkSoft)),
      const SizedBox(height: SlSpace.xs),
      Text(l.accountSignInHost(server.host), style: SlType.caption.copyWith(color: c.muted)),
      const SizedBox(height: SlSpace.md),
      Wrap(
        spacing: SlSpace.sm,
        runSpacing: SlSpace.sm,
        children: [
          FilledButton.icon(
            key: const ValueKey('account-sign-in'),
            onPressed: cloud.busy ? null : cloud.signIn,
            icon: const Icon(Icons.open_in_browser, size: 18),
            label: Text(cloud.busy ? l.accountSigningIn : l.accountSignIn),
          ),
          if (openUrl != null)
            OutlinedButton.icon(
              key: const ValueKey('account-plans'),
              onPressed: () => reportAction(
                context,
                () => openUrl!(CloudController.website.resolve('/pricing')),
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l.accountPlans),
            ),
        ],
      ),
    ];
  }

  List<Widget> _signedIn(BuildContext context, AppLocalizations l, ServerUrl server) {
    final c = context.sl;
    final account = cloud.account;
    final plan = cloud.entitlements;
    final web = cloud.meta?.web;
    final offered = [
      for (final f in CloudController.services)
        if (cloud.offers(f)) f,
    ];
    return [
      Text(
        account?.displayName ?? account?.email ?? account?.id ?? server.host,
        style: SlType.title.copyWith(color: c.text, fontWeight: FontWeight.w600),
      ),
      if (account?.displayName != null && account?.email != null)
        Text(account!.email!, style: SlType.caption.copyWith(color: c.muted)),
      if (plan != null) ...[
        const SizedBox(height: SlSpace.md),
        Row(
          children: [
            Text(l.accountPlan(planName(l, plan)), style: SlType.body.copyWith(color: c.text)),
            const SizedBox(width: SlSpace.sm),
            SlBadge(_status(l, plan.knownStatus)),
          ],
        ),
      ],
      if (cloud.offline) ...[
        const SizedBox(height: SlSpace.md),
        SlNotice(
          cloud.planConfirmed
              ? l.accountOffline(server.host, _when(context, plan!.checkedAt))
              : l.accountOfflineUnconfirmed(server.host),
        ),
      ],
      const SizedBox(height: SlSpace.lg),
      Text(l.accountServices, style: SlType.caption.copyWith(color: c.muted)),
      const SizedBox(height: SlSpace.xs),
      if (offered.isEmpty)
        Text(l.accountNoServices, style: SlType.body.copyWith(color: c.inkSoft))
      else
        for (final feature in offered) _service(context, l, feature, plan),
      const SizedBox(height: SlSpace.md),
      Wrap(
        spacing: SlSpace.sm,
        runSpacing: SlSpace.sm,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('account-refresh'),
            onPressed: cloud.busy ? null : cloud.refresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l.accountRefresh),
          ),
          if (openUrl != null && web?.accountUrl != null)
            OutlinedButton.icon(
              onPressed: () => reportAction(context, () => openUrl!(web!.accountUrl!)),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l.accountManage),
            ),
          if (openUrl != null && web?.pricingUrl != null)
            CloudController.isFree(plan)
                ? FilledButton.icon(
                    key: const ValueKey('account-upgrade'),
                    onPressed: () => reportAction(context, () => openUrl!(web!.pricingUrl!)),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(l.accountUpgrade),
                  )
                : OutlinedButton.icon(
                    onPressed: () => reportAction(context, () => openUrl!(web!.pricingUrl!)),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(l.accountPlans),
                  ),
          TextButton(
            key: const ValueKey('account-sign-out'),
            onPressed: cloud.busy ? null : cloud.signOut,
            child: Text(l.accountSignOut),
          ),
        ],
      ),
    ];
  }

  Widget _service(BuildContext context, AppLocalizations l, String feature, Entitlements? plan) {
    final c = context.sl;
    final entitlement = plan?.features[feature];
    final quota = entitlement?.quota;
    final state = plan == null
        ? null
        : (entitlement?.enabled ?? false)
        ? l.cloudServiceIncluded
        : l.cloudServiceNotInPlan;
    final detail = [
      ?state,
      if (quota != null && (entitlement?.enabled ?? false)) _quota(context, l, quota),
    ].join(' · ');
    return Padding(
      key: ValueKey('cloud-service-$feature'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(switch (feature) {
              'jobs.transcribe' => l.cloudServiceTranscribe,
              'jobs.translate' => l.cloudServiceTranslate,
              _ => l.cloudServiceLlm,
            }, style: SlType.body.copyWith(color: c.text)),
          ),
          if (detail.isNotEmpty) Text(detail, style: SlType.caption.copyWith(color: c.muted)),
        ],
      ),
    );
  }

  static String _number(num n) => n == n.roundToDouble() ? '${n.round()}' : n.toStringAsFixed(1);

  String _quota(BuildContext context, AppLocalizations l, Quota quota) {
    final used = _number(quota.used), limit = _number(quota.limit);
    final text = switch (quota.unit) {
      'minute' => l.quotaMinutes(used, limit),
      'credit' => l.quotaCredits(used, limit),
      _ => l.quotaOther(used, limit),
    };
    final resets = quota.resetsAt;
    return resets == null
        ? text
        : '$text, ${l.quotaResets(MaterialLocalizations.of(context).formatMediumDate(resets.toLocal()))}';
  }

  static String _when(BuildContext context, DateTime time) {
    final local = time.toLocal();
    final m = MaterialLocalizations.of(context);
    return '${m.formatMediumDate(local)} ${m.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  static String _status(AppLocalizations l, EntitlementStatus status) => switch (status) {
    EntitlementStatus.active => l.accountStatusActive,
    EntitlementStatus.trialing => l.accountStatusTrialing,
    EntitlementStatus.pastDue => l.accountStatusPastDue,
    EntitlementStatus.canceled => l.accountStatusCanceled,
    EntitlementStatus.expired => l.accountStatusExpired,
    EntitlementStatus.none => l.accountStatusNone,
    EntitlementStatus.unknown => l.accountStatusUnknown,
  };
}
