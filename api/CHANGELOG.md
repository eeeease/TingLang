# API changelog

Versions of `api/openapi.yaml` (`info.version`). Additive changes raise the minor version; breaking changes start a new URL major version (`/v2`).

## 1.3.0 · 2026-11-03

- `GET /library` and `GET /library/{course_id}` take the account's token (optional). Without one, the library is a preview: the first three courses of each category with `preview: true`, and the courses outside it answer 401. Optional `course_count` on the library and on each category gives the full counts. A token that is sent but invalid answers 401.

## 1.2.0 · 2026-11-02

- `GET /library`: optional `categories` (interest categories in display order, with a name per language) and, per course, optional `category` and `series`. Clients that ignore them still list every course.

## 1.1.0 · 2026-11-01

- `GET /library` and `GET /library/{course_id}`: the official library. No sign-in; the client asks only when the user opens it. Text only (courses and a JPEG `cover_url`); media plays from where it is published.

## 1.0.0 · unreleased

First version of the contract.

- `GET /meta`: API version, server info, minimum client version, OAuth 2.1 settings (`auth`), feature switches, website links.
- `GET /account`, `GET /entitlements` (display only; every endpoint checks for itself), `POST /auth/revoke` (RFC 7009).
- Cloud jobs: `POST /jobs/estimate`, `POST /jobs` (with `Idempotency-Key`), presigned uploads, `POST /jobs/{id}/start`, `GET /jobs/{id}` (with `Retry-After`), `GET /jobs/{id}/result`, `POST /jobs/{id}/cancel`, `GET /jobs`. Kinds: `transcribe`, `translate`, `course` (reserved; not offered yet).
- LLM gateway, OpenAI-compatible: `GET /llm/models`, `POST /llm/chat/completions`.
- Problem details with the codes in `x-problem-codes`.

Planned, not in 1.0.0: account export and deletion, sync and backup, community sharing.
