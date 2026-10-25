# Contributing to TingLang

Thanks for helping. Please read `AGENTS.md` (it applies to people too),
`docs/ARCHITECTURE.md` and `docs/VERIFICATION.md` before a change.

Security problems: please report them privately as described in
`SECURITY.md`, not in a public issue.

## Ground rules

- Local-first. Never add telemetry, analytics or background network traffic.
  Accounts and cloud services are optional and go through the contract in
  `api/` (see `docs/CLOUD.md`): nothing may contact a server before the user
  signs in or turns that feature on. A feature that sends audio or text off the device must be off by
  default, enabled explicitly by the user, and labelled in the UI where it runs
  (`SlBadge.cloud`). Cloud backends are registered with `cloud: true` so the
  backend registry never auto-selects them.
- Do not commit personal data: learner records, recordings, private course
  files, tokens or `Local.xcconfig`.
- Do not copy code from projects whose licence is incompatible with
  AGPL-3.0-only, and keep the notice of any permissively licensed code you port
  (see NOTICE.md).
- `macos/` is generated. Native customisation lives in
  `scripts/configure_macos.py`, `scripts/native/` and `packages/tinglang_native_*`.

## Checks

```bash
fvm install            # Flutter version from .fvmrc
bash scripts/check.sh  # Python checks, analyze, all tests
bash scripts/check.sh --build   # plus a macOS release build (on a Mac)
```

Record what you actually ran, and what you could not run, in
`docs/VERIFICATION.md`. Do not weaken a behavioural test to get a green result.

## Licence of contributions (inbound grant)

TingLang is dual-licensed: the GNU Affero General Public License v3.0 only,
and a separate commercial licence that the copyright holder, eeeease, offers
for uses that cannot meet the AGPL's obligations (closed-source products,
app-store builds, hosted services without published source; see NOTICE.md).
To keep that possible, contributions are accepted on the following terms.

By submitting a contribution (code, documentation, translations, design assets
or other material) to this repository, you agree that:

1. **Outbound licence.** Your contribution is licensed to everyone under
   AGPL-3.0-only, the same as the rest of TingLang.
2. **Additional grant to the copyright holder.** You also grant eeeease (the
   TingLang maintainer) a perpetual, worldwide, non-exclusive, royalty-free, irrevocable
   licence to use, reproduce, modify, distribute, sublicense and relicense your
   contribution, including under proprietary or commercial licence terms, as
   part of TingLang or derived works.
3. **Your rights.** You keep the copyright in your contribution and may use it
   in any other way you like. This is a licence grant, not a copyright
   assignment.
4. **Origin.** The contribution is your own original work, or you have the
   right to submit it under these terms (for example it is under a compatible
   permissive licence whose notice you include). If your employer has rights
   in your work, you have their permission.
5. **No obligation.** The maintainer is not required to accept or use your
   contribution.

Sign off each commit to confirm (`git commit -s`, adding
`Signed-off-by: Your Name <email>`). If you cannot agree to point 2, say so in
the pull request before investing work; we may still accept the change
AGPL-only, or reimplement it.

This text is a good-faith summary written for this project, not legal advice.
