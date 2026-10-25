# Account and cloud services

TingLang works fully without an account. The optional TingLang account adds what only a server can do (plans today; official cloud transcription and AI courses later). This document describes how the app talks to that server. The server itself is operated by the TingLang team and is not part of this repository.

## Principles

1. **Local first.** Every feature on the Mac works without signing in, and nothing contacts a TingLang server before the user signs in, refreshes or signs out. `test/cloud/offline_guarantees_test.dart` enforces this: starting the app and visiting every page creates no HTTP client.
2. **One versioned contract.** The app only knows the OpenAPI 3.1 contract in [`api/`](../api) (schemas and an example per operation). It never embeds a vendor SDK or reads the server's database; the server's implementation can change without an app update. `packages/tinglang_api` is the client.
3. **Discovery, not hard-coding.** The app knows one address, `https://api.tinglang.app` (`CloudController.official`), and reads everything else — sign-in endpoints, client id, redirect, website pages, which features are on — from `GET /v1/meta`.
4. **No payment in the app.** Buying, changing and cancelling a plan happen on the website (tinglang.app). The app reads the plan and usage (`GET /v1/entitlements`) to decide what to show and opens the website for the rest. It contains no payment SDK, price list or server secret.
5. **The server decides.** Every paid capability is checked on the server; the app's view of the plan is only for display (an open-source client can be changed, so it cannot be trusted to enforce anything).

## Sign-in

OAuth 2.1 authorization code with PKCE (RFC 8252 for native apps):

1. The user presses **Sign in** (sidebar → account). Only then does the app request `/v1/meta`.
2. The app creates a `code_verifier` and `state` and opens the `authorization_endpoint` in the system's web authentication session (`ASWebAuthenticationSession`, capability `webAuth`), so the user signs in with the browser's saved passwords and passkeys — email code, Google or GitHub.
3. The redirect (`auth.redirect_uri` in `/v1/meta`, a private scheme such as `tinglang://oauth/callback`) is caught by that session, not by an open port. The app checks `state` and exchanges the code with the verifier for an access token (short-lived, kept in memory) and a refresh token.
4. The refresh token is stored in the Keychain (`SecretStore`, key `account:<server host>`), never in the database; the server rotates it on each refresh.
5. Signing out asks the server to revoke the session (`/v1/auth/revoke`, RFC 7009 style) and always forgets the tokens and cached account locally, whether or not the server answered.

The database keeps only that the user is signed in, the account's display fields, the last `/v1/meta` and the last entitlements.

## Plans and usage

`GET /v1/entitlements` returns the plan, its status, per-feature switches and quotas (unit, limit, used, reset time), `valid_until` and `grace_until`. Offline, the app keeps showing the cached plan until `grace_until` and then says it cannot confirm the plan; since every paid feature runs on the server, being offline never changes what works on the Mac.

## Cloud jobs (contract only)

The contract already describes asynchronous jobs (estimate → create with an `Idempotency-Key` → upload to a presigned URL → poll → fetch the result → cancel) whose results reuse the app's own formats (`transcript.json` of a `.tinglang` package, or a course document), and an LLM gateway. The official server does not offer them yet: `/v1/meta` reports them off and the app lists TingLang's own cloud speech service as "coming soon". Third-party cloud speech services with the user's own key are a separate, local feature (`packages/tinglang_cloud_asr`).

## Conventions

- Errors are RFC 9457 problem details with a stable `code` (`unauthorized`, `entitlement_required`, `quota_exceeded`, `rate_limited`, `client_too_old`, …); the app maps codes to messages in the user's language and never shows the server's own text.
- `Retry-After` is honoured; a 401 is retried once with a refreshed token.
- The contract changes additively within `v1`; `api/CHANGELOG.md` records every change, and a `v2` would run alongside `v1` for at least six months.
- `ServerUrl` accepts only https (plain http only for this Mac, for development builds with `--dart-define=TINGLANG_SERVER=…`).

## Privacy

Signing in sends the account's email and sign-in provider to the server; using a cloud feature sends what that feature needs and nothing else. The app sends no analytics. Media sent for a cloud job is deleted by the server after the job (at most 24 hours later) and results after 7 days.
