# Alibaba Cloud Model Studio / 阿里云百炼 (DashScope) — `dashscope`

Adapter: `lib/src/providers/dashscope.dart` (`DashScopeAsr`). Tests: `test/dashscope_test.dart`.
Documentation read on 2026-10-25 (help.aliyun.com, Model Studio 语音识别 pages).

## Products and why

| Use | Model / API | Why |
|---|---|---|
| Live | `fun-asr-realtime` over the DashScope realtime WebSocket (`run-task` → binary audio → `finish-task`) | Model Studio's realtime model whose main version covers 30 languages, including all seven app languages (`paraformer-realtime-v2` has no Spanish; Model Studio now calls Paraformer the older generation and recommends migrating). Sentence and word times by default, no session-length limit, per-second billing, available in Beijing and Singapore. |
| Files | `fun-asr` asynchronous transcription, with the WAV in DashScope's temporary storage (`oss://` URL) | The recorded-file API takes only URLs. The documented temporary upload (upload policy + OSS form POST → `oss://…`, valid 48 h, used with `X-DashScope-OssResourceResolve: enable`) is still documented and avoids any storage of the user's own. Same model family and languages as live; 12 h / 2 GB per file. |

Alternatives on the same protocols (constructor `liveModel` / `fileModel`): the selection page now recommends `qwen-audio-3.1-asr-flash-streaming` for continuous transcription and `qwen-audio-3.1-asr-flash-filetrans` for files. They use the identical `run-task` and transcription APIs and the same language list, but bill per token (6 元 / 0.8 元 per million input tokens in Beijing) where the conversion from audio seconds is not documented, so the per-second Fun-ASR models are the default (open question in the report). `qwen3-asr-flash-realtime` uses a different (OpenAI-style) protocol and returns no timestamps.

Model Studio now recommends workspace-specific hosts (`{WorkspaceId}.cn-beijing.maas.aliyuncs.com`, `{WorkspaceId}.ap-southeast-1.maas.aliyuncs.com`); the documentation states the existing `dashscope.aliyuncs.com` / `dashscope-intl.aliyuncs.com` hosts still work, so no workspace field is needed.

## Credentials (fields)

| Field | Console value |
|---|---|
| `apiKey` | A Model Studio API key (`sk-…`): 百炼控制台 › API-Key (<https://bailian.console.aliyun.com/cn-beijing/model/settings/api-key>; Singapore: the international Model Studio console). Keys are per region. |
| `region` (choice) | `cn` = 华北2（北京） `dashscope.aliyuncs.com` (default); `intl` = Singapore `dashscope-intl.aliyuncs.com`. |

## Endpoints

| Step | Request |
|---|---|
| Live | `wss://<host>/api-ws/v1/inference`, header `Authorization: Bearer <key>` |
| Upload policy (also `verify`) | `GET https://<host>/api/v1/uploads?action=getPolicy&model=fun-asr` |
| Upload | `POST <data.upload_host>` multipart form: `OSSAccessKeyId`, `Signature`, `policy`, `x-oss-object-acl`, `x-oss-forbid-overwrite`, `key` = `<upload_dir>/tinglang-<random>.wav`, `success_action_status=200`, then `file` last. No API key is sent to the storage host. |
| Create task | `POST https://<host>/api/v1/services/audio/asr/transcription`, headers `X-DashScope-Async: enable`, `X-DashScope-OssResourceResolve: enable`; body `{"model":"fun-asr","input":{"file_urls":["oss://<key>"]},"parameters":{"channel_id":[0],"language_hints":["en"]}}` (`parameters` is always sent; the new hosts fail tasks without it). |
| Poll | `GET https://<host>/api/v1/tasks/<task_id>` until `task_status` is `SUCCEEDED` (or `FAILED`/`CANCELED`/`UNKNOWN`). |
| Result | `GET <results[0].transcription_url>` (pre-signed OSS URL, valid 24 h, no key sent). |

The upload host and the result URL come from the service; the adapter only uses `https://*.aliyuncs.com` URLs (or the test server) and refuses anything else before sending audio. Redirects are not followed (they would repeat the `Authorization` header).

`hosts()` → `dashscope.aliyuncs.com` + `*.oss-cn-beijing.aliyuncs.com` (cn) or `dashscope-intl.aliyuncs.com` + `*.oss-ap-southeast-1.aliyuncs.com` (intl). The Beijing bucket names are from the documented examples; the Singapore OSS region is inferred, not documented.

## Authentication

`Authorization: Bearer <API key>` on every Model Studio request, including the WebSocket handshake (a bad key fails the upgrade with HTTP 401/403). No request signing.

## Live protocol

- After the upgrade the adapter sends `run-task`: `header {action: run-task, task_id: <UUID v4>, streaming: duplex}`, `payload {task_group: audio, task: asr, function: recognition, model: fun-asr-realtime, parameters {format: pcm, sample_rate: 16000, language_hints: [<code>]}, input: {}}`. `openStream` returns after `task-started` (or throws on `task-failed`).
- Audio: binary PCM frames; the samples send 100 ms (3200 bytes) per frame. The adapter re-chunks to 3200 bytes and flushes the rest before `finish-task`; it does not pace.
- Results (`result-generated`): `payload.output.sentence` with `sentence_id` (from 1; the segment id), `sentence_end` (final), `begin_time`, `end_time` (null in partials; the adapter then uses the last word's end, else the start), `text`, `words[] {begin_time, end_time, text, punctuation}`. Heartbeat results (`heartbeat: true`, `sentence_id` 0) and empty partials are dropped. Words are kept on finals, text trimmed, punctuation not attached.
- End: `finish-task` with the same `task_id`; remaining results, then `task-finished`. `task-failed` (`error_code`, `error_message`) ends the stream with an error.
- Limits: no session-length limit ("无限制"); the server times out an idle task ("request timeout after 23 seconds", `CLIENT_ERROR` → sessionEnded). Task creation is limited to 20 per second per account.

## File limits

`maxFileBytes = 104 857 600` (100 MB: the temporary-storage policy in the documentation allows `max_file_size_mb` 100 per upload, and the policy's actual value is checked at run time) and `maxFileMs = 43 200 000` (12 h, the fun-asr limit). A 16 kHz mono WAV reaches 100 MB after about 54 minutes. Submission is limited to 600 requests per minute. The temporary URL lives 48 h; the policy endpoint allows 100 QPS per account and model (Model Studio warns that temporary storage is not meant for production; for one user's files it is the documented route that needs no OSS bucket of their own).

Result JSON: `transcripts[0].sentences[] {begin_time, end_time, text, words[]}` in ms from the file start. A subtask code `SUCCESS_WITH_NO_VALID_FRAGMENT` (no speech) returns an empty list.

## Languages

`language_hints` takes one code for Fun-ASR (only the first is used):

| App tag | Hint |
|---|---|
| `en`, `en-US`, `en-GB` | `en` |
| `zh-Hans` | `zh` |
| `ja`, `ko`, `es`, `fr`, `de` | same code |

Other tags → `unsupportedLanguage` (the models know more languages; the adapter lists the app's seven). `info.languages = {en, zh, ja, ko, es, fr, de}`.

## Word timestamps

Both models return word times by default (live: on each sentence; files: per sentence). Words outside their sentence (± 250 ms) cause that sentence's words to be dropped, never shifted.

## Errors

| Code (HTTP body `code`, `task-failed` `error_code`, task/subtask `code`) | `CloudAsrErrorKind` |
|---|---|
| `InvalidApiKey`, `AccessDenied*`, `Model.AccessDenied`, `Workspace.AccessDenied` | unauthorized |
| `Arrearage`, `AccessDenied.Unpurchased`, `AllocationQuota.FreeTierOnly`, `CommodityNotPurchased`, `PrepaidBillOverdue`, `PostpaidBillOverdue`, `BudgetLimitExceeded`, `ModelNotFound` | quotaExceeded |
| `Throttling*` (RateQuota, BurstRate, AllocationQuota, Concurrency, …) | rateLimited |
| `InvalidFile.AudioLengthError`, `InvalidFile.Duration`, `InvalidFile.Size`, `BadRequest.TooLarge`, `Audio.DurationLimitError`, `FILE_TOO_LARGE`, `AUDIO_DURATION_TOO_LONG` | audioTooLong |
| `CLIENT_ERROR` with a timeout message | sessionEnded |
| `ClientDisconnect` | network |
| `InternalError*`, `SystemError`, `ModelServiceFailed`, `RequestTimeOut`, `ResponseTimeout` | server |
| `InvalidParameter*`, `BadRequest*`, `InvalidFile*`, `Audio.*`, `FILE_*`, other `CLIENT_ERROR` | badRequest |
| anything else | by HTTP status (401/403 unauthorized, 429 rateLimited, 5xx server, else badRequest) |

OSS upload failures (XML `<Code>`/`<Message>`): 403 (e.g. expired policy) → server (a new attempt gets a new policy), 413 / `EntityTooLarge` → audioTooLong, 429 → rateLimited, 5xx → server. An expired result URL → server. Messages are passed on with the API key and the OSS policy values replaced by `***`.

`verify()` requests an upload policy: free, no audio, and it rejects a wrong or wrong-region key.

## Pricing and links

- Prices: <https://help.aliyun.com/zh/model-studio/model-pricing> — Beijing: `fun-asr-realtime` 0.00033 元/s (≈ 1.19 元/h), `fun-asr` 0.00022 元/s (≈ 0.79 元/h), each with 36 000 s (10 h) free for 90 days after activation; Singapore: 0.00066 and 0.00026 元/s, no free quota. Files are billed on detected speech duration.
- Model overview: <https://help.aliyun.com/zh/model-studio/asr-model/>
- Fun-ASR realtime WebSocket: <https://help.aliyun.com/zh/model-studio/fun-asr-realtime-websocket-api>, client events <https://help.aliyun.com/zh/model-studio/fun-asr-client-events>, server events <https://help.aliyun.com/zh/model-studio/fun-asr-server-events>
- Recorded files (HTTP): <https://help.aliyun.com/zh/model-studio/fun-asr-recorded-speech-recognition-http-api>
- Temporary upload: <https://help.aliyun.com/zh/model-studio/get-temporary-file-url>
- Error codes: <https://help.aliyun.com/zh/model-studio/error-code>; rate limits: <https://help.aliyun.com/zh/model-studio/rate-limit>
- API keys: <https://help.aliyun.com/zh/model-studio/get-api-key>

## Tested here / not verified against the live service

Tested with a loopback fake server (`test/dashscope_test.dart`): the upgrade request (path, `Bearer` header, no key in the URL); the `run-task` message; partials and finals by `sentence_id` with times and words, heartbeat and empty partials dropped; 3200-byte framing and the flushed remainder; `finish-task` with the same task id and `task-finished`; `task-failed` during and instead of `task-started`; HTTP 401 on the upgrade; a socket closed without a message (sessionEnded); the whole file flow (policy → multipart form with the file last and intact → task with `X-DashScope-Async` and `X-DashScope-OssResourceResolve` → PENDING/RUNNING/SUCCEEDED polls → result download without the key → sentences and words); `verify` making one policy request; HTTP error codes; failed tasks and subtasks; no-speech results; a foreign upload host refused before upload; OSS XML errors with policy values redacted; cancel while polling; an unreachable host. There is no published signature to check (bearer auth only).

Not verified against the real service (no key was used): the exact event and result frames from `fun-asr-realtime`, whether the policy endpoint accepts `model=fun-asr` (the documentation's example uses another model), the real `max_file_size_mb` for this model, the Singapore OSS host names, and processing times for long files.
