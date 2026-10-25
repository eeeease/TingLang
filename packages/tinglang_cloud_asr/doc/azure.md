# Microsoft Azure AI Speech (`azure`)

`lib/src/providers/azure.dart` · checked against Microsoft Learn on 2026-10-25.

## Products and models

| Use | API | Why |
| --- | --- | --- |
| Files | [Fast transcription](https://learn.microsoft.com/azure/ai-services/speech-service/fast-transcription-create) `POST /speechtotext/transcriptions:transcribe?api-version=2025-10-15` | One synchronous request, faster than real time. No storage container is needed (batch transcription needs one) and nothing stays on the service. It returns display-form phrases with word offsets. |
| Live | The Speech service's real-time WebSocket protocol (the one the Speech SDK speaks), conversation mode | Microsoft publishes no other streaming API for speech to text. The adapter implements the protocol itself (see below). It is **not verified against the live service.** |

Both use Microsoft's base model for the chosen locale. Azure LLM Speech ("enhanced mode") and custom models are not used.

## Fields, region and endpoints

- `apiKey` (secret): the Speech or Foundry resource key, sent as `Ocp-Apim-Subscription-Key`.
- `region` (text): the resource's region, such as `eastus` or `westeurope`. It is normalised (lower case, spaces removed, so `East US` becomes `eastus`) and must match `^[a-z][a-z0-9]{2,39}$`. Dots, slashes, colons, `@`, `?`, `#`, hyphens and so on are rejected, so the value can only ever be a host label. Azure Government (`usgov…`, `usdod…`) and Azure China (`china…`) use other host suffixes and are refused. A bad region throws `unauthorized` (a settings problem) before anything is sent, and `hosts()` returns nothing for it.
- REST host: `https://<region>.api.cognitive.microsoft.com`. Speech host: `wss://<region>.stt.speech.microsoft.com`. `hosts()` returns both.
- `verify`: `POST https://<region>.api.cognitive.microsoft.com/sts/v1.0/issueToken` with the key. It is free, proves the key belongs to that region and sends no audio. The returned token is thrown away.

Free (F0) resources can verify and stream, but Azure lists fast transcription as "not applicable" on F0. A file request from an F0 key then fails with Azure's error, mapped as below.

## Files (fast transcription)

The request is multipart with two parts:

- `audio`: `tinglang.wav`, `audio/wav`;
- `definition`: `{"locales":["en-GB"],"profanityFilterMode":"None"}`.

One locale is passed, because a single known locale is the most accurate and fastest option. Profanity is not masked, since learners need the real words.

The response's `phrases` (`offsetMilliseconds`, `durationMilliseconds`, `text`, `words`, `locale`) become one final segment each, with their words. Times are offsets into the file.

Progress: the upload counts for 0–0.5, and 1.0 arrives with the answer. Cancel aborts the request.

Limits disagree. The quota page (updated 2026-10-23) and the how-to say < 5 h and < 500 MB. The 2025-10-15 API reference still says < 2 h and < 250 MB. `CloudAsrInfo.maxFileMs` is 2 h and `maxFileBytes` is 240 MB, inside both. Fast and batch transcription share 600 requests per minute.

**Privacy.** Fast transcription is synchronous and keeps no job or file, so there is nothing to delete afterwards.

## Live: the Speech service WebSocket protocol

Written from the protocol's documented behaviour and the open-source JS Speech SDK's message format (MIT), which was read, not copied. The adapter is its own implementation.

- URL: `wss://<region>.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=<locale>&format=detailed&profanity=raw&wordLevelTimestamps=true`.
- Upgrade headers: `Ocp-Apim-Subscription-Key`, and `X-ConnectionId` (32 random hex digits).
- Text messages are `Name: value` header lines (CRLF), a blank line, then the body.
- Binary messages are a 2-byte big-endian header length, the ASCII header lines (each ending in CRLF), then the payload.
- Every client message carries `Path`, `X-RequestId` (32 hex digits, one per stream) and `X-Timestamp` (ISO 8601 UTC with milliseconds).
- Message order:
  1. `speech.config` (JSON: `context.system` is name/version `Tinglang`; `context.os` is the OS name only, with no version or device data);
  2. `audio` with `Content-Type: audio/x-wav` and a 44-byte WAV header (16 kHz, mono, 16-bit);
  3. one `audio` message per captured chunk (40–200 ms, no re-chunking; the protocol has no frame size);
  4. on `finish()`, an `audio` message with no body.
- The service replies with `turn.start`, `speech.startDetected`, then:
  - `speech.hypothesis` (`Text`, `Offset`, `Duration` in 100-ns ticks): a partial;
  - `speech.phrase` (`RecognitionStatus`, `DisplayText` or `NBest[0].Display`, `NBest[0].Words`): a final.
  The partials and final of one phrase share `id` (`"0"`, `"1"`, …), and the id moves on after each successful phrase. `NoMatch`, `InitialSilenceTimeout`, `BabbleTimeout` and `EndOfDictation` produce no text.
- After the end of the audio, the last `speech.phrase`, `speech.endDetected` and `turn.end` arrive, and `finish()` completes.
- Offsets are 100-ns ticks from the start of the turn, which is the first sample sent, so ms = ticks / 10,000.
- Word timings are the lexical words (`good`, not `Good,`), as the service sends them.

**Session limit → `sessionEnded`.** Microsoft's old WebSocket protocol documentation capped an active connection at 10 minutes (180 s idle) and said the service closes it without warning. Current pages give no figure, and the SDK reconnects transparently. So the adapter treats any `turn.end` before `finish()`, and any close with code 1000/1001 before `finish()`, as `sessionEnded`, and the app opens a new stream. Audio sent between the last phrase and that close is not re-sent.

Concurrency: 100 real-time requests per S0 resource (can be raised), 1 on F0.

## Languages

Locales: `en` → `en-US`, `en-US`, `en-GB` (also `en-AU`, `en-CA`, `en-IN`), `zh-Hans` → `zh-CN`, `ja` → `ja-JP`, `ko` → `ko-KR`, `es` → `es-ES` (`es-MX` kept), `fr` → `fr-FR` (`fr-CA` kept), `de` → `de-DE`, plus `it-IT`, `pt-BR` and `hi-IN`. Those are the locales the fast transcription page lists. Real-time speech to text supports many more, but only locales both modes document are offered. `info.languages` is {en, zh, ja, ko, es, fr, de, it, pt, hi}. Anything else throws `unsupportedLanguage` before sending.

## Errors

REST errors are `{"error": {"code", "message", "innerError": {"code", "message"}}}` (the gateway also sends `{"error": {"code": "401", "message": …}}`).

| Azure | Kind |
| --- | --- |
| inner `AudioLengthLimitExceeded`, HTTP 413 | `audioTooLong` |
| inner `InvalidLocale`, `UnsupportedLanguageCode`, `NoLanguageIdentified`, `MultipleLanguagesIdentified` | `unsupportedLanguage` |
| inner `QuotaViolation`; HTTP 403 whose message mentions quota ("Out of call volume quota") | `quotaExceeded` |
| HTTP 401, other 403; inner `InvalidSubscription`, `SubscriptionNotFound`, `InvalidPermissions` | `unauthorized` |
| HTTP 400, 404, 415, 422 (for example `InvalidAudioFormat`, `EmptyAudioFile`) | `badRequest` |
| HTTP 429 | `rateLimited` (Azure asks for retries while it scales) |
| HTTP 5xx | `server` |
| Refused WebSocket upgrade | By its HTTP status, as above |
| Phrase status `TooManyRequests` / `BadRequest` / `Forbidden` / `Error`, `ServiceUnavailable` | `rateLimited` / `badRequest` / `unauthorized` / `server` |
| Close reason mentioning "too many", concurrency or throttling / quota | `rateLimited` / `quotaExceeded` |
| Close 1000/1001 before `finish()`, or an early `turn.end` | `sessionEnded` |
| Close 1007 / 1008 / 1011, 4000 | `badRequest` / `unauthorized` / `server` |
| No close code, socket, TLS or timeout | `network` |

Messages have the key and key-like runs removed. `providerCode` is kept only when it is a plain code.

## Links

- Create a Speech resource: https://portal.azure.com/#create/Microsoft.CognitiveServicesSpeechServices
- Pricing: https://azure.microsoft.com/pricing/details/speech/
- Docs: https://learn.microsoft.com/azure/ai-services/speech-service/ (fast transcription REST reference: https://learn.microsoft.com/rest/api/speechtotext/transcriptions/transcribe, quotas: https://learn.microsoft.com/azure/ai-services/speech-service/speech-services-quotas-and-limits, regions: https://learn.microsoft.com/azure/ai-services/speech-service/regions)

## Tested here, and not verified against the live service

`test/azure_test.dart` uses a loopback server only. It covers:

- region normalisation and rejection (host injection attempts, sovereign clouds, empty);
- locales;
- `verify` with the key header, error mapping and an unreachable host;
- the fast transcription request (path, `api-version`, multipart parts, definition JSON), with phrases turned into segments, times and words;
- inner error codes mapped to kinds;
- cancel aborting the request;
- limit, language and region checks before any request;
- the live handshake (path, query, key header, connection id);
- `speech.config`, then the WAV-header audio message, then framed audio with a stable request id and timestamps, parsed independently by the test;
- hypotheses (numbers or numeric strings), then phrases with tick → ms times, words and stable ids;
- `NoMatch` ignored;
- end of audio (empty message) → last phrase → `turn.end`, with `finish` completing;
- an early `turn.end` or close → `sessionEnded`;
- close codes, phrase statuses and refused upgrades (401, 403, 429, 500);
- cancel;
- the key never appearing in a thrown error.

**Not verified against the live service:** no Azure resource was used. The live adapter in particular follows the protocol as described, and has never talked to `stt.speech.microsoft.com`. Unconfirmed points:

- whether the service needs more `speech.config` fields;
- the exact close codes and reasons for quota and time limits;
- the real per-connection time limit;
- `wordLevelTimestamps` as a query parameter.

Fast transcription has not been run against Azure either.
