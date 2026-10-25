# iFlytek Open Platform (讯飞开放平台) — `xfyun`

Adapter: `lib/src/providers/xfyun.dart` (`XfyunAsr`). Tests: `test/xfyun_test.dart`.
Documentation read on 2026-10-25 (xfyun.cn/doc).

## Products and why

| Use | Product | Endpoint |
|---|---|---|
| Live | 实时语音转写大模型 | `wss://office-api-ast-dx.iflyaisol.com/ast/communicate/v1?<signed query>` |
| Files | 录音文件转写大模型 | `https://office-api-ist-dx.iflyaisol.com` — `POST /v2/upload`, then `POST /v2/getResult` until done |

Both standard pages (实时语音转写标准版 `rtasr.xfyun.cn`, 录音文件转写标准版 `raasr.xfyun.cn`) open with a banner recommending the large-model versions, and the product pages (<https://www.xfyun.cn/services/rtasr>, <https://www.xfyun.cn/services/lfasr>) now sell the large-model versions. The standard real-time product only offers Chinese and English without extra purchases (other languages have console-only parameter values), and an account opened for the large-model service is not necessarily licensed on the old endpoint (a published third-party integration report shows 10110 there). The large-model products use one set of keys for both (APPID / APIKey / APISecret), so the user enters three values once.

## Credentials (fields)

From the console's 服务接口认证信息 panel (<https://console.xfyun.cn/services/new_rta> for real time, <https://console.xfyun.cn/services/new_lfasr> for files; apps at <https://console.xfyun.cn/app/myapp>):

| Field | Console value | Sent as |
|---|---|---|
| `appId` (text) | APPID | `appId` |
| `apiKey` | APIKey | `accessKeyId` |
| `apiSecret` | APISecret | HMAC key (`accessKeySecret`), never sent |

No new `CloudFieldKeys` were needed. Each service needs its free quota claimed or a package bought on its product page.

## Signature (both products)

1. Take every request parameter except `signature`, drop empty values, sort by name.
2. Percent-encode each key and value (RFC 3986 unreserved characters kept; equal to the Java `URLEncoder` used by the official sample for these values: `:` → `%3A`, `+` → `%2B`), join `key=value` with `&` → baseString. The same string is the request's query.
3. `signature = Base64(HMAC-SHA1(APISecret, baseString))` — live: appended as `&signature=<percent-encoded>`; files: the `signature` request header.

Time values are `yyyy-MM-dd'T'HH:mm:ss+0800` (the adapter writes Beijing time; the services check the skew — 35014 / 100012 / 100008).

## Live protocol

- Query: `appId`, `accessKeyId`, `utc`, `uuid` (fresh per session; a repeated signature is refused with 35030), `lang` (`autodialect` or `autominor`), `recognized_language` (autominor only), `audio_encode=pcm_s16le`, `samplerate=16000`, `signature`.
- Handshake: a `started` action (`{"msg_type":"action","data":{"action":"started","sessionId":…}}`; the page's own table also shows the older top-level `{"action":"started","sid":…}` — both are read). `openStream` returns after it.
- Audio: binary PCM, 16 kHz mono 16-bit; documented as 1280 bytes (40 ms) every 40 ms, faster may fail (100001), 15 s without audio ends the session (37005). The adapter re-chunks to 1280-byte frames and flushes the rest at `finish()`; it does not pace.
- Results: `{"msg_type":"result","res_type":"asr","data":{"cn":{"st":{bg, ed, type, rt[].ws[].cw[]}}, "ls":…}}`. `st.type` "0" = final, "1" = partial; `bg`/`ed` in ms from the stream start (`ed` is 0 in partials, the adapter then uses `bg`); token `wp` n = word, s = filler, p = punctuation, g = paragraph mark (skipped). iFlytek gives no sentence id, so the adapter numbers sentences: partials share the id of the final that follows them. `data.ls: true` marks the last result.
- End: text `{"end": true, "sessionId": <id from started>}`; `finish()` completes on `ls: true` or when the server closes.
- Errors: an `error` action or a non-zero `code` (top level or in `data`), or `res_type` `frc` with `normal: false`.
- Limits: 8 hours per session (37007 → sessionEnded); concurrency per AppID depends on the package (35006).

## File protocol

1. `POST /v2/upload?appId&accessKeyId&dateTime&signatureRandom&fileSize&fileName=tinglang.wav&language&durationCheckDisable=true`, header `signature`, `Content-Type: application/octet-stream`, body = the WAV. Reply `{"code":"000000","content":{"orderId":…,"taskEstimateTime":ms}}`.
2. `POST /v2/getResult?accessKeyId&dateTime&signatureRandom&orderId&resultType=transfer`, body `{}`, same `signatureRandom` as the upload (as documented), a fresh `dateTime`. `orderInfo.status`: 0 created, 3 processing, 4 done, −1 failed; `100013` = not finished yet. The interval grows (1×, 2×, 9× the base 5 s) and stops after 96 queries (the service allows 100 per order).
3. `orderResult` (a JSON string) → `lattice[].json_1best` (itself a JSON string) → `st {bg, ed, rt[].ws[] {wb, we, cw[] {w, wp}}}`; one segment per lattice entry.

`durationCheckDisable=true` avoids failType 5 for rounding differences. Smoothing (`eng_smoothproc`) is left at the default; filler tokens (`wp` s) that remain are kept, as heard.

`failType`: 6 (silent file) → empty result; 4 (over 5 h) → audioTooLong; 2 (transcoding) and 5 → badRequest; others → server.

## File limits

`maxFileMs = 18 000 000` (5 h) and `maxFileBytes = 500 000 000` (documented "不超过 500MB"). A 16 kHz mono WAV reaches 500 MB after about 4.3 hours.

## Languages

| App tag | `lang` / `language` | `recognized_language` (live) |
|---|---|---|
| `en`, `en-US`, `en-GB` | `autodialect` (Chinese + English + 202 dialects) | — |
| `zh-Hans` | `autodialect` | — |
| `ja`, `ko`, `es`, `fr`, `de` | `autominor` (37 languages) | `ja`, `ko`, `es`, `fr`, `de` |

`autominor` must be enabled for the account through a work order (<https://console.xfyun.cn/workorder/commit>); without it the service answers 35020 / 100018 / 100019 / 100020, which the adapter reports as `unsupportedLanguage` with that hint. The file API documents no target-language parameter, so autominor files auto-detect. `info.languages = {en, zh, ja, ko, es, fr, de}`.

## Word timestamps

Word times are `bg + wb × 10` to `bg + we × 10` ms (`wb`/`we` are 10 ms frames from the sentence start: documented by the file page and the standard realtime page; the numbers in the large-model realtime example fit the same reading). A sentence's words are dropped when any word lacks a positive time span or falls outside the sentence. Live words are kept on finals only. Text joins Latin, Cyrillic, Greek and Hangul words with spaces (and after ASCII punctuation), CJK without.

## Errors

Live (实时语音转写大模型, plus old 实时语音转写 codes):

| Codes | `CloudAsrErrorKind` |
|---|---|
| 35001, 35004, 35005, 35010, 35017, 100002, 100013, 100016, 100020, 10105 | unauthorized |
| 35002 (usage insufficient), 35022, 35031 (account expired), 10110 (no licence) | quotaExceeded |
| 35006, 37002, 10800 (concurrency), 100001 (audio too fast) | rateLimited |
| 35014, 100012, 35030 (time skew / repeated signature) | badRequest (message: check the Mac's clock) |
| 35020, 100018, 100019 | unsupportedLanguage |
| 37005 (no audio 15 s), 37007 (8 h limit) | sessionEnded |
| 37010, 37011, 37012 | protocol |
| 10202, 10204, 10205 | network |
| other 35xxx/37xxx parameter codes | badRequest; anything else server |

Files (录音文件转写大模型):

| Codes | `CloudAsrErrorKind` |
|---|---|
| 000002 (accessKeyId unknown), 100009 (signature) | unauthorized |
| 100007 (permission: service not activated) | quotaExceeded |
| 100012 | rateLimited |
| 100008 (request time) | badRequest |
| 100020 (language) | unsupportedLanguage |
| 999999, 100001, 100002, 100004, 100006, 100037, 100039 | server |
| others | badRequest |

HTTP failures without a body code map by status. Service messages are passed on with credential values replaced by `***`.

`verify()` opens a live session and closes it after the `started` handshake (no audio; ending a session without audio is an error to the service, 37012, so no end message is sent). It checks the APPID, APIKey, APISecret and the real-time service.

## Pricing and links

- Product and pricing pages (rendered in the browser, prices not copied here): <https://www.xfyun.cn/services/rtasr>, <https://www.xfyun.cn/services/lfasr>
- 实时语音转写大模型: <https://www.xfyun.cn/doc/spark/asr_llm/rtasr_llm.html>
- 录音文件转写大模型: <https://www.xfyun.cn/doc/spark/asr_llm/Ifasr_llm.html>
- Standard versions (not used): <https://www.xfyun.cn/doc/asr/rtasr/API.html>, <https://www.xfyun.cn/doc/asr/ifasr_new/API.html>

## Tested here / not verified against the live service

Tested with a loopback fake server (`test/xfyun_test.dart`): the baseString against both documented examples (the realtime page's `accessKeyId=XXX&appId=XXX&lang=cn&utc=2025-03-24T00%3A01%3A19%2B0800&uuid=…` and the upload example with a Chinese file name); HMAC values computed independently with Python (the pages print no reproducible signature — the realtime page reuses the standard version's example value); Beijing-time formatting; the signed live URL; partials and finals with stable ids, word times from frames, 1280-byte framing, the end message with the session id, completion on `ls`; the older top-level message shape; error frames and handshake refusals; HTTP 403 on the upgrade; `verify` sending no audio and no end message; the file flow (upload query, header signature, body bytes → processing / 100013 / done → sentences and words), the multilingual mode for files, error codes, failTypes (silent file → empty), HTTP 502, cancel while polling, an unreachable host, missing credentials.

Not verified against the real service (no account or key was used): the exact live frame shapes (the documentation is inconsistent; the handshake/`sessionId` shape follows the page's description and independent integrations), whether `wb`/`we` in live results are frames from `bg`, how English words are spaced in real results, whether `autominor` accepts `recognized_language` for these codes, whether `getResult` needs `appId`, and actual processing times.
