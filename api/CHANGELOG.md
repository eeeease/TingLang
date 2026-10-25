# API changelog

Versions of `api/openapi.yaml` (`info.version`). Additive changes raise the minor version; breaking changes start a new URL major version (`/v2`).

## 1.0.0 · unreleased

First version of the contract.

- `GET /meta`: API version, server info, minimum client version, OAuth 2.1 settings (`auth`), feature switches, website links.
- `GET /account`, `GET /entitlements` (display only; every endpoint checks for itself), `POST /auth/revoke` (RFC 7009).
- Cloud jobs: `POST /jobs/estimate`, `POST /jobs` (with `Idempotency-Key`), presigned uploads, `POST /jobs/{id}/start`, `GET /jobs/{id}` (with `Retry-After`), `GET /jobs/{id}/result`, `POST /jobs/{id}/cancel`, `GET /jobs`. Kinds: `transcribe`, `translate`, `course` (reserved; not offered yet).
- LLM gateway, OpenAI-compatible: `GET /llm/models`, `POST /llm/chat/completions`.
- Problem details with the codes in `x-problem-codes`.

Planned, not in 1.0.0: account export and deletion, sync and backup, community sharing.
