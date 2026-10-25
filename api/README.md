# Tinglang Cloud API contract

The contract between the Tinglang desktop client (this repository) and a Tinglang server (TingLang-web, or anyone's own). The client only depends on what is written here; how a server implements it is up to the server. Design notes, versioning rules and the offline guarantees are in [docs/CLOUD.md](../docs/CLOUD.md).

```text
api/
├── openapi.yaml     OpenAPI 3.1; schemas are referenced from schemas/
├── schemas/         JSON Schema (draft 2020-12), one file per type
├── examples/        <operationId>/request.json and response.<status>[.<variant>].json
└── CHANGELOG.md
```

## Using it

- **Server side:** pin a tagged version of this folder (tags look like `api-v1.0.0`). Implement the operations you offer and say which ones in `GET /v1/meta` → `features`; leave the rest out or answer `feature_disabled`. Check your responses against the files in `examples/` and the schemas.
- **Client side:** `packages/tinglang_api` parses every example (round trip) and talks to the endpoints.
- **The examples are fixtures for both sides.** Every operation has a request example when it takes a body, and at least one success example. Hosts in examples use the reserved `.example` domain; the official domain is not decided yet.

## Rules

- Everything is under `/v1`. Inside v1, changes only add: new operations, new optional fields, new enum values, new features. Clients ignore unknown fields and treat unknown values as unknown.
- A breaking change goes to `/v2`, and v1 keeps working for at least six months alongside it (with `Deprecation` and `Sunset` headers).
- `info.version` follows semantic versioning; every change is recorded in [CHANGELOG.md](CHANGELOG.md).
- JSON keys are snake_case. Embedded documents keep their own format: `transcript.json` is exactly the one inside a `.tinglang` share package, `course.json` is an English V3 course.
- Errors are RFC 9457 problem details with a stable `code` from `x-problem-codes` in `openapi.yaml`.

## Checking

```bash
cd packages/tinglang_api
dart run tool/validate_api.dart   # spec against OpenAPI 3.1, schemas compile, examples validate
dart test                         # the checker's own tests and the client's round trips
```

`scripts/check.sh` runs both. The OpenAPI 3.1 schema used for the first check is vendored in `packages/tinglang_api/tool/` (Apache-2.0, OpenAPI Initiative).

## A local stand-in server

`python3 tools/mock_cloud_server.py [port]` serves these examples on `http://127.0.0.1:8787` with a minimal OAuth flow (the authorize step redirects straight back to `tinglang://oauth/callback`). Point Tinglang at it under Settings → Advanced → Server address to try the account screens without a real server. It binds to this machine only and stores nothing.

## Licence

For now this folder is under the repository's licence, AGPL-3.0-only. A separate, more permissive licence for the contract is under consideration (see docs/CLOUD.md §3.2).
