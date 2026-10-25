# Soniox (`soniox`)

`lib/src/providers/soniox.dart` · checked against the documentation on 2026-10-25.

## Products and models

| Use | API | Model | Why |
| --- | --- | --- | --- |
| Live captions | Real-time WebSocket API | `stt-rt-v5` | Current real-time model (16 June 2026); `stt-rt-v4` is now an alias of it. One model for all 60 languages, token-level finals with timestamps, endpoint detection. |
| Files | Async API | `stt-async-v5` | Current async model (11 June 2026); `stt-async-v4` is an alias. |

Older names (`stt-rt-v3`, `stt-async-v3`, the `-preview` models) are retired or aliased; see the [models page](https://soniox.com/docs/stt/models).

## Endpoints and authentication

- Live: `wss://stt-rt.soniox.com/transcribe-websocket`. The key goes in the `Authorization: Bearer <key>` upgrade header. The `api_key` field of the start message is deprecated (connections that send the key only there are refused from 15 January 2027), so it is never sent.
- REST: `https://api.soniox.com/v1/…` with `Authorization: Bearer <key>`.
- `hosts()`: `api.soniox.com`, `stt-rt.soniox.com`.
- `verify`: `GET /v1/models`. It is free, needs a valid key and sends no audio.
- Data residency: Soniox has regional deployments (EU: `api.eu.soniox.com`, `stt-rt.eu.soniox.com`) for projects set up with sales. Each needs its own key, so the adapter does not offer them. See the open questions.

## Live protocol

1. Upgrade with the key header, then send one JSON text message: `{"model":"stt-rt-v5","audio_format":"pcm_s16le","sample_rate":16000,"num_channels":1,"language_hints":["en"],"enable_endpoint_detection":true}`.
2. Send audio as binary frames, forwarded as the app captures them (40–200 ms). Soniox sets no frame size; its examples send 120 ms.
3. Each response carries `tokens` (`text`, `start_ms`, `end_ms`, `is_final`, …). Final tokens are never repeated. Non-final tokens are replaced in every response.
4. Ending: an empty text frame. Soniox finalizes everything, sends `{"finished": true}` and closes. `finish()` waits for that, or for its timeout.
5. When no audio has been sent for `keepAliveInterval` (10 s), the adapter sends `{"type":"keepalive"}`. Without audio or a keepalive for 20 s, Soniox ends the stream with 408.

**Lines.** Tokens are sub-words (`"Hel"`, `"lo"`, `" world"`), so the adapter builds caption lines from them. A line ends:

- at `<end>`, which endpoint detection sends after a pause (or `<fin>`);
- at a sentence end: `.` `?` `!` `…` followed by a token that starts a new word and is not lower case (not after `Mr.`, `e.g.`, `U.S.` or an initial), or followed by a Han or kana character;
- at once after `。` `？` `！`;
- at a gap of 2 s or more between tokens.

The open line's final tokens plus the current non-final tokens make the partial. The partial and the line's final share `id` (`"0"`, `"1"`, …). Times are Soniox's `start_ms`/`end_ms`, which count from the first audio byte of the stream, as the interface requires.

**Words.** A token that starts with a space starts a word. Han and kana tokens are words of their own. Punctuation joins the word before it. Live partials carry no words; finals and file segments do.

## Limits

| | Limit | Source |
| --- | --- | --- |
| Stream length | 300 min per stream (fixed). Then error 413 `max_duration_reached` → `sessionEnded` | [RT limits](https://soniox.com/docs/stt/rt/limits-and-quotas) |
| Concurrency | 10 streams, 100 requests/min (default; can be raised) | same |
| File duration | 300 min (fixed) | [async limits](https://soniox.com/docs/stt/async/limits-and-quotas) |
| File size | Not published. An older guide said 500 MB | — |
| Storage | 10 GB, 1,000 files, 100 pending and 2,000 total transcriptions; auto-deleted after 30 days | async limits |

`CloudAsrInfo.maxFileMs` is 240 min and `maxFileBytes` is 480 MB. A 16 kHz mono 16-bit WAV uses 32 kB/s, so 240 min is about 461 MB. Both stay under the 300-minute limit and the old 500 MB figure. Longer files are split by the caller.

## Files

`POST /v1/files` (multipart, field `file`, `tinglang.wav`) → `POST /v1/transcriptions` `{"model":"stt-async-v5","file_id":…,"language_hints":[…]}` → poll `GET /v1/transcriptions/{id}` every `pollInterval` (1 s) until `completed` or `error` (`fileTimeout` 2 h) → `GET /v1/transcriptions/{id}/transcript` → lines as above.

Progress: the upload counts for 0–0.5, the transcript fetch moves it to 0.9 and the result to 1.0. Soniox reports no progress while it processes. The cancel token is checked before each step and aborts an upload or request in flight.

**Privacy and cleanup.** In a `finally` block, the adapter always calls `DELETE /v1/transcriptions/{id}` and then `DELETE /v1/files/{id}`, after success, failure or cancel. Soniox refuses to delete a transcription that is still processing, which only happens after a cancel. Deleting its file makes that job fail, and Soniox removes the remaining record after 30 days.

## Languages

Soniox takes ISO 639-1 `language_hints` and has one model for 60 languages. `info.languages` lists all 60. Mapping: `en`, `en-US`, `en-GB` → `en`; `zh-Hans` → `zh`; `ja`, `ko`, `es`, `fr`, `de` as they are. Any tag whose base is not in the list throws `unsupportedLanguage` before connecting. `language_hints_strict` is not sent, because the real-time API says not every model supports it.

## Errors

Soniox sends `{"error_code", "error_type", "error_message"}` on the WebSocket, then closes. REST errors return `{"status_code", "error_type", "message"}`.

| Soniox | Kind |
| --- | --- |
| 400 (`invalid_request`, `model_not_available`) | `badRequest`; `unsupportedLanguage` if the message is about the language; `audioTooLong` for "too long" / "too much audio" |
| 401 `unauthenticated`, 403 `permission_denied` | `unauthorized` |
| 402 `organization_balance_exhausted`, `…_monthly_budget_exhausted` | `quotaExceeded` |
| 404, 409 | `badRequest` |
| 408 `request_timeout` | `network` (retryable) |
| 413 `max_duration_reached` on a stream | `sessionEnded` (413 on REST → `audioTooLong`) |
| 429 `limit_exceeded`, `max_concurrent_connections_reached` | `rateLimited` |
| 5xx `internal_error`, `service_unavailable` | `server` |
| WebSocket close 1001 (idle) | `sessionEnded` |
| Refused upgrade | By HTTP status as above. Socket, TLS or timeout failures → `network` |
| Job `status: error` | By `error_type`: `invalid_request` / `file_not_found` → `badRequest`, internal → `server` |

Messages are the service's own text, with the key and any key-like run removed (`scrub`).

## Links

- Console and keys: https://console.soniox.com
- Pricing: https://soniox.com/pricing ($0.12/h real-time, $0.10/h async, on 2026-10-25)
- Docs: https://soniox.com/docs (WebSocket API: https://soniox.com/docs/stt/api-reference/websocket-api, REST: https://soniox.com/docs/openapi.yaml)

## Tested here, and not verified against the live service

`test/soniox_test.dart` uses a loopback server only (`fvm dart test`). It covers:

- the Bearer header;
- the exact start message, with no key in it;
- audio forwarded byte for byte;
- partials, then finals with stable ids and Soniox's times;
- words joined from sub-word tokens;
- sentence, CJK, abbreviation and pause splitting;
- `finish` (empty frame, `finished`, close);
- error messages mapped to kinds, idle close → `sessionEnded`, a refused upgrade, an unreachable host;
- keepalive;
- cancel;
- the file flow in order (upload → create → poll ×3 → transcript → delete transcription → delete file), with times, words and progress;
- a failed job and a 402 still cleaning up;
- cancel while polling;
- language and limit checks before any request;
- the key never appearing in any thrown error.

**Not verified against the live service:** no real key was used. These are written from the documentation and have not been run against Soniox:

- the exact token stream (how often `<end>` arrives, how stable non-final tokens are);
- whether Soniox rejects the upgrade itself on a bad key (handled either way);
- the real upload size limit;
- the deletion behaviour.
