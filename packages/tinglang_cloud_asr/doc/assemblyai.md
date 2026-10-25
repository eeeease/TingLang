# AssemblyAI (`assemblyai`)

`lib/src/providers/assemblyai.dart` · checked against the documentation on 2026-10-25.

## Products and models

| Use | API | Model | Why |
| --- | --- | --- | --- |
| Live captions | Universal-Streaming v3 WebSocket | `universal-3-6-pro` | AssemblyAI's recommended and default streaming model. It covers 32 languages (all seven app languages; the cheaper Universal-Streaming models cover only en/es/de/fr/pt/it) and sends formatted, punctuated turns. $0.45/h. |
| Files | Pre-recorded `/v2/transcript` | `speech_models: ["universal-3-5-pro", "universal-2"]` | Universal-3.5 Pro is the recommended pre-recorded model ($0.21/h). Languages it lacks (Korean among them) fall back to Universal-2 (99 languages, $0.15/h). This is the service's own default list, sent explicitly so it does not change silently. |

Cheaper alternative, not used: `universal-streaming-english` / `-multilingual` at $0.15/h. They are less accurate, need `format_turns=true`, and do not cover zh/ja/ko. The stream code already handles their unformatted-then-formatted end of turn (`formatTurns`). See the open questions.

## Endpoints, regions and authentication

| Region (`region` field) | REST | Streaming |
| --- | --- | --- |
| `us` (default) | `https://api.assemblyai.com` | `wss://streaming.us.assemblyai.com/v3/ws` (US data residency) |
| `eu` | `https://api.eu.assemblyai.com` | `wss://streaming.eu.assemblyai.com/v3/ws` (EU data residency) |

`wss://streaming.assemblyai.com` is AssemblyAI's "global" endpoint, which routes each connection to the nearest region. `us` uses the US data-residency host instead, so choosing a region always means the data stays there. One API key works for both regions. On the EU endpoint, account and usage data still stay in the US.

- The API key goes in the `Authorization` header with no `Bearer` prefix, on REST and on the WebSocket upgrade. Temporary tokens in the URL are for browsers and are not used.
- `hosts()`: the REST and streaming hosts of the chosen region.
- `verify`: `GET /v2/transcript?limit=1`. It is free, needs a valid key and sends no audio.

## Live protocol

1. Connect to `…/v3/ws?sample_rate=16000&encoding=pcm_s16le&speech_model=universal-3-6-pro&language_codes=["en"]`. `language_codes` is a JSON array in one query value, as the API spec's example shows. Wait for `Begin`, at most `readyTimeout` (10 s). An `Error` or close before `Begin` throws from `openStream`.
2. Audio goes out as binary frames of exactly 100 ms (3,200 bytes), re-chunked from the app's 40–200 ms captures. The service requires 50–1,000 ms per frame (otherwise close 3007). It also rejects audio sent faster than real time, so nothing is paced or buffered beyond one frame.
3. `Turn` messages: all messages of one turn share `turn_order`, which is used as the segment `id`. Partial text is every word so far (final or not). The final is the `transcript` of the message with `end_of_turn: true`. For Universal-3.x that message is already formatted. For the Universal-Streaming models the adapter would wait for `turn_is_formatted: true`. Times are the words' `start`/`end` (ms from the stream start). Finals carry words.
4. `finish()`: send the last partial frame (padded with silence to 50 ms), then `{"type":"ForceEndpoint"}` so the open turn ends, then `{"type":"Terminate"}`. Wait for `Termination` and the close.

## Limits

| | Limit |
| --- | --- |
| Stream length | 3 h per session, then close 3008 `Session Expired` → `sessionEnded`. Billing is by session time, so streams are always terminated. |
| New streams | 5 per minute on free accounts; 100+ per minute, auto-scaling, on paid ones. Over the limit: close 1008 "Too many concurrent sessions" → `rateLimited` |
| File | 2.2 GB per `/v2/upload`; 10 h of audio |

`CloudAsrInfo.maxFileMs` is 10 h and `maxFileBytes` is 2.2 GB (a 10 h WAV is about 1.15 GB).

## Files

`POST /v2/upload` (raw bytes, `application/octet-stream`) → `upload_url` → `POST /v2/transcript` `{"audio_url", "speech_models", "language_code", "punctuate": true, "format_text": true}` → poll `GET /v2/transcript/{id}` every `pollInterval` (3 s) until `completed` or `error` (`fileTimeout` 3 h) → `GET /v2/transcript/{id}/sentences` → one segment per sentence, with its words.

Progress: the upload counts for 0–0.5, then 0.9 and 1.0. The cancel token is checked between steps and aborts a request in flight.

**Privacy and cleanup.** In a `finally` block, the adapter always calls `DELETE /v2/transcript/{id}`, after success, failure or cancel. AssemblyAI says this also deletes the uploaded file right away. If the transcript could not be created at all, the upload has no delete call. AssemblyAI then removes it on its own (its pages give 24 hours to 3 days).

## Languages

- Live (`language_codes`, base codes): af ar yue ca da nl en et fi fr gl de he hi it ja ko zh mr no nn fa pt ro ru es sv tr ur vi xh zu.
- Files (`language_code`): `en` → `en`, `en-US` → `en_us`, `en-GB` → `en_uk`, `en-AU` → `en_au`, `zh-Hans` → `zh`. Other tags use their base code if Universal-2 knows it (99 codes).
- `info.languages` is the set both modes accept (29 codes; it leaves out `yue`, `xh` and `zu`, which have no file model). All seven app languages are in it. A language the mode cannot take throws `unsupportedLanguage` before anything is sent.

## Errors

| AssemblyAI | Kind |
| --- | --- |
| HTTP 401, 403 | `unauthorized` |
| HTTP 402, or text about insufficient balance or payment | `quotaExceeded` |
| HTTP 400, 404, 410 | `badRequest` (language text → `unsupportedLanguage`, "too long" → `audioTooLong`) |
| HTTP 413 | `audioTooLong` |
| HTTP 422 (upload failed), 5xx | `server` |
| HTTP 429 | `rateLimited` |
| Close 1008 "Invalid API key", "Missing Authorization header", "API key is disabled", "Signature has expired" | `unauthorized` |
| Close 1008 "Too many concurrent sessions" | `rateLimited` |
| Close 1008 "Insufficient funds", "No metronome account found" | `quotaExceeded` |
| Close 3008 (session expired); 3006 for inactivity | `sessionEnded` |
| Close 3006 (invalid message), 3007 (frame size or rate) | `badRequest` |
| Close 3005, 1011 | `server` |
| Other closes, socket, TLS or timeout | `network` |
| Job `status: error` | By its text: language → `unsupportedLanguage`, too long → `audioTooLong`, balance → `quotaExceeded`, "try again" or internal → `server`, else `badRequest` |

The server sends an `Error` message (`error_code`, `error`) just before closing. The adapter uses it, or the close reason when there was no message. Messages have the key and key-like runs removed.

## Links

- Dashboard and keys: https://www.assemblyai.com/dashboard
- Pricing: https://www.assemblyai.com/pricing ($50 free credit for new accounts)
- Docs: https://www.assemblyai.com/docs (streaming API: https://www.assemblyai.com/docs/api-reference/streaming-api/streaming-api, errors: https://www.assemblyai.com/docs/streaming/common-session-errors-and-closures, REST spec: https://www.assemblyai.com/docs/openapi.json)

## Tested here, and not verified against the live service

`test/assemblyai_test.dart` uses a loopback server only. It covers:

- the raw-key header;
- the exact query (`language_codes` as JSON, no key in the URL);
- re-chunking 40 ms captures into 100 ms frames and padding the last frame to 50 ms;
- `Begin` gating `openStream`;
- partials, then finals with the same `turn_order` id, times and words;
- ignoring a late copy of a finished turn;
- the `ForceEndpoint` → `Terminate` → `Termination` order;
- refusals before `Begin` (1008 variants, 3005, close-only, HTTP 401);
- 3008 → `sessionEnded`;
- cancel;
- the file flow in order (upload → create → poll ×2 → sentences → delete), with the exact request body, times, words and progress;
- a failed job still deleting;
- 429 on upload;
- cancel while polling;
- EU hosts, an unreachable host, and the key never appearing in a thrown error.

**Not verified against the live service:** no real key was used. These come from the documentation and have not been run against AssemblyAI:

- whether Universal-3.6 Pro's live behaviour matches the documented message sequence;
- the `language_codes` URL encoding;
- whether a bad key is refused at the HTTP upgrade or by close 1008 (both are handled);
- the deletion of the upload.
