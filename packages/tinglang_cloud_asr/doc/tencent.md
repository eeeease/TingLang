# Tencent Cloud ASR (腾讯云语音识别) — `tencent`

Adapter: `lib/src/providers/tencent.dart` (`TencentCloudAsr`). Tests: `test/tencent_test.dart`.
Documentation read on 2026-10-25 (实时语音识别 page last updated 2026-10-21, 极速版 page 2026-07-16).

## Products and why

| Use | Product | Why |
|---|---|---|
| Live | 实时语音识别 (WebSocket) | The streaming product: partial and stable results per sentence, times from the stream start, every app language as a 16 kHz engine. |
| Files | 录音文件识别极速版 (flash) | One synchronous HTTPS POST with the WAV as the body (no upload storage, no polling); 100 MB / 2 h per request; sentence and word times. The asynchronous 录音文件识别 needs a public audio URL or a 5 MB base64 body and polling, so flash fits a desktop app better. |

Engines: the 16 kHz **general** engines (`16k_en`, `16k_zh`, …). They cover all seven app languages in both products, are what the free monthly quota is for, and cost less than the 大模型 engines (see Pricing). The live `16k_en_large` / `16k_zh_en` (大模型1.0) and `Hy-ASR-3.0-preview` (大模型2.0, preview: 5-minute sessions) engines exist; the flash product has no English large-model engine. Switching is a one-line change in `engineFor` (open question in the report).

## Credentials (fields)

| Field | Console value |
|---|---|
| `appId` (text) | APPID — 账号中心 › 账号信息 (also shown on API 密钥管理). Digits only; the adapter refuses anything else (it goes into the URL path). |
| `secretId` | SecretId of a key pair from 访问管理 › API 密钥管理 (<https://console.cloud.tencent.com/cam/capi>). |
| `secretKey` | The matching SecretKey. |

The service must be activated once in the ASR console (<https://console.cloud.tencent.com/asr>).

## Endpoints

- Live: `wss://asr.cloud.tencent.com/asr/v2/<appid>?<params>&signature=<sig>`
- Files: `POST https://asr.cloud.tencent.com/asr/flash/v1/<appid>?<params>`, header `Authorization: <sig>`, `Content-Type: application/octet-stream`, body = the WAV.

`hosts()` → `asr.cloud.tencent.com`.

## Signatures (HMAC-SHA1, Base64)

Live: sort every parameter except `signature` by name, join `k=v` with `&`, prefix the URL without `wss://` (`asr.cloud.tencent.com/asr/v2/<appid>?…`), HMAC-SHA1 with the SecretKey, Base64, then percent-encode (`+`, `/`, `=` included) into `signature`.
Parameters sent: `secretid`, `timestamp` (s), `expired` (timestamp + 24 h; must be < 90 days), `nonce` (random 1…2³¹−1, ≤ 10 digits), `engine_model_type`, `voice_id` (fresh UUID v4 per connection), `voice_format=1` (PCM), `needvad=1`, `word_info=1` (only for `16k_en`, `16k_zh`, `16k_ja`, the engines whose table lists word times).

Flash: same, but the string is `POST` + `asr.cloud.tencent.com/asr/flash/v1/<appid>?` + sorted query (the APPID is in the path, not the query — as the official Python SDK builds it); the Base64 value is the `Authorization` header. `timestamp` must be within 3 minutes of server time.
Parameters: `secretid`, `engine_type`, `voice_format=wav`, `timestamp`, `word_info` (1 when the caller wants words, else 0), `first_channel_only=1`, `speaker_diarization=0`, `filter_dirty=0`, `filter_modal=0` (keep fillers), `filter_punc=0`, `convert_num_mode=1`.

All values the adapter signs are digits, ids, UUIDs and engine codes, so the documented raw string and the SDK's percent-encoded string are the same.

## Live protocol

- Handshake: the server sends `{"code":0,"message":"success","voice_id":…}`; a non-zero `code` then closes the connection. `openStream` returns only after code 0.
- Audio: binary PCM, 16 kHz mono 16-bit. Documented pacing: 200 ms of audio per 200 ms (6400 bytes); faster than real time → 4000, a gap over 6 s may break the session, 15 s without audio → 4008. The adapter re-chunks the caller's 40–200 ms captures into 6400-byte frames and flushes the rest at `finish()`; it does not pace.
- Results: `result.index` (sentence number, from 0) is the segment id; `slice_type` 0 = sentence start, 1 = changing, 2 = stable (final); `start_time`/`end_time` in ms from the stream start; `voice_text_str`. Empty partials are dropped. Words (`word_list[].word/start_time/end_time`) are kept on finals only.
- End: text `{"type":"end"}`; the server sends the remaining results, then `"final":1`, and closes. `finish()` completes then (or after its timeout).
- Limits: no documented maximum session length; segments over 60 s are cut (VAD is on); default 200 concurrent sessions per account.

## File limits

`CloudAsrInfo.maxFileBytes = 100 000 000` (documented 100 MB) and `maxFileMs = 7 200 000` (2 h). A 16 kHz mono WAV hits the byte limit after about 52 minutes.
Response: `flash_result[0].sentence_list[]` with `text`, `start_time`, `end_time` (ms in the file) and `word_list[]`. Concurrency: 20 free per AppID (5 for 大模型 engines).

## Languages

| App tag | Engine (live and files) |
|---|---|
| `en`, `en-US`, `en-GB` | `16k_en` |
| `zh-Hans` (any `zh`) | `16k_zh` |
| `ja` | `16k_ja` |
| `ko` | `16k_ko` |
| `es` | `16k_es` |
| `fr` | `16k_fr` |
| `de` | `16k_de` |

Anything else → `unsupportedLanguage`. `info.languages = {en, zh, ja, ko, es, fr, de}`.

## Word timestamps

Files: requested with `word_info=1` (all engines). Live: only `16k_en`, `16k_zh`, `16k_ja` accept `word_info`. The documentation says word times are offsets in the whole stream/file; if any word of a sentence falls outside that sentence (± 250 ms), the adapter drops that sentence's words instead of shifting them.

## Errors

| Code | Meaning | `CloudAsrErrorKind` |
|---|---|---|
| 4000 | audio sent faster than real time | rateLimited |
| 4001 | invalid parameter | badRequest |
| 4002 | authentication failed | unauthorized |
| 4003 | AppID has not activated the service | quotaExceeded |
| 4004 | resource pack used up | quotaExceeded |
| 4005 | account in arrears | quotaExceeded |
| 4006 | concurrency limit | rateLimited |
| 4007 | audio decoding failed | badRequest |
| 4008 | no audio for 15 s | sessionEnded (the app reopens) |
| 4009 | client disconnected | network |
| 4010 | unknown text message | protocol |
| 4011 / 4012 | audio too large / empty (flash) | audioTooLong / badRequest |
| 5000–5003 | engine or network hiccup, retry | server |
| 6001 | called from outside mainland China (use the international site or turn off the proxy) | badRequest |
| HTTP 401/403, 429, 5xx without a code | | unauthorized, rateLimited, server |

Service messages are passed on with every credential value replaced by `***`. Transport failures never include the URL (it carries the SecretId and signature).

`verify()` opens a live session (handshake only, no audio, so nothing is billed) and closes it: this checks the AppID, both keys and activation.

## Pricing and links

- Billing: <https://cloud.tencent.com/document/product/1093/35686> — free every month: 实时语音识别 5 h, 录音文件识别极速版 5 h. Prepaid general engines from 3 元/h (live) and 2.4 元/h (flash) for the smallest packs; 大模型1.0 4.5 元/h (live) and 5 元/h (flash). Post-paid is off by default for new accounts (service stops when packs run out → 4004).
- 实时语音识别: <https://cloud.tencent.com/document/product/1093/48982>
- 录音文件识别极速版: <https://cloud.tencent.com/document/product/1093/52097>
- Official SDK used to confirm the URL and sign-string layout: <https://github.com/TencentCloud/tencentcloud-speech-sdk-python> (`asr/speech_recognizer.py`, `asr/flash_recognizer.py`).

## Tested here / not verified against the live service

Tested with a loopback fake server (`test/tencent_test.dart`):
- the live signature reproduces the documentation's example exactly (`G8jDQBRg1JfeBi/YnTjyjekxfDA=`);
- the flash sign string layout, against a value computed independently with Python (the 极速版 page prints `vLBmoXJ8Oi4YMEuNhpIyrOo+deM=` for its example, which does not reproduce from the example's own text);
- the signed live URL (all parameters, encoding, signature over the received parameters);
- partials → finals with stable ids and stream times, 6400-byte framing with the remainder flushed before `{"type":"end"}`, `finish()` waiting for `final:1`, words outside their sentence dropped;
- error frames (4008 → sessionEnded), handshake codes, HTTP 403 on the upgrade, unreachable host;
- the flash request (path, query, `Authorization`, body bytes) and response parsing; error codes and HTTP failures; limits; cancel before and during the request; no credential in any error.

Not verified against the real service (no account or key was used): the actual handshake and result frames, whether the server accepts our exact parameter set, word-time semantics in live results, flash latency for long files, and the 6001 behaviour outside mainland China.
